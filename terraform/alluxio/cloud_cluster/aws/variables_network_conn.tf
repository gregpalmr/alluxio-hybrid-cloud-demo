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

// Network connectivity related variables
// ---------------------
variable "aws_key_pair_name" {
  description = "Name of AWS key pair to launch instances with. If left blank, SSH access to instances will not be available."
  type        = string
  default     = null
}

variable "aws_subnet_id" {
  description = "Id of VPC subnet to create EMR cluster in, output of vpc_with_internet module"
  type        = string
}

variable "aws_security_group_id" {
  description = "Id of primary security group. For EMR, this will be the EMR managed security group"
  type        = string
}

variable "additional_security_group_ids" {
  description = "List of additional security group ids to associate EMR instances with"
  type        = list(string)
  default     = []
}
