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

provider "aws" {
  alias   = "aws_compute"
  region  = var.compute_region
  version = "~> 2.56"
}

provider "aws" {
  alias   = "aws_on_prem"
  region  = var.on_prem_region
  version = "~> 2.56"
}

resource "random_id" "name_suffix" {
  byte_length = 4
}

locals {
  presuffix_name = var.name == "" ? random_id.name_suffix.hex : var.name
  name_prefix    = var.randomize_name ? "${local.presuffix_name}_${random_id.name_suffix.hex}" : local.presuffix_name

  compute_name_prefix = "${local.name_prefix}-compute"
  on_prem_name_prefix = "${local.name_prefix}-onprem"

  shared_bucket_name_replaced = replace("shared-${local.name_prefix}-bucket", "_", "-") // underscores are not allowed
  shared_bucket_name_lowered  = lower(local.shared_bucket_name_replaced)                // uppercase letters not allowed
}

resource "aws_s3_bucket" "shared_s3_bucket" {
  // the shared s3 bucket can be in any region
  // make sure the objects that upload to the bucket belong to the aws provider of the bucket region
  // bucket in compute region can provide better performance
  provider      = aws.aws_compute
  bucket        = local.shared_bucket_name_lowered
  force_destroy = true
}

// on-prem HDFS mock cluster resources
locals {
  on_prem_master_instance_type = var.on_prem_master_instance_type
  on_prem_worker_instance_type = var.on_prem_worker_instance_type
  on_prem_instance_types       = [local.on_prem_master_instance_type, local.on_prem_worker_instance_type]
  on_prem_conf_s3_uri          = "s3://${aws_s3_bucket.shared_s3_bucket.bucket}/onpremConf/"
  on_prem_bootstrap_action = {
    name = "bootstrap_onprem"
    path = "s3://${aws_s3_bucket.shared_s3_bucket.bucket}/${aws_s3_bucket_object.on_prem_bootstrap.key}"
    args = [local.on_prem_conf_s3_uri]
  }
}

module "vpc_on_prem" {                             
  source = "./alluxio/vpc_with_internet/aws"
  providers = {
    aws = aws.aws_on_prem
  }
  aws_availability_zone_blacklist = var.availability_zone_blacklist
  aws_instance_types              = local.on_prem_instance_types
}

resource "aws_security_group" "security_group_on_prem" {
  provider    = aws.aws_on_prem
  name        = "${local.on_prem_name_prefix}-security-group"
  description = "Allow inbound traffic"
  vpc_id      = module.vpc_on_prem.vpc_id

  ingress {
    description = "Allow all internal traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = [var.local_ip_as_cidr]
  }
}

module "aws_key_pair_on_prem" {
  source  = "terraform-aws-modules/key-pair/aws"
  version = "0.6.0"
  providers = {
    aws = aws.aws_on_prem
  }

  create_key_pair = var.on_prem_key_pair_name == null
  key_name        = var.on_prem_key_pair_name == null ? "${local.on_prem_name_prefix}-keypair" : var.on_prem_key_pair_name
  public_key      = file(var.ssh_public_key_file_path)
}

resource "aws_s3_bucket_object" "on_prem_bootstrap" {
  provider = aws.aws_compute
  bucket   = aws_s3_bucket.shared_s3_bucket.bucket
  key      = "on-prem-emr-bootstrap.sh"
  source   = "${path.cwd}/scripts/on-prem-emr-bootstrap.sh"
}

module "emr_on_prem" {
  source = "./alluxio/cloud_cluster/aws"
  providers = {
    aws = aws.aws_on_prem
  }

  name                  = "${local.on_prem_name_prefix}-onprem"
  randomize_name        = var.randomize_name
  aws_key_pair_name     = module.aws_key_pair_on_prem.this_key_pair_key_name
  aws_security_group_id = aws_security_group.security_group_on_prem.id
  aws_subnet_id         = module.vpc_on_prem.subnet_id
  bootstrap_actions     = [local.on_prem_bootstrap_action]
  emr_release_label     = var.on_prem_release_label

  master_config = {
    ebs_volume_size = 32
    instance_count  = 1
    instance_type   = local.on_prem_master_instance_type
  }
  worker_config = {
    ebs_volume_size = 64
    instance_count  = 3
    instance_type   = local.on_prem_worker_instance_type
  }
}

