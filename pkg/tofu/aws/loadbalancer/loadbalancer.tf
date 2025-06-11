provider "aws" {
  region = var.region
}

data "aws_instances" "kubernetes" {
  instance_tags = var.instance_tags
}

data "aws_vpc" "vpc" {
  id = var.vpc
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  lower = true
  upper = false
}

resource "random_string" "prefix" {
  length  = 2
  special = false
  lower = true
  upper = false
}

locals {
  http_listeners = {
    http = {
      port            = 80
      protocol        = "HTTP"
      forward = {
        target_group_key = "smp-instance"
      }
    }
  }
  https_listeners = {
    # https= {
    #   port     = 443
    #   protocol = "HTTPS"
    #   forward = {
    #     target_group_key = "smp-instance"
    #   }
    #   certificate_arn = "${var.existing_certificate_id == "" ? aws_acm_certificate.cert[0].arn : var.existing_certificate_id}"
    # }
  }
  loadbalancer_listeners = merge(local.http_listeners, var.tls_enabled ? local.https_listeners : {})

  security_group_ingress_rules_http = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  security_group_ingress_rules_https = {
    all_https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      description = "HTTPS web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  security_group_ingress_rules = merge(local.security_group_ingress_rules_http, var.tls_enabled ? local.security_group_ingress_rules_https : {})
}

module "alb" {
  source = "terraform-aws-modules/alb/aws"

  name    = "smp-alb-${random_string.suffix.result}"
  vpc_id  = var.vpc
  subnets = var.subnets

  # Security Group
  security_group_ingress_rules = local.security_group_ingress_rules
  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = data.aws_vpc.vpc.cidr_block
    }
  }
  enable_deletion_protection = false

  listeners = local.loadbalancer_listeners

  target_groups = {
    smp-instance = {
      name_prefix      = "smp-${random_string.prefix.result}"
      protocol         = "HTTP"
      port             = var.harness_node_port
      create_attachment = false
      target_type      = "instance"
      target_id        = "i-0f6d38a07d50d080f"
      health_check = {
          enabled = true
          healthy_threshold = 2
          interval = 30
          matcher = 404
          path = "/health"
        }
      
    }
  }

  tags = var.tags
}

resource "aws_lb_target_group_attachment" "kubernetes" {
  # covert a list of instance objects to a map with instance ID as the key, and an instance
  # object as the value.
  for_each = toset(data.aws_instances.kubernetes.ids)

  target_group_arn = module.alb.target_groups["smp-instance"].arn
  target_id        = each.value
  port             = var.harness_node_port
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = module.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${var.existing_certificate_id == "" ? aws_acm_certificate.cert[0].arn : var.existing_certificate_id}"

  default_action {
    type             = "forward"
    target_group_arn = module.alb.target_groups["smp-instance"].arn
  }

  tags = var.tags

  depends_on = [ aws_acm_certificate.cert, module.alb ]
}

output "dns_name" {
  value = module.alb.dns_name
}

output "dns_zone_id" {
  value = module.alb.zone_id
}
