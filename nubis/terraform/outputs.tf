output "iam_roles" {
  value = "${join(",",aws_iam_role.prometheus.*.id)}"
}

output "federation_password" {
  value = "${data.template_file.federation.rendered}"
}

output "admin_password" {
  value = "${data.template_file.password.rendered}"
}
