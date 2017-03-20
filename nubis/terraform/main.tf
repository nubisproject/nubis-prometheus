provider "aws" {
  profile = "${var.aws_profile}"
  region  = "${var.aws_region}"
}

data "atlas_artifact" "nubis-prometheus" {
  count = "${var.enabled}"
  name  = "nubisproject/nubis-prometheus"
  type  = "amazon.image"

  metadata {
    project_version = "${var.nubis_version}"
  }
}

module "uuid" {
  source = "github.com/nubisproject/nubis-deploy///modules/uuid?ref=master"

  enabled = "${var.enabled}"

  aws_profile = "${var.aws_profile}"
  aws_region  = "${var.aws_region}"

  name = "prometheus"

  environments = "${var.environments}"

  lambda_uuid_arn = "${var.lambda_uuid_arn}"
}

resource "aws_s3_bucket" "prometheus" {
  count = "${var.enabled * length(split(",", var.environments))}"

  lifecycle {
    create_before_destroy = true
  }

  bucket = "prometheus-${element(split(",",var.environments), count.index)}-${element(split(",",module.uuid.uuids), count.index)}"

  acl           = "private"
  force_destroy = true

  versioning {
    enabled = true
  }

  tags = {
    Name        = "${var.project}-${element(split(",",var.environments), count.index)}"
    Region      = "${var.aws_region}"
    Environment = "${element(split(",",var.environments), count.index)}"
  }
}

resource "aws_security_group" "prometheus" {
  count = "${var.enabled * length(split(",", var.environments))}"

  lifecycle {
    create_before_destroy = true
  }

  name_prefix = "${var.project}-${element(split(",",var.environments), count.index)}-"
  description = "Prometheus rules"

  vpc_id = "${element(split(",",var.vpc_ids), count.index)}"

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    security_groups = [
      "${element(split(",",var.ssh_security_groups), count.index)}",
    ]
  }

  # Traefik
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    security_groups = [
      "${element(split(",",var.ssh_security_groups), count.index)}",
      "${element(aws_security_group.elb-traefik.*.id, count.index)}",
    ]
  }

  # Traefik 
  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    security_groups = [
      "${element(split(",",var.ssh_security_groups), count.index)}",
      "${element(aws_security_group.elb-traefik.*.id, count.index)}",
    ]
  }

  # Traefik  Admin
  ingress {
    from_port = 8082
    to_port   = 8082
    protocol  = "tcp"
    self      = true

    cidr_blocks = ["0.0.0.0/0"]

    security_groups = [
      "${element(split(",",var.ssh_security_groups), count.index)}",
    ]
  }

  # Alertmanager
  ingress {
    from_port = 9093
    to_port   = 9093
    protocol  = "tcp"
    self      = true

    cidr_blocks = ["0.0.0.0/0"]

    security_groups = [
      "${element(split(",",var.ssh_security_groups), count.index)}",
    ]
  }

  # Grafana
  ingress {
    from_port = 3000
    to_port   = 3000
    protocol  = "tcp"

    self = true

    security_groups = [
      "${element(split(",",var.ssh_security_groups), count.index)}",
    ]
  }

  # Put back Amazon Default egress all rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${element(split(",",var.environments), count.index)}"
    Region      = "${var.aws_region}"
    Environment = "${element(split(",",var.environments), count.index)}"
  }
}

resource "aws_iam_instance_profile" "prometheus" {
  count = "${var.enabled * length(split(",", var.environments))}"

  lifecycle {
    create_before_destroy = true
  }

  name = "${var.project}-${element(split(",",var.environments), count.index)}-${var.aws_region}"

  roles = [
    "${element(aws_iam_role.prometheus.*.name, count.index)}",
  ]
}

resource "aws_iam_role" "prometheus" {
  count = "${var.enabled * length(split(",", var.environments))}"

  lifecycle {
    create_before_destroy = true
  }

  name = "${var.project}-${element(split(",",var.environments), count.index)}-${var.aws_region}"
  path = "/nubis/${var.project}/"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "prometheus" {
  count = "${var.enabled * length(split(",", var.environments))}"

  lifecycle {
    create_before_destroy = true
  }

  name = "${var.project}-bucket-${element(split(",",var.environments), count.index)}-${var.aws_region}"
  role = "${element(aws_iam_role.prometheus.*.id, count.index)}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
              {
              "Sid": "SeeAllBuckets",
              "Effect": "Allow",
              "Action": "s3:ListAllMyBuckets",
              "Resource": "arn:aws:s3:::*"
            },
            {
              "Sid": "ListInOurBuckets",
              "Effect": "Allow",
              "Action": [
                "s3:ListBucket"
              ],
              "Resource": [
	          "${element(aws_s3_bucket.prometheus.*.arn, count.index)}"
	       ]
            },
            {
              "Sid": "FullAccessToOurBucket",
              "Effect": "Allow",
              "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
              ],
              "Resource": "${element(aws_s3_bucket.prometheus.*.arn, count.index)}/*"
            }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "grafana" {
  count = "${var.enabled * length(split(",", var.environments))}"

  lifecycle {
    create_before_destroy = true
  }

  name = "${var.project}-grafana-${element(split(",",var.environments), count.index)}-${var.aws_region}"
  role = "${element(aws_iam_role.prometheus.*.id, count.index)}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
            {
              "Sid": "CloudWatchReadOnly",
              "Effect": "Allow",
              "Action": [
                "cloudwatch:List*",
                "cloudwatch:Get*",
                "cloudwatch:Describe*"
              ],
              "Resource": "*"
            }
  ]
}
POLICY
}

