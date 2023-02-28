/*
 * The Alluxio Open Foundation licenses this work under the Apache License, version 2.0
 * (the "License"). You may not use this work except in compliance with the License, which is
 * available at www.apache.org/licenses/LICENSE-2.0
 *
 * This software is distributed on an "AS IS" basis, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
 * either express or implied, as more fully set forth in the License.
 *
 * See the NOTICE file distributed with this work for information regarding copyright ownership.
 */

resource "random_integer" "cidr_range_prefix" {
  count = var.enabled ? (var.aws_vpc_cidr == "" ? 1 : 0) : 0
  // avoid 0, 10, 127, and 224
  // https://cloud.ibm.com/docs/vpc-on-classic-network?topic=vpc-on-classic-network-choosing-ip-ranges-for-your-vpc
  min = 11
  max = 126
}

// avoid cidr range prefix conflicts
resource "random_integer" "cidr_range" {
  count = var.enabled ? (var.aws_vpc_cidr == "" ? 1 : 0) : 0
  min   = 1
  max   = 255
}

locals {
  vpc_cidr    = var.aws_vpc_cidr == "" ? "${random_integer.cidr_range_prefix[0].result}.${random_integer.cidr_range[0].result}.0.0/16" : var.aws_vpc_cidr
  subnet_cidr = var.aws_subnet_cidr == "" ? cidrsubnet(local.vpc_cidr, 4, 0) : var.aws_subnet_cidr
}

resource "aws_vpc" "vpc" {
  count                = var.enabled ? 1 : 0
  cidr_block           = local.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
}

data "aws_region" "current" {
}

resource "aws_vpc_dhcp_options" "dhcp_options" {
  count               = var.enabled ? (length(var.aws_dns_servers) != 0 ? 1 : 0) : 0
  domain_name         = data.aws_region.current.name == "us-east-1" ? "ec2.internal" : "${data.aws_region.current.name}.compute.internal"
  domain_name_servers = var.aws_dns_servers
}

resource "aws_vpc_dhcp_options_association" "dhcp_options_association" {
  count           = var.enabled ? (length(var.aws_dns_servers) != 0 ? 1 : 0) : 0
  vpc_id          = aws_vpc.vpc[0].id
  dhcp_options_id = aws_vpc_dhcp_options.dhcp_options[0].id
}

data "aws_availability_zones" "zones" {
  exclude_names = var.aws_availability_zone_blacklist
}

resource "aws_subnet" "subnet" {
  count                   = var.enabled ? 1 : 0
  vpc_id                  = aws_vpc.vpc[0].id
  availability_zone       = var.aws_subnet_zone == null ? data.aws_availability_zones.zones.names[0] : var.aws_subnet_zone
  cidr_block              = local.subnet_cidr
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "gw" {
  count  = var.enabled ? 1 : 0
  vpc_id = aws_vpc.vpc[0].id
}

resource "aws_route" "r" {
  count                  = var.enabled ? 1 : 0
  route_table_id         = aws_vpc.vpc[0].main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw[0].id
}

data "aws_ec2_instance_type_offering" "compute_instance_offering" {
  count = var.enabled ? length(var.aws_instance_types) : 0
  filter {
    name   = "instance-type"
    values = [var.aws_instance_types[count.index]]
  }
  filter {
    name   = "location"
    values = [aws_subnet.subnet[0].availability_zone]
  }

  location_type = "availability-zone"
}
