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

output "hadoop_master_private_dns" {
  value       = data.aws_instance.hadoop_master.private_dns
  description = "Master private dns of the hadoop cluster master"
}

output "hadoop_master_public_dns" {
  value       = data.aws_instance.hadoop_master.public_dns
  description = "Master public dns of the hadoop cluster master"
}

output "emr_cluster_id" {
  value       = length(aws_emr_cluster.emr_cluster) == 0 ? "" : aws_emr_cluster.emr_cluster[0].id
  description = "ID of EMR cluster"
}
