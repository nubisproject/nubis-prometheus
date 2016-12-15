# nubis-prometheus

[![Version](https://img.shields.io/github/release/nubisproject/nubis-prometheus.svg?maxAge=2592000)](https://github.com/nubisproject/nubis-prometheus/releases)
[![Build Status](https://img.shields.io/travis/nubisproject/nubis-prometheus/master.svg?maxAge=2592000)](https://travis-ci.org/nubisproject/nubis-prometheus)
[![Issues](https://img.shields.io/github/issues/nubisproject/nubis-prometheus.svg?maxAge=2592000)](https://github.com/nubisproject/nubis-prometheus/issues)

## Prometheus Deployment
The Prometheus project is designed to be deployed into a standard Nubis Account. It takes advantage of the standard deployment found [here](https://github.com/nubisproject/nubis-docs/blob/master/DEPLOYMENT_OVERVIEW.md). For further specifics about Prometheus consult the documentation [here](https://prometheus.io/docs/introduction/overview/.


### Deployment Diagram
![Deployment Diagram](media/Nubis_Prometheus_Diagram.png "Deployment Diagram")

**NOTE**: The line colors are representative and are for readability only. They are not intended to indicate any underlying protocol or specific communication details.

### Deployment Notes
The Nubis Prometheus deployment consists of:
 - A single EC2 instance acting as a Prometheus server
 - An Auto Scaling group to provide resiliency
 - A S3 log bucket where backups are stored

### Deployment Resources
Details for the deployment including; naming conventions, relationships, permissions, etcetera, can be found in the [Terraform template](nubis/terraform/main.tf) used for deployment. Links to specific resources can be found in the following table.

|Resource Type|Resource Title|Code Location|
|-------------|--------------|-------------|
|atlas_artifact|nubis-prometheus|[nubis/terraform/main.tf#6](nubis/terraform/main.tf#6)|
|aws_s3_bucket|prometheus|[nubis/terraform/main.tf#35](nubis/terraform/main.tf#35)|
|aws_security_group|prometheus|[nubis/terraform/main.tf#58](nubis/terraform/main.tf#58)|
|aws_iam_instance_profile|prometheus|[nubis/terraform/main.tf#128](nubis/terraform/main.tf#128)|
|aws_iam_role|prometheus|[nubis/terraform/main.tf#142](nubis/terraform/main.tf#142)|
|aws_iam_role_policy|prometheus|[nubis/terraform/main.tf#169](nubis/terraform/main.tf#169)|
|aws_launch_configuration|prometheus|[nubis/terraform/main.tf#214](nubis/terraform/main.tf#214)|
|aws_autoscaling_group|prometheus|[nubis/terraform/main.tf#254](nubis/terraform/main.tf#254)|
