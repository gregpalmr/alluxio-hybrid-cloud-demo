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

// EMR configuration variables
// ---------------------------
variable "applications" {
  description = "List of application names to deploy on EMR cluster. A non-empty list of applications will be set if value is left as an empty list"
  type        = list(string)
  default     = []
}

variable "bootstrap_actions" {
  description = "List of additional bootstrap actions to execute after provisioning"
  type = list(object({
    path = string
    name = string
    args = list(string)
  }))
  default = []
}

variable "emr_release_label" {
  // See https://docs.aws.amazon.com/emr/latest/ReleaseGuide/emr-hadoop.html
  description = "Use emr-5.29.0 for Hadoop 2 and emr-6.0.0 for Hadoop 3"
  type        = string
  default     = "emr-6.2.0"
}

variable "emr_configurations_json_file" {
  description = "JSON file containing configuration overrides for EMR applications. See https://docs.aws.amazon.com/emr/latest/ReleaseGuide/emr-configure-apps.html"
  type        = string
  default     = ""
}

variable "log_uri" {
  description = "S3 URL to write EMR logs to. The S3 bucket created for the cluster will be used if value is left empty."
  type        = string
  default     = ""
}

variable "ebs_root_volume_size" {
  description = "Size in GB to allocate for the root volume on each instance"
  type        = number
  default     = 32
}

variable "master_config" {
  description = "Master instance(s) configuration details"
  type = object({
    ebs_volume_size = number
    instance_count  = number
    instance_type   = string
  })
  default = {
    ebs_volume_size = 10
    instance_count  = 1
    instance_type   = "r4.xlarge"
  }
}

variable "masters_spot_price" {
  description = "Provision spot instances for masters with the given price. If set to 0, provisions on demand."
  type        = number
  default     = 0
}

variable "worker_config" {
  description = "Worker instance(s) configuration details"
  type = object({
    ebs_volume_size = number
    instance_count  = number
    instance_type   = string
  })
  default = {
    ebs_volume_size = 32
    instance_count  = 1
    instance_type   = "r4.xlarge"
  }
}

variable "workers_spot_price" {
  description = "Provision spot instances for workers with the given price. If set to 0, provisions on demand."
  type        = number
  default     = 0
}
