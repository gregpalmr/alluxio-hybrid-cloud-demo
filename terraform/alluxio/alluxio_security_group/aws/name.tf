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

// determine name_prefix for all resources created by the module
// name prefix should be valid in aws
// aws bucket name must be of lowercase letters, numbers, dots, and hyphens
resource "random_string" "name_presuffix" {
  length  = 6
  upper   = false
  lower   = true
  number  = false
  special = false
}

resource "random_id" "name_suffix" {
  byte_length = 4
}

locals {
  presuffix_name        = var.name == "" ? random_string.name_presuffix.result : var.name
  name_prefix_unchecked = var.randomize_name ? "${local.presuffix_name}-${random_id.name_suffix.hex}" : local.presuffix_name
  // Uppercase string and underscores are not allowed in gcp resources name and aws bucket name
  name_prefix = lower(replace(local.name_prefix_unchecked, "_", "-"))
}
