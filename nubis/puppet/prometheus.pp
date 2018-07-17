$prometheus_version = '2.2.1'
$alertmanager_version = '0.14.0'
$blackbox_version = '0.12.0'

$prometheus_url = "https://github.com/prometheus/prometheus/releases/download/v${prometheus_version}/prometheus-${prometheus_version}.linux-amd64.tar.gz"
$alertmanager_url = "https://github.com/prometheus/alertmanager/releases/download/v${alertmanager_version}/alertmanager-${alertmanager_version}.linux-amd64.tar.gz"
$blackbox_url = "https://github.com/prometheus/blackbox_exporter/releases/download/v${blackbox_version}/blackbox_exporter-${blackbox_version}.linux-amd64.tar.gz"

include nfs::client

file { '/opt/prometheus':
  ensure => 'directory',
  owner  => 0,
  group  => 0,
  mode   => '0755',
}

file { '/etc/prometheus':
  ensure => 'directory',
  owner  => 0,
  group  => 0,
  mode   => '0755',
}

file { '/etc/prometheus/rules.d':
  ensure  => 'directory',
  owner   => 0,
  group   => 0,
  mode    => '0755',
  require => [
    File['/etc/prometheus'],
  ],
}

file { '/etc/prometheus/nubis.rules.d':
  ensure  => 'directory',
  recurse => true,
  purge   => false,
  owner   => 0,
  group   => 0,
  mode    => '0755',
  require => [
    File['/etc/prometheus'],
  ],
  source  => 'puppet:///nubis/files/rules',
}
->exec { 'check prometheus rules syntax':
  command => '/opt/prometheus/promtool check rules /etc/prometheus/nubis.rules.d/*',
  path    => ['/sbin','/bin','/usr/sbin','/usr/bin','/usr/local/sbin','/usr/local/bin'],
  require => [
    Staging::Extract["prometheus.${prometheus_version}.tar.gz"],
  ],
}

file { '/var/lib/prometheus':
  ensure => 'directory',
  owner  => 0,
  group  => 0,
  mode   => '0755',
}

# bootup prometheus actions
file { '/etc/nubis.d/prometheus':
    ensure => file,
    owner  => root,
    group  => root,
    mode   => '0755',
    source => 'puppet:///nubis/files/prometheus-onboot',
}

file { '/etc/consul/svc-prometheus.json':
    ensure => file,
    owner  => root,
    group  => root,
    mode   => '0644',
    source => 'puppet:///nubis/files/svc-prometheus.json',
}

file { '/etc/consul/svc-alertmanager.json':
    ensure => file,
    owner  => root,
    group  => root,
    mode   => '0644',
    source => 'puppet:///nubis/files/svc-alertmanager.json',
}

file { '/usr/local/bin/nubis_prometheus':
    ensure => file,
    owner  => root,
    group  => root,
    mode   => '0755',
    source => 'puppet:///nubis/files/nubis_prometheus',
}

notice ("Grabbing prometheus ${prometheus_version}")
staging::file { "prometheus.${prometheus_version}.tar.gz":
  source => $prometheus_url,
}
->staging::extract { "prometheus.${prometheus_version}.tar.gz":
  strip   => 1,
  target  => '/opt/prometheus',
  creates => '/opt/prometheus/prometheus',
  require => File['/opt/prometheus'],
}

notice ("Grabbing alertmanager ${alertmanager_version}")
staging::file { "alertmanager.${alertmanager_version}.tar.gz":
  source => $alertmanager_url,
}
->staging::extract { "alertmanager.${alertmanager_version}.tar.gz":
  strip   => 1,
  target  => '/opt/prometheus',
  creates => '/opt/prometheus/alertmanager',
  require => File['/opt/prometheus'],
}

notice ("Grabbing blackbox ${blackbox_version}")
staging::file { "blackbox.${blackbox_version}.tar.gz":
  source => $blackbox_url,
}
->staging::extract { "blackbox.${blackbox_version}.tar.gz":
  strip   => 1,
  target  => '/opt/prometheus',
  creates => '/opt/prometheus/blackbox_exporter',
  require => File['/opt/prometheus'],
}

systemd::unit_file { 'prometheus.service':
  source => 'puppet:///nubis/files/prometheus.systemd',
}
->service { 'prometheus':
  enable => true,
}

systemd::unit_file { 'alertmanager.service':
  source => 'puppet:///nubis/files/alertmanager.systemd',
}
->service { 'alertmanager':
  enable => true,
}

systemd::unit_file { 'blackbox.service':
  source => 'puppet:///nubis/files/blackbox.systemd',
}
->service { 'blackbox':
  enable => true,
}
