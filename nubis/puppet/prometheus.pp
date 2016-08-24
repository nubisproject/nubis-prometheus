$prometheus_version = "1.0.1"
$alertmanager_version = "0.4.0"

$prometheus_url = "https://github.com/prometheus/prometheus/releases/download/v${prometheus_version}/prometheus-${prometheus_version}.linux-amd64.tar.gz"
$alertmanager_url = "https://github.com/prometheus/alertmanager/releases/download/v${alertmanager_version}/alertmanager-${alertmanager_version}.linux-amd64.tar.gz"

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
}->
file { "/etc/prometheus/rules.d":
  ensure => 'directory',
  owner  => 0,
  group  => 0,
  mode   => 755,
}

file { "/etc/prometheus/rules.d/nubis.prom":
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0755',
    source  => 'puppet:///nubis/files/rules/nubis.prom',
    require => File['/etc/prometheus/rules.d'],
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

file { '/etc/consul/svc-prometheus.json':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0644',
    source  => 'puppet:///nubis/files/svc-prometheus.json',
}

file { '/etc/consul/svc-alertmanager.json':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0644',
    source  => 'puppet:///nubis/files/svc-alertmanager.json',
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

notice ("Grabbing alertmanager ${alertmanager_version}")
staging::file { "alertmanager.${alertmanager_version}.tar.gz":
  source => $alertmanager_url,
}->
staging::extract { "alertmanager.${alertmanager_version}.tar.gz":
  strip   => 1,
  target  => "/opt/prometheus",
  creates => "/opt/prometheus/alertmanager",
  require => File["/opt/prometheus"],
}

exec { "apt-get-update-grafana":
  command => "/usr/bin/apt-get update",  
}->
class { 'grafana':
  install_method  => 'repo',
  cfg => {
    app_mode => 'production',
    users    => {
      allow_sign_up => false,
    },
  },
}
#->
#grafana_datasource { 'prometheus':
#  type              => 'prometheus',
#  url               => 'http://localhost:80',
  #access_mode       => 'proxy',
  #is_default        => true,
#}
