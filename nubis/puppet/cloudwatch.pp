$cloudwatch_exporter_version = '0.3'
$cloudwatch_exporter_port = 9116
$cloudwatch_exporter_billing_port = 9117
$cloudwatch_exporter_url = "https://github.com/gozer/cloudwatch_exporter/releases/download/GOZER-${cloudwatch_exporter_version}/cloudwatch_exporter-${cloudwatch_exporter_version}-GOZER-jar-with-dependencies.jar"

notice ("Grabbing cloudwatch_exporter ${cloudwatch_exporter_version}")

class { 'java':
  distribution => 'jre',
}

file { '/usr/share/cloudwatch_exporter':
  ensure => 'directory',
}->
staging::file { "cloudwatch.${cloudwatch_exporter_version}.jar":
  source => $cloudwatch_exporter_url,
  target => "/usr/share/cloudwatch_exporter/cloudwatch_exporter-${cloudwatch_exporter_version}.jar"
}->
file { '/usr/share/cloudwatch_exporter/cloudwatch_exporter.jar':
  ensure => 'link',
  target => "cloudwatch_exporter-${cloudwatch_exporter_version}.jar"
}

systemd::unit_file { 'cloudwatch_exporter.service':
  source => 'puppet:///nubis/files/cloudwatch_exporter.systemd',
}

systemd::unit_file { 'cloudwatch_exporter_billing.service':
  source => 'puppet:///nubis/files/cloudwatch_exporter_billing.systemd',
}
