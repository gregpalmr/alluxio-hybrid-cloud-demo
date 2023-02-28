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

locals {
  kerberos_enabled = var.kerberos_type != ""

  // avoid conficts with resources already existing in this bucket
  working_path = lower(replace(local.name_prefix, "_", "-"))

  // shared variables between alluxio and presto bootstrap scripts
  onprem_conf_bootstrap_args = [
    var.on_prem_core_site_uri == "" ? "" : "-f ${var.on_prem_core_site_uri}",
    var.on_prem_hdfs_site_uri == "" ? "" : "-f ${var.on_prem_hdfs_site_uri}"
  ]
}

// alluxio bootstrap variables
locals {
  enable_manager_ui                 = "alluxio.web.manager.enabled=true"
  root_mount_hdfs_remote_pv         = "alluxio.master.mount.table.root.option.alluxio.underfs.hdfs.remote=true"
  remote_hdfs_additional_properties = var.on_prem_hdfs_address != "" ? local.root_mount_hdfs_remote_pv : ""

  // join the two property lists with ';' and trim ';' from both ends in case either list is empty
  all_additional_properties = trim(join(";", [
    local.enable_manager_ui,
    local.remote_hdfs_additional_properties,
    var.alluxio_additional_properties,
  ]), ";")

  // construct bootstrap args
  alluxio_default_bootstrap_args = [
    var.on_prem_hdfs_address == "" ? "s3://${var.alluxio_working_bucket}/${local.working_path}/" : var.on_prem_hdfs_address,
    "-d ${var.alluxio_tarball_url}",
    local.all_additional_properties == "" ? "" : "-p ${local.all_additional_properties}",
    var.alluxio_active_sync_list == "" ? "" : "-l ${var.alluxio_active_sync_list}",
    var.alluxio_nvme_percentage == 0 ? "" : "-n ${var.alluxio_nvme_percentage}",
    "-v ${var.hdfs_version}"
  ]
  // construct kerberos configuration map by putting additional keys into var.kerberos_configuration
  krb_config = merge(
    var.kerberos_configuration,
    {
      "s3_uri_krb_keytab" : "s3://${var.alluxio_working_bucket}/${local.working_path}/keytab",
    }
  )
  alluxio_kerberos_bootstrap_args = local.kerberos_enabled ? [
    "-k ${var.kerberos_type}",
    "-m ${jsonencode(local.krb_config)}",
  ] : []
  // join all arguments
  finalized_alluxio_bootstrap_args = concat(
    local.alluxio_default_bootstrap_args,
    local.onprem_conf_bootstrap_args,
    local.alluxio_kerberos_bootstrap_args,
  )
  alluxio_bootstrap_action = {
    name = "bootstrap_alluxio"
    path = var.alluxio_bootstrap_s3_uri
    args = local.finalized_alluxio_bootstrap_args
  }
}

// presto bootstrap variables
locals {
  presto_default_bootstrap_args = concat(["-c"],
    // add -u for hive metastore address only if provided
  var.on_prem_hms_address != "" ? ["-u ${var.on_prem_hms_address}"] : [])

  presto_kerberos_bootstrap_args = local.kerberos_enabled ? [
    "-k ${var.kerberos_type}",
    "-m ${jsonencode(local.krb_config)}",
  ] : []
  // join all arguments
  finalized_presto_bootstrap_args = concat(
    local.presto_default_bootstrap_args,
    local.presto_kerberos_bootstrap_args,
    local.onprem_conf_bootstrap_args
  )
  presto_bootstrap_action = {
    name = "bootstrap_presto"
    path = var.presto_bootstrap_s3_uri
    args = local.finalized_presto_bootstrap_args
  }
}

// resolve with variable values before setting in emr module
locals {
  finalized_applications = length(var.applications) == 0 ? ["Hadoop", "Hive", "Presto", "Spark"] : var.applications
  // note the trailing '/' at the end of the log uri is to avoid unnecessarily recreating the emr cluster
  // see https://github.com/terraform-providers/terraform-provider-aws/pull/1374
  finalized_log_uri = var.log_uri == "" ? "s3://${var.alluxio_working_bucket}/${local.working_path}/log/" : var.log_uri
  finalized_bootstrap_actions = concat(
    [local.alluxio_bootstrap_action, local.presto_bootstrap_action],
    var.bootstrap_actions,
  )
  finalized_emr_configuration_json_file = var.emr_configurations_json_file == "" ? "${path.module}/config/config.json" : ""
}

module "emr" {
  source = "../../cloud_cluster/aws"

  // meta
  enabled = var.enabled

  // name
  name           = var.name
  randomize_name = var.randomize_name

  // emr
  applications                 = local.finalized_applications
  bootstrap_actions            = local.finalized_bootstrap_actions
  emr_release_label            = var.emr_release_label
  emr_configurations_json_file = local.finalized_emr_configuration_json_file
  log_uri                      = local.finalized_log_uri
  ebs_root_volume_size         = var.ebs_root_volume_size
  master_config                = var.master_config
  masters_spot_price           = var.masters_spot_price
  worker_config                = var.worker_config
  workers_spot_price           = var.workers_spot_price

  // network connectivity
  aws_security_group_id         = var.aws_security_group_id
  additional_security_group_ids = var.additional_security_group_ids
  aws_subnet_id                 = var.aws_subnet_id
  aws_key_pair_name             = var.aws_key_pair_name

  // kerberos
  kerberos_type                     = var.kerberos_type
  emr_security_configuration_string = local.kerberos_enabled ? var.emr_security_configuration_string : ""
  kerberos_configuration            = local.kerberos_enabled ? var.kerberos_configuration : {}
}