resource "aws_launch_configuration" "prometheus" {
  count = "${var.enabled * length(split(",", var.environments))}"

  name_prefix = "${var.project}-${element(split(",",var.environments), count.index)}-${var.aws_region}-"
  
  image_id = "${data.atlas_artifact.nubis-prometheus.metadata_full["region-${var.aws_region}"]}"

  instance_type        = "t2.small"
  key_name             = "${var.key_name}"
  iam_instance_profile = "${element(aws_iam_instance_profile.prometheus.*.name, count.index)}"

  enable_monitoring    = false

  root_block_device = {
    volume_size = "32"
    volume_type = "gp2"
    delete_on_termination = true
  }

  security_groups = [
    "${element(aws_security_group.prometheus.*.id, count.index)}",
    "${element(split(",",var.internet_access_security_groups), count.index)}",
    "${element(split(",",var.shared_services_security_groups), count.index)}",
    "${element(split(",",var.ssh_security_groups), count.index)}",
    "${element(split(",",var.monitoring_security_groups), count.index)}",
  ]

  user_data = <<EOF
NUBIS_PROJECT="${var.project}"
NUBIS_ENVIRONMENT="${element(split(",",var.environments), count.index)}"
NUBIS_ACCOUNT="${var.service_name}"
NUBIS_TECHNICAL_CONTACT="${var.technical_contact}"
NUBIS_DOMAIN="${var.nubis_domain}"
NUBIS_PROMETHEUS_LIVE_APP="${var.live_app}"
NUBIS_PROMETHEUS_BUCKET="${element(aws_s3_bucket.prometheus.*.id, count.index)}"
NUBIS_PROMETHEUS_SLACK_URL="${var.slack_url}"
NUBIS_PROMETHEUS_SLACK_CHANNEL="${var.slack_channel}"
NUBIS_PROMETHEUS_NOTIFICATION_EMAIL="${var.notification_email}"
NUBIS_PROMETHEUS_PAGERDUTY_SERVICE_KEY="${var.pagerduty_service_key}"
NUBIS_PROMETHEUS_SINK_SLACK_URL="${var.sink_slack_url}"
NUBIS_PROMETHEUS_SINK_SLACK_CHANNEL="${var.sink_slack_channel}"
NUBIS_PROMETHEUS_SINK_NOTIFICATION_EMAIL="${var.sink_notification_email}"
NUBIS_PROMETHEUS_SINK_PAGERDUTY_SERVICE_KEY="${var.sink_pagerduty_service_key}"
NUBIS_SUDO_GROUPS="${var.nubis_sudo_groups}"
NUBIS_USER_GROUPS="${var.nubis_user_groups}"
EOF
}

