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

upstart::job { 'cloudwatch_exporter':
    description    => 'CloudWatch Exporter',
    service_ensure => 'stopped',
    require        => [
      Staging::File["cloudwatch.${cloudwatch_exporter_version}.jar"],
    ],
    # Never give up
    respawn        => true,
    respawn_limit  => 'unlimited',
    start_on       => '(local-filesystems and net-device-up IFACE!=lo)',
    user           => 'root',
    group          => 'root',
    exec           => "java -Dhttps.proxyHost=proxy.service.consul -Dhttps.proxyPort=3128 -jar /usr/share/cloudwatch_exporter/cloudwatch_exporter.jar ${cloudwatch_exporter_port} /etc/cloudwatch_exporter.yml",
}

upstart::job { 'cloudwatch_exporter_billing':
    description    => 'CloudWatch Exporter for Billing',
    service_ensure => 'stopped',
    require        => [
      Staging::File["cloudwatch.${cloudwatch_exporter_version}.jar"],
    ],
    # Never give up
    respawn        => true,
    respawn_limit  => 'unlimited',
    start_on       => '(local-filesystems and net-device-up IFACE!=lo)',
    user           => 'root',
    group          => 'root',
    exec           => "java -Dhttps.proxyHost=proxy.service.consul -Dhttps.proxyPort=3128 -jar /usr/share/cloudwatch_exporter/cloudwatch_exporter.jar ${cloudwatch_exporter_billing_port} /etc/cloudwatch_exporter_billing.yml",
}
