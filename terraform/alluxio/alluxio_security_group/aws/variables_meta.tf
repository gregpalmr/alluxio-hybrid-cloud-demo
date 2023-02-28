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

// Meta variables
// --------------
variable "depends_on_variable" {
  description = "DO NOT SET MANUALLY! Used for declaring a dependency on another module or resource for terraform to construct a plan correctly. Can be removed if modules had a depends_on field"
  type        = any
  default     = null
}

// TODO: placeholder until 0.13 when modules can be enabled/disabled
variable "enabled" {
  description = "Set to false to prevent creation of any resources."
  type        = bool
  default     = true
}
