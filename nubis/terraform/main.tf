provider "aws" {
  profile = "${var.aws_profile}"
  region  = "${var.aws_region}"
}

resource "atlas_artifact" "nubis-prometheus" {
  count = "${var.enabled}"
  name  = "nubisproject/nubis-prometheus"
  type  = "amazon.image"

  lifecycle {
    create_before_destroy = true
  }

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

variable "elb_account_ids" {
  default = {
    us-east-1      = "127311923021"
    us-west-1      = "027434742980"
    us-west-2      = "797873946194"
    eu-central-1   = "054676820928"
    ap-southeast-1 = "114774131450"
    ap-northeast-1 = "582318560864"
    ap-southeast-2 = "783225319266"
    ap-northeast-2 = "600734575887"
    sa-east-1      = "507241528517"
  }
}

resource "aws_s3_bucket" "elb" {
  count = "${var.enabled * length(split(",", var.environments))}"

  lifecycle {
    create_before_destroy = true
  }

  bucket = "prometheus-elb-${element(split(",",var.environments), count.index)}-${element(split(",",module.uuid.uuids), count.index)}"

  acl           = "private"
  force_destroy = true

  versioning {
    enabled = true
  }

  # Careful, resource must match the name of the bucket
  policy = <<POLICY
{
          "Version": "2008-10-17",
          "Statement": [
            {
              "Sid": "Allow ELBs to publish logs here",
              "Action": "s3:PutObject",
              "Effect": "Allow",
              "Resource": "arn:aws:s3:::prometheus-elb-${element(split(",",var.environments), count.index)}-${element(split(",",module.uuid.uuids), count.index)}/*",
              "Principal": {
                "AWS": "arn:aws:iam::${lookup(var.elb_account_ids, var.aws_region)}:root"
              }
            }
          ]
        }  
POLICY

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

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"

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
	          "${element(aws_s3_bucket.prometheus.*.arn, count.index)}",
		  "${element(aws_s3_bucket.elb.*.arn, count.index)}"
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
            },
	    {
              "Sid": "ReadingFromELBBucket",
              "Effect": "Allow",
              "Action": [
                "s3:GetObject"
              ],
              "Resource": "${element(aws_s3_bucket.elb.*.arn, count.index)}/*"
            }
  ]
}
POLICY
}

resource "aws_launch_configuration" "prometheus" {
  count = "${var.enabled * length(split(",", var.environments))}"

  lifecycle {
    create_before_destroy = true
  }

  name_prefix = "${var.project}-${element(split(",",var.environments), count.index)}-${var.aws_region}-"

  # Somewhat nasty, since Atlas doesn't have an elegant way to access the id for a region
  # the id is "region:ami,region:ami,region:ami"
  # so we split it all and find the index of the region
  # add on, and pick that element
  image_id = "${ element(split(",",replace(atlas_artifact.nubis-prometheus.id,":",",")) ,1 + index(split(",",replace(atlas_artifact.nubis-prometheus.id,":",",")), var.aws_region)) }"

  instance_type        = "t2.nano"
  key_name             = "${var.key_name}"
  iam_instance_profile = "${element(aws_iam_instance_profile.prometheus.*.name, count.index)}"

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
NUBIS_DOMAIN="${var.nubis_domain}"
NUBIS_PROMETHEUS_BUCKET="${element(aws_s3_bucket.prometheus.*.id, count.index)}"
EOF
}

resource "aws_autoscaling_group" "prometheus" {
  count = "${var.enabled * length(split(",", var.environments))}"

  lifecycle {
    create_before_destroy = true
  }

  #XXX: Fugly, assumes 3 subnets per environments, bad assumption, but valid ATM
  vpc_zone_identifier = [
    "${element(split(",",var.subnet_ids), (count.index * 3) + 0 )}",
    "${element(split(",",var.subnet_ids), (count.index * 3) + 1 )}",
    "${element(split(",",var.subnet_ids), (count.index * 3) + 2 )}",
  ]

  name                      = "${var.project}-${element(split(",",var.environments), count.index)} (LC ${element(aws_launch_configuration.prometheus.*.name, count.index)})"
  max_size                  = "2"
  min_size                  = "1"
  health_check_grace_period = 10
  health_check_type         = "EC2"
  desired_capacity          = "1"
  force_delete              = true
  launch_configuration      = "${element(aws_launch_configuration.prometheus.*.name, count.index)}"

  wait_for_capacity_timeout = "60m"

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
}
