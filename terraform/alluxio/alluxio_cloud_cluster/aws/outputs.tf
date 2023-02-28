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

output "hadoop_master_public_dns" {
  value       = module.emr.hadoop_master_public_dns
  description = "Public DNS of the hadoop cluster master"
}

output "hadoop_master_private_dns" {
  value       = module.emr.hadoop_master_private_dns
  description = "Private DNS of the hadoop cluster master"
}
