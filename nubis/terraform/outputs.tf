output "iam_roles" {
  value = "${join(",",aws_iam_role.prometheus.*.id)}"
}

output "federation_password" {
  value = "${template_file.federation.rendered}"
}
