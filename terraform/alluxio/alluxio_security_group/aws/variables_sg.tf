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

variable "vpc_id" {
  description = "Id of VPC to create security group in"
  type        = string
}

variable "alluxio_web_ui_rule_cidr_blocks" {
  description = <<DESC
List of CIDR block to set as an ingress rule for Alluxio Web UI port.
This cannot contain 0.0.0.0/0 because EMR will fail to start.
A CIDR block representing your IP address is typically in the format IP_ADDRESS/32.
If this is left unset, the Alluxio Web UI will not be accessible,
but the security group can be updated after creation to open access.
DESC
  type        = list(string)
  default     = []
}
