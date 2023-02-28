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

// Name variables
// --------------
variable "name" {
  description = "Name to prefix resources with. Random string will be used if left blank."
  type        = string
  default     = ""
}

variable "randomize_name" {
  description = "If true, appends a random string to name in order to create unique resources across multiple runs. Recommended to set to false for production."
  type        = bool
  default     = true
}