resource "aws_autoscaling_group" "prometheus" {
  count = "${var.enabled * length(split(",", var.environments))}"

  #XXX: Fugly, assumes 3 subnets per environments, bad assumption, but valid ATM
  vpc_zone_identifier = [
    "${element(split(",",var.subnet_ids), (count.index * 3) + 0 )}",
    "${element(split(",",var.subnet_ids), (count.index * 3) + 1 )}",
    "${element(split(",",var.subnet_ids), (count.index * 3) + 2 )}",
  ]

  name                      = "${var.project}-${element(split(",",var.environments), count.index)} (LC ${element(aws_launch_configuration.prometheus.*.name, count.index)})"
  max_size                  = "2"
  min_size                  = "1"
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = "1"
  force_delete              = true
  launch_configuration      = "${element(aws_launch_configuration.prometheus.*.name, count.index)}"

  wait_for_capacity_timeout = "60m"

  load_balancers = [
    "${element(aws_elb.traefik.*.name, count.index)}",
  ]

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]

  tag {
    key                 = "Name"
    value               = "Prometheus (${var.nubis_version}) for ${var.service_name} in ${element(split(",",var.environments), count.index)}"
    propagate_at_launch = true
  }

  tag {
    key                 = "ServiceName"
    value               = "${var.project}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "${element(split(",",var.environments), count.index)}"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "elb-traefik" {
  count = "${var.enabled * length(split(",", var.environments))}"

  # * length(split(",",var.public_subnet_ids))}"

  lifecycle {
    create_before_destroy = true
  }
  name        = "elb-traefik-${element(split(",",var.environments), count.index)}"
  description = "Allow inbound traffic for traefik"
  vpc_id      = "${element(split(",",var.vpc_ids), count.index)}"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Put back Amazon Default egress all rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elb" "traefik" {
  count = "${var.enabled * length(split(",", var.environments))}"

  #XXX
  lifecycle {
    create_before_destroy = true
  }

  name = "traefik-${element(split(",",var.environments), count.index)}"

  #XXX: Fugly, assumes 3 subnets per environments, bad assumption, but valid ATM
  subnets = [
    "${element(split(",",var.public_subnet_ids), (count.index * 3) + 0 )}",
    "${element(split(",",var.public_subnet_ids), (count.index * 3) + 1 )}",
    "${element(split(",",var.public_subnet_ids), (count.index * 3) + 2 )}",
  ]

  # This is an internet facing ELB
  internal = false

  listener {
    instance_port     = 80
    instance_protocol = "tcp"
    lb_port           = 80
    lb_protocol       = "tcp"
  }

  listener {
    instance_port     = 443
    instance_protocol = "tcp"
    lb_port           = 443
    lb_protocol       = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:80"
    interval            = 30
  }

  cross_zone_load_balancing = true

  security_groups = [
    "${element(aws_security_group.elb-traefik.*.id, count.index)}",
  ]

  tags = {
    Name        = "traefik-${element(split(",",var.environments), count.index)}"
    Region      = "${var.aws_region}"
    Environment = "${element(split(",",var.environments), count.index)}"
  }
}

resource "aws_route53_record" "traefik-wildcard" {
  count   = "${var.enabled * length(split(",", var.environments))}"
  zone_id = "${var.zone_id}"
  name    = "*.mon.${element(split(",",var.environments), count.index)}"
  type    = "CNAME"
  ttl     = "30"

  records = [
    "mon.${element(split(",",var.environments), count.index)}.${var.aws_region}.${var.service_name}.${var.nubis_domain}",
  ]
}

resource "aws_route53_record" "traefik" {
  count   = "${var.enabled * length(split(",", var.environments))}"
  zone_id = "${var.zone_id}"

  name = "mon.${element(split(",",var.environments), count.index)}"
  type = "A"

  alias {
    name                   = "${element(aws_elb.traefik.*.dns_name,count.index)}"
    zone_id                = "${element(aws_elb.traefik.*.zone_id,count.index)}"
    evaluate_target_health = true
  }
}

# This null resource is responsible for storing our secret authentication into KMS
resource "null_resource" "secrets" {
  count = "${var.enabled * length(split(",", var.environments))}"

  lifecycle {
    create_before_destroy = true
  }

  # Important to list here every variable that affects what needs to be put into KMS
  triggers {
    secret = "${var.credstash_key}"

    region        = "${var.aws_region}"
    version       = "${var.nubis_version}"
    federation    = "${data.template_file.federation.rendered}"
    password      = "${var.password}"
    context       = "-E region:${var.aws_region} -E environment:${element(split(",",var.environments), count.index)} -E service:${var.project}"
    unicreds      = "unicreds -r ${var.aws_region} put -k ${var.credstash_key} ${var.project}/${element(split(",",var.environments), count.index)}"
    unicreds_file = "unicreds -r ${var.aws_region} put-file -k ${var.credstash_key} ${var.project}/${element(split(",",var.environments), count.index)}"
  }

  provisioner "local-exec" {
    command = "${self.triggers.unicreds}/federation/password ${data.template_file.federation.rendered} ${self.triggers.context}"
  }

  provisioner "local-exec" {
    command = "${self.triggers.unicreds}/admin/password ${data.template_file.password.rendered} ${self.triggers.context}"
  }
}

# TF 0.6 limitation

# Used as a stable random-number generator since we don't have random provider yet

resource "tls_private_key" "federation" {
  algorithm = "ECDSA"

  lifecycle {
    create_before_destroy = true
  }
}

resource "tls_private_key" "password" {
  algorithm = "ECDSA"

  lifecycle {
    create_before_destroy = true
  }
}

data "template_file" "federation" {
  template = "$${password}"

  vars = {
    password = "${replace(tls_private_key.federation.id,"/^(.{32}).*/","$1")}"
  }
}

data "template_file" "password" {
  template = "$${password}"

  vars = {
    password = "${coalesce(var.password, replace(tls_private_key.federation.id,"/^(.{32}).*/","$1"))}"
  }
}
