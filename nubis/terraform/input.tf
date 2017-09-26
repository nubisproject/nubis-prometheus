variable aws_region {}

variable key_name {}

variable nubis_version {}

variable nubis_domain {}

variable zone_id {}

variable service_name {}

variable arenas {
  type = "list"
}

variable enabled {}

variable technical_contact {}

variable vpc_ids {}

variable subnet_ids {}

variable public_subnet_ids {}

variable ssh_security_groups {}

variable monitoring_security_groups {}

variable internet_access_security_groups {}

variable shared_services_security_groups {}

variable sso_security_groups {
  default = ""
}

variable project {
  default = "prometheus"
}

variable slack_url {}

variable slack_channel {}

variable notification_email {}

variable pagerduty_service_key {
  default = ""
}

variable sink_slack_url {
  default = ""
}

variable sink_slack_channel {
  default = ""
}

variable sink_notification_email {
  default = ""
}

variable sink_pagerduty_service_key {
  default = ""
}

variable nubis_sudo_groups {
  default = "nubis_sudo_groups"
}

variable nubis_user_groups {
  default = ""
}

variable "credstash_key" {
  description = "KMS Key ID used for Credstash (aaaabbbb-cccc-dddd-1111-222233334444)"
}

variable "credstash_dynamodb_table" {}

variable "password" {
  description = "Password for the Web UI"
  default     = ""
}

variable "live_app" {
  default = ""
}
