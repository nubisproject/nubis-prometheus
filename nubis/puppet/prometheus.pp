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

file { '/etc/prometheus/alertmanager.yml':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0644',
    source  => 'puppet:///nubis/files/alertmanager.yml',
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

# XXX: This is just too ugly
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
}->
exec {"wait-for grafana startup":
  command => "/bin/sleep 15",
}->
grafana_datasource { 'prometheus':
  grafana_url       => 'http://localhost:3000',
  grafana_user      => 'admin',
  grafana_password  => 'admin',
  type              => 'prometheus',
  url               => 'http://localhost:80',
  access_mode       => 'proxy',
  is_default        => true,
}

include 'upstart'

upstart::job { 'alertmanager':
    description    => 'Prometheus Alert Manager',
#    service_ensure => 'stopped',
    # Never give up
    respawn        => true,
    respawn_limit  => 'unlimited',
    start_on       => '(local-filesystems and net-device-up IFACE!=lo)',
    env            => {
      "SLEEP_TIME" => 1,
      "GOMAXPROCS" => 2,
    },
    user           => 'root',
    group          => 'root',
    exec           => '/opt/prometheus/alertmanager -config.file /etc/prometheus/alertmanager.yml',
    post_stop      => '
goal=$(initctl status $UPSTART_JOB | awk \'{print $2}\' | cut -d \'/\' -f 1)
if [ $goal != "stop" ]; then
    echo "Backoff for $SLEEP_TIME seconds"
    sleep $SLEEP_TIME
    NEW_SLEEP_TIME=`expr 2 \* $SLEEP_TIME`
    if [ $NEW_SLEEP_TIME -ge 60 ]; then
        NEW_SLEEP_TIME=60
    fi
    initctl set-env SLEEP_TIME=$NEW_SLEEP_TIME
fi
',
}
