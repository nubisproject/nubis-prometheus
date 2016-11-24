variable aws_profile {
}

variable aws_region {
}

variable key_name {
}

variable nubis_version {
}

variable nubis_domain {
}

variable zone_id {
}

variable service_name {
}

variable environments {
}

variable enabled {
}

variable lambda_uuid_arn {

}

variable technical_contact {
}

variable vpc_ids {
}

variable subnet_ids {
}

variable public_subnet_ids {
}

variable ssh_security_groups {
}

variable monitoring_security_groups {
}

variable internet_access_security_groups {
}

variable shared_services_security_groups {
}

variable project {
  default = "prometheus"
}

variable slack_url {
}
variable slack_channel {
}
variable notification_email {
}

variable pagerduty_service_key {
  default = ""
}

variable nubis_sudo_groups {
  default = "nubis_sudo_groups"
}

variable nubis_user_groups {
  default = ""
}
