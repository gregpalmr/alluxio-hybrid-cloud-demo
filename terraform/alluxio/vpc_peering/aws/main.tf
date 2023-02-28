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

provider "aws" {
  alias = "cloud_compute"
}

provider "aws" {
  alias = "on_prem"
}

data "aws_vpc" "compute_vpc" {
  provider = aws.cloud_compute
  id       = var.cloud_compute_vpc_id
}

data "aws_subnet" "compute_subnet" {
  provider = aws.cloud_compute
  id       = var.cloud_compute_subnet_id
}

data "aws_vpc" "on_prem_vpc" {
  provider = aws.on_prem
  id       = var.on_prem_vpc_id
}

data "aws_subnet" "on_prem_subnet" {
  provider = aws.on_prem
  id       = var.on_prem_subnet_id
}

data "aws_region" "on_prem_region" {
  provider = aws.on_prem
}

resource "aws_vpc_peering_connection" "peering" {
  count       = var.enabled ? 1 : 0
  provider    = aws.cloud_compute
  vpc_id      = var.cloud_compute_vpc_id
  peer_vpc_id = var.on_prem_vpc_id
  peer_region = data.aws_region.on_prem_region.name
  auto_accept = false

  tags = {
    Side = "Requester"
  }
}

resource "aws_vpc_peering_connection_accepter" "peering_accepter" {
  count                     = var.enabled ? 1 : 0
  provider                  = aws.on_prem
  vpc_peering_connection_id = aws_vpc_peering_connection.peering[0].id
  auto_accept               = true

  tags = {
    Side = "Accepter"
  }
}

resource "aws_vpc_peering_connection_options" "peering_requester_options" {
  count    = var.enabled ? 1 : 0
  provider = aws.cloud_compute
  # As options can't be set until the connection has been accepted
  # create an explicit dependency on the accepter.
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.peering_accepter[0].id

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_vpc_peering_connection_options" "peering_accepter_options" {
  count                     = var.enabled ? 1 : 0
  provider                  = aws.on_prem
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.peering_accepter[0].id

  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_route" "route_peering_compute" {
  count                     = var.enabled ? 1 : 0
  provider                  = aws.cloud_compute
  route_table_id            = data.aws_vpc.compute_vpc.main_route_table_id
  destination_cidr_block    = data.aws_subnet.on_prem_subnet.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peering[0].id
}

resource "aws_route" "route_peering_on_prem" {
  count                     = var.enabled ? 1 : 0
  provider                  = aws.on_prem
  route_table_id            = data.aws_vpc.on_prem_vpc.main_route_table_id
  destination_cidr_block    = data.aws_subnet.compute_subnet.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peering[0].id
}

resource "aws_security_group_rule" "allow_on_prem_access" {
  count             = var.enabled ? 1 : 0
  provider          = aws.cloud_compute
  type              = "ingress"
  description       = "Allow all traffic from peering VPC subnet"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [data.aws_subnet.on_prem_subnet.cidr_block]
  security_group_id = var.cloud_compute_security_group_id
}

resource "aws_security_group_rule" "allow_compute_access" {
  count             = var.enabled ? 1 : 0
  provider          = aws.on_prem
  type              = "ingress"
  description       = "Allow all traffic from peering VPC subnet"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [data.aws_subnet.compute_subnet.cidr_block]
  security_group_id = var.on_prem_security_group_id
}
