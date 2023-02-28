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

variable "aws_vpc_cidr" {
  description = "VPC CIDR block to create VPC with. If left empty, a random CIDR block will be used"
  type        = string
  default     = ""
}

variable "aws_subnet_zone" {
  description = "Availbility zone to create subnet and related resources in. If zone is not provided, aws will pick a random zone to create subnet in."
  type        = string
  default     = null
}

variable "aws_availability_zone_blacklist" {
  description = <<DESC
Availability zones to blacklist while creating subnet and related resources in.
If a non-null value is provided for aws_subnet_zone, the blacklist is ignored.
Availability zones that don't support commonly used instance types and functionalities are blacklisted by default.
If your terraform apply throws error 'no EC2 Instance Type Offerings found matching criteria',
please add the availbility zone of your created subnet in this list.
DESC
  type        = list(string)
  default     = ["us-east-1e", "us-east-1f"]
}

variable "aws_instance_types" {
  description = <<DESC
Instance types to check against the availability zone of the created subnet.
If the availability zone doesn't support one or more of the given instance types,
error `no EC2 Instance Type Offerings found matching criteria` will be thrown directly.
DESC
  type        = list(string)
  default     = []
}

variable "aws_subnet_cidr" {
  description = "Subnet CIDR block to create subnet with, within the created VPC. If left empty, a random CIDR block will be used"
  type        = string
  default     = ""
}

variable "aws_dns_servers" {
  description = "DNS servers to use. If not specified, the default AWS DNS server will be used."
  type        = list(string)
  default     = []
}