// compute cluster resources
locals {
  compute_master_instance_type = var.compute_master_instance_type
  compute_worker_instance_type = var.compute_worker_instance_type
  compute_instance_types       = [local.compute_master_instance_type, local.compute_worker_instance_type]
}

module "vpc_compute" {                             
  source = "./alluxio/vpc_with_internet/aws"
  providers = {
    aws = aws.aws_compute
  }
  aws_availability_zone_blacklist = var.availability_zone_blacklist
  aws_instance_types              = local.compute_instance_types
}

module "security_group_compute" {                       
  source = "./alluxio/alluxio_security_group/aws"
  providers = {
    aws = aws.aws_compute
  }
  name                            = local.compute_name_prefix
  randomize_name                  = var.randomize_name
  vpc_id                          = module.vpc_compute.vpc_id
  alluxio_web_ui_rule_cidr_blocks = var.local_ip_as_cidr != "" ? [var.local_ip_as_cidr] : []
}

module "aws_key_pair_compute" {
  source  = "terraform-aws-modules/key-pair/aws"
  version = "0.6.0"
  providers = {
    aws = aws.aws_compute
  }

  create_key_pair = var.compute_key_pair_name == null
  key_name        = var.compute_key_pair_name == null ? "${local.compute_name_prefix}-keypair" : var.compute_key_pair_name
  public_key      = file(var.ssh_public_key_file_path)
}

resource "aws_s3_bucket_object" "compute_alluxio_bootstrap" {
  provider = aws.aws_compute
  bucket   = aws_s3_bucket.shared_s3_bucket.bucket
  key      = "alluxio-emr.sh"
  source = "emr/alluxio-emr.sh"
}

resource "aws_s3_bucket_object" "compute_presto_bootstrap" {
  provider = aws.aws_compute
  bucket   = aws_s3_bucket.shared_s3_bucket.bucket
  key      = "presto-emr.sh"
  source = "emr/presto-emr.sh"
}

module "alluxio_compute" {
  source = "./alluxio/alluxio_cloud_cluster/aws"
  providers = {
    aws = aws.aws_compute
  }

  name                          = "${local.compute_name_prefix}-compute"
  randomize_name                = var.randomize_name
  aws_security_group_id         = module.security_group_compute.emr_managed_sg_id
  additional_security_group_ids = [module.security_group_compute.alluxio_sg_id]
  aws_subnet_id                 = module.vpc_compute.subnet_id
  aws_key_pair_name             = module.aws_key_pair_compute.this_key_pair_key_name

  alluxio_tarball_url      = var.alluxio_tarball_url
  alluxio_working_bucket   = aws_s3_bucket.shared_s3_bucket.bucket
  alluxio_bootstrap_s3_uri = "s3://${aws_s3_bucket.shared_s3_bucket.bucket}/${aws_s3_bucket_object.compute_alluxio_bootstrap.key}"
  presto_bootstrap_s3_uri  = "s3://${aws_s3_bucket.shared_s3_bucket.bucket}/${aws_s3_bucket_object.compute_presto_bootstrap.key}"

  on_prem_hdfs_address = "hdfs://${module.emr_on_prem.hadoop_master_private_dns}:8020/"
  on_prem_hms_address  = "thrift://${module.emr_on_prem.hadoop_master_private_dns}:9083"

  on_prem_core_site_uri = "${local.on_prem_conf_s3_uri}/core-site.xml"
  on_prem_hdfs_site_uri = "${local.on_prem_conf_s3_uri}/hdfs-site.xml"

  master_config = {
    ebs_volume_size = 32
    instance_count  = 1
    instance_type   = local.compute_master_instance_type
  }
  worker_config = {
    ebs_volume_size = 32
    instance_count  = 3
    instance_type   = local.compute_worker_instance_type
  }
  alluxio_nvme_percentage = 80
}

// vpc peering to connect the two clusters
module "vpc_peering" {                       
  source = "./alluxio/vpc_peering/aws"
  providers = {
    aws.cloud_compute = aws.aws_compute
    aws.on_prem       = aws.aws_on_prem
  }
  cloud_compute_vpc_id            = module.vpc_compute.vpc_id
  cloud_compute_subnet_id         = module.vpc_compute.subnet_id
  cloud_compute_security_group_id = module.security_group_compute.emr_managed_sg_id
  on_prem_vpc_id                  = module.vpc_on_prem.vpc_id
  on_prem_subnet_id               = module.vpc_on_prem.subnet_id
  on_prem_security_group_id       = aws_security_group.security_group_on_prem.id
}
