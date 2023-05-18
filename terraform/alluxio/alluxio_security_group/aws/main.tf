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

resource "aws_security_group" "emr_managed" {
  count       = var.enabled ? 1 : 0
  name        = "${local.name_prefix}-emr-security-group"
  description = "Security group for Alluxio compute cluster"
  vpc_id      = var.vpc_id

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
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "alluxio" {
  count       = var.enabled ? 1 : 0
  name        = "${local.name_prefix}-alluxio-security-group"
  description = "Security group for Alluxio compute cluster"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = length(var.alluxio_web_ui_rule_cidr_blocks) > 0 ? [""] : []
    content {
      description = "Alluxio web UI default port"
      from_port   = 19999
      to_port     = 19999
      protocol    = "TCP"
      cidr_blocks = var.alluxio_web_ui_rule_cidr_blocks
    }
  }

  dynamic "ingress" {
    for_each = length(var.alluxio_web_ui_rule_cidr_blocks) > 0 ? [""] : []
    content {
      description = "Prometheus Web UI default port"
      from_port   = 9090 
      to_port     = 9090 
      protocol    = "TCP"
      cidr_blocks = var.alluxio_web_ui_rule_cidr_blocks
    }
  }

  dynamic "ingress" {
    for_each = length(var.alluxio_web_ui_rule_cidr_blocks) > 0 ? [""] : []
    content {
      description = "Grafana Web UI default port"
      from_port   = 3000 
      to_port     = 3000 
      protocol    = "TCP"
      cidr_blocks = var.alluxio_web_ui_rule_cidr_blocks
    }
  }

  dynamic "ingress" {
    for_each = length(var.alluxio_web_ui_rule_cidr_blocks) > 0 ? [""] : []
    content {
      description = "Presto web UI default port"
      from_port   = 8889
      to_port     = 8889
      protocol    = "TCP"
      cidr_blocks = var.alluxio_web_ui_rule_cidr_blocks
    }
  }

  dynamic "ingress" {
    for_each = length(var.alluxio_web_ui_rule_cidr_blocks) > 0 ? [""] : []
    content {
      description = "Spark History Server web UI default port"
      from_port   = 8020
      to_port     = 8020
      protocol    = "TCP"
      cidr_blocks = var.alluxio_web_ui_rule_cidr_blocks
    }
  }
}
