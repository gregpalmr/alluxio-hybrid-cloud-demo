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

output "vpc_id" {
  value       = length(aws_vpc.vpc) == 0 ? "" : aws_vpc.vpc[0].id
  description = "VPC id"
}

output "subnet_id" {
  value       = length(aws_subnet.subnet) == 0 ? "" : aws_subnet.subnet[0].id
  description = "Subnet id"
}

output "vpc_cidr" {
  value       = length(aws_vpc.vpc) == 0 ? "" : aws_vpc.vpc[0].cidr_block
  description = "CIDR block of VPC"
}
