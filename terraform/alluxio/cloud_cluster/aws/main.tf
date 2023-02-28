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
  kerberos_enabled       = var.kerberos_type != ""
  finalized_applications = length(var.applications) == 0 ? ["Hadoop", "Hive"] : var.applications
  ad_enabled             = lookup(var.kerberos_configuration, "ad_realm", "") != ""
  default_config_json    = var.master_config.instance_count >= 3 ? file("${path.module}/config/ha_config.json") : file("${path.module}/config/single_master_config.json")
  emr_config_json        = var.emr_configurations_json_file != "" ? file(var.emr_configurations_json_file) : local.default_config_json
}

// HA clusters do not support having a Cluster Dedicated KDC.  Only External KDC is supported.
resource "null_resource" "validate_ha_kdc_flavor" {
  count = var.enabled ? 1 : 0
  triggers = {
    always_trigger = timestamp()
  }
  provisioner "local-exec" {
    command = <<CMD
if [[ "${local.kerberos_enabled}" == "true" ]] && [[ "${var.kerberos_type}" != "external_kdc" ]] && [[ "${var.master_config.instance_count}" -ge "3" ]];
  then echo "Cluster Dedicated KDC is not supported in emr cluster with HA enabled" && exit 1;
fi
CMD
  }
}

resource "aws_emr_cluster" "emr_cluster" {
  count = var.enabled ? 1 : 0
  name  = "${local.name_prefix}_emr_cluster"

  applications           = local.finalized_applications
  log_uri                = var.log_uri
  release_label          = var.emr_release_label
  security_configuration = local.kerberos_enabled ? aws_emr_security_configuration.emr_security_config[0].name : null
  service_role           = "EMR_DefaultRole"
  ebs_root_volume_size   = var.ebs_root_volume_size
  tags = {
    Name = "${local.name_prefix}-Cluster"
  }

  ec2_attributes {
    key_name                          = var.aws_key_pair_name
    subnet_id                         = var.aws_subnet_id
    emr_managed_master_security_group = var.aws_security_group_id
    emr_managed_slave_security_group  = var.aws_security_group_id
    additional_master_security_groups = join(",", var.additional_security_group_ids)
    additional_slave_security_groups  = join(",", var.additional_security_group_ids)
    instance_profile                  = aws_iam_instance_profile.emr_profile[0].arn
  }

  master_instance_group {
    instance_type  = var.master_config.instance_type
    instance_count = var.master_config.instance_count
    bid_price      = var.masters_spot_price == 0 ? null : var.masters_spot_price
    ebs_config {
      size                 = var.master_config.ebs_volume_size
      type                 = "gp2"
      volumes_per_instance = 1
    }
  }

  core_instance_group {
    instance_type  = var.worker_config.instance_type
    instance_count = var.worker_config.instance_count
    bid_price      = var.workers_spot_price == 0 ? null : var.workers_spot_price
    ebs_config {
      size                 = var.worker_config.ebs_volume_size
      type                 = "gp2"
      volumes_per_instance = 1
    }
  }

  dynamic "bootstrap_action" {
    for_each = var.bootstrap_actions
    content {
      path = bootstrap_action.value.path
      name = bootstrap_action.value.name
      args = bootstrap_action.value.args
    }
  }

  dynamic "kerberos_attributes" {
    // When the given list is empty, the inner block will be removed
    for_each = local.kerberos_enabled == true ? [""] : []
    content {
      kdc_admin_password                   = var.kerberos_configuration["kdc_admin_password"]
      realm                                = var.kerberos_configuration["default_realm"]
      ad_domain_join_password              = local.ad_enabled ? var.kerberos_configuration["ad_domain_join_password"] : null
      ad_domain_join_user                  = local.ad_enabled ? var.kerberos_configuration["ad_domain_join_user"] : null
      cross_realm_trust_principal_password = local.ad_enabled ? var.kerberos_configuration["ad_cross_realm_trust_principal_password"] : null
    }
  }

  configurations_json = local.emr_config_json
}

resource "aws_emr_security_configuration" "emr_security_config" {
  count         = var.enabled ? (local.kerberos_enabled ? 1 : 0) : 0
  name          = "${local.name_prefix}_security_config"
  configuration = var.emr_security_configuration_string
}

data "aws_instance" "hadoop_master" {
  depends_on = [aws_emr_cluster.emr_cluster]
  filter {
    name   = "dns-name"
    values = length(aws_emr_cluster.emr_cluster) == 0 ? [] : [aws_emr_cluster.emr_cluster[0].master_public_dns]
  }
}

// IAM Role for EC2 Instance Profile
// https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-iam-role-for-ec2.html
resource "aws_iam_role" "iam_emr_profile_role" {
  count = var.enabled ? 1 : 0
  name  = "${local.name_prefix}_iam_emr_profile_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "ec2.amazonaws.com",
          "s3.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "cal_attach_emr_ec2_role" {
  count      = var.enabled ? 1 : 0
  role       = aws_iam_role.iam_emr_profile_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
}

resource "aws_iam_instance_profile" "emr_profile" {
  count = var.enabled ? 1 : 0
  name  = "${local.name_prefix}_emr_profile"
  role  = aws_iam_role.iam_emr_profile_role[0].name
}
