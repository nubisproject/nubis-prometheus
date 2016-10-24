output "iam_roles" {
  value = "${join(",",aws_iam_role.prometheus.*.id)}"
}
