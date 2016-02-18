$prometheus_version = "0.17.0rc2"
$node_exporter_version = "0.12.0rc3"
$consul_exporter_version = "0.2.0"

$prometheus_url = "https://github.com/prometheus/prometheus/releases/download/${prometheus_version}/prometheus-${prometheus_version}.linux-amd64.tar.gz"
$node_exporter_url = "https://github.com/prometheus/node_exporter/releases/download/${node_exporter_version}/node_exporter-${node_exporter_version}.linux-amd64.tar.gz"
$consul_exporter_url = "https://github.com/prometheus/consul_exporter/releases/download/${consul_exporter_version}/consul_exporter-${consul_exporter_version}.linux-amd64.tar.gz"

file { "/opt/prometheus":
  ensure => 'directory',
  owner  => 0,
  group  => 0,
  mode   => 755,
}

file { "/etc/prometheus":
  ensure => 'directory',
  owner  => 0,
  group  => 0,
  mode   => 755,
}

file { "/var/lib/prometheus":
  ensure => 'directory',
  owner  => 0,
  group  => 0,
  mode   => 755,
}

# bootup prometheus actions
file { '/etc/nubis.d/prometheus':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0755',
    source  => 'puppet:///nubis/files/prometheus-restart',
}

file { '/etc/prometheus/config.yml':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0644',
    source  => 'puppet:///nubis/files/prometheus.yml',
    require => File['/etc/prometheus'],
}

file { '/etc/init/prometheus.conf':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0644',
    source  => 'puppet:///nubis/files/prometheus.upstart',
    require => File['/etc/prometheus'],
}

file { '/etc/init/node_exporter.conf':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0644',
    source  => 'puppet:///nubis/files/node_exporter.upstart',
    require => File['/etc/prometheus'],
}

file { '/etc/init/consul_exporter.conf':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0644',
    source  => 'puppet:///nubis/files/consul_exporter.upstart',
    require => File['/etc/prometheus'],
}

notice ("Grabbing prometheus ${prometheus_version}")
staging::file { "prometheus.${prometheus_version}.tar.gz":
  source => $prometheus_url,
}->
staging::extract { "prometheus.${prometheus_version}.tar.gz":
  strip   => 1,
  target  => "/opt/prometheus",
  creates => "/opt/prometheus/prometheus",
  require => File["/opt/prometheus"],
}

notice ("Grabbing node_exporter ${node_exporter_version}")
staging::file { "node_exporter.${node_exporter_version}.tar.gz":
  source => $node_exporter_url,
}->
staging::extract { "node_exporter.${node_exporter_version}.tar.gz":
  target  => "/opt/prometheus",
  creates => "/opt/prometheus/node_exporter",
  require => File["/opt/prometheus"],
}

notice ("Grabbing consul_exporter ${consul_exporter_version}")
staging::file { "consul_exporter.${consul_exporter_version}.tar.gz":
  source => $consul_exporter_url,
}->
staging::extract { "consul_exporter.${consul_exporter_version}.tar.gz":
  target  => "/opt/prometheus",
  creates => "/opt/prometheus/consul_exporter",
  require => File["/opt/prometheus"],
}

# https://github.com/prometheus/pushgateway/releases/download/0.2.0/pushgateway-0.2.0.linux-amd64.tar.gz
# https://github.com/prometheus/cloudwatch_exporter/archive/cloudwatch_exporter-0.1.tar.gz
