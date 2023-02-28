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

variable "kerberos_type" {
  description = "Name of kerberos type, where empty string indicates no kerberos authentication"
  type        = string
  default     = ""
}

variable "kerberos_configuration" {
  description = "Map of kerberos configuration properties, output from kerberos_config module"
  type        = map(string)
  default     = {}
}

variable "emr_security_configuration_string" {
  description = "String to set as the configuration field of the aws_emr_security_configuration resource, output from kerberos_config module"
  type        = string
  default     = ""
}
