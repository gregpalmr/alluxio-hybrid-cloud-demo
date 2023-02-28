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

variable "alluxio_tarball_url" {
  description = "Alluxio tarball download url"
  type        = string
  default =     "https://downloads.alluxio.io/protected/files/alluxio-enterprise-trial.tar.gz"
}

variable "alluxio_additional_properties" {
  description = "A string containing a delimited set of properties which should be added to the alluxio-site.properties file. The delimiter by default is a semicolon ';'."
  type        = string
  default     = ""
}

variable "alluxio_active_sync_list" {
  description = "A string containing a delimited set of Alluxio paths where UFS metadata will be periodically synced with the Alluxio namespace. The delimiter by default is a semicolon ';'."
  type        = string
  default     = "/"
}

variable "alluxio_nvme_percentage" {
  description = "Percentage of the instance attached NVMe SSD to be configured as Alluxio worker storage. Set this variable when your worker instance type contains NVMe SSDs by default."
  type        = number
  default     = 0
}

variable "alluxio_working_bucket" {
  description = "S3 bucket to be used as alluxio working bucket and emr log place. The bucket must be created in the same region as the emr cluster"
  type        = string
  default     = null
}

variable "alluxio_bootstrap_s3_uri" {
  description = "S3 uri of the alluxio bootstrap script"
  type        = string
  default     = null
}

variable "presto_bootstrap_s3_uri" {
  description = "S3 uri of the presto bootstrap script"
  type        = string
  default     = null
}

variable "on_prem_hdfs_address" {
  description = "On-prem hdfs address (e.g. hdfs://<on_prem_hdfs_master_hostname>:8020/path/to/mount) for alluxio to connect to. "
  type        = string
  default     = ""
}

variable "on_prem_hms_address" {
  description = "On-prem hive metastore address (e.g. thrift://<hive_metastore_host>:9083) for Presto and Spark to connect to"
  type        = string
  default     = ""
}

variable "on_prem_core_site_uri" {
  description = "An s3:// or http(s):// URI to download on_prem core-site.xml file from. If provided, Presto and Alluxio will be configured with the given core-site.xml"
  type        = string
  default     = ""
}

variable "on_prem_hdfs_site_uri" {
  description = "An s3:// or http(s):// URI to download on_prem hdfs-site.xml file from. If provided, Presto and Alluxio will be configured with the given hdfs-site.xml"
  type        = string
  default     = ""
}

// Valid values include cdh-5.11,cdh-5.12,cdh-5.13,cdh-5.14,cdh-5.15,cdh-5.16,cdh-5.6,cdh-5.8,cdh-6.0,cdh-6.1,cdh-6.2,cdh-6.3,hadoop-2.2,hadoop-2.3,hadoop-2.4,hadoop-2.5,hadoop-2.6,hadoop-2.7,hadoop-2.8,hadoop-2.9,hadoop-3.0,hadoop-3.1,hadoop-3.2,hdp-2.0,hdp-2.1,hdp-2.2,hdp-2.3,hdp-2.4,hdp-2.5,hdp-2.6,hdp-3.0,hdp-3.1
variable "hdfs_version" {
  description = "Version of the hdfs to connect to"
  type        = string
  default     = "hadoop-2.8"
}
