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

variable "ssh_public_key_file_path" {
  description = <<DESC
Path to SSH public key file to access instances via SSH.
This is ignored if key_pair_name is provided for the particular region.
If no key_pair_name is set and the value is null, no key pair will be associated with launched instances.
DESC
  default     = "~/.ssh/id_rsa.pub"
}

variable "compute_key_pair_name" {
  description = "Name of an existing key pair in the corresponding region, used for SSH access into launched instances"
  type        = string
  default     = null
}

variable "compute_region" {
  description = "Region to create compute cluster resources in"
  default     = "us-east-1"
}

variable "on_prem_key_pair_name" {
  description = "Name of an existing key pair in the corresponding region, used for SSH access into launched instances"
  type        = string
  default     = null
}

variable "on_prem_release_label" {
  // See https://docs.aws.amazon.com/emr/latest/ReleaseGuide/emr-hadoop.html
  description = "Use emr-5.29.0 for Hadoop 2 and emr-6.0.0 for Hadoop 3"
  type        = string
  default     = "emr-6.2.0" 
}

variable "on_prem_region" {
  description = "Region to create on-premise mock cluster resources in"
  type        = string
  default     = "us-west-1"
}

variable "on_prem_master_instance_type" {
  description = "ON-PREM STORAGE cluster master node instance_type"
  type        = string
  default     = "r4.4xlarge"
}

variable "on_prem_worker_instance_type" {
  description = "ON-PREM STORAGE cluster worker node instance_type"
  type        = string
  default     = "r4.4xlarge"
}

variable "compute_master_instance_type" {
  description = "CLOUD COMPUTE cluster master node instance_type"
  type        = string
  default     = "r4.4xlarge"
}

variable "compute_worker_instance_type" {
  description = "CLOUD COMPUTE cluster worker node instance_type"
  type        = string
  default     = "r5d.4xlarge"
}

variable "local_ip_as_cidr" {
  description = <<DESC
Your local IP address as a CIDR block to set as an ingress rule for Alluxio Web UI port.
This cannot be set to 0.0.0.0/0 because EMR will fail to start.
A CIDR block representing your IP address is typically in the format IP_ADDRESS/32.
If this is left unset, the Alluxio Web UI will not be accessible,
but the security group can be updated after creation to open access.
DESC
  type        = string
  default     = ""
}

variable "availability_zone_blacklist" {
  description = <<DESC
Availability zones to blacklist while creating subnet and related resources in.
Availability zones that don't support commonly used instance types and functionalities are blacklisted by default.
If your terraform apply throws error 'no EC2 Instance Type Offerings found matching criteria',
please add the availability zone of your created subnet in this list.
DESC
  type        = list(string)
  default     = ["us-east-1e", "us-east-1f"]
}

variable "alluxio_tarball_url" {
  description = "URL to alluxio tarball"
  type        = string
  default     = "https://downloads.alluxio.io/protected/files/alluxio-enterprise-trial.tar.gz"
}
