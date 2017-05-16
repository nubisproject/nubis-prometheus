$prometheus_version = '1.6.2'
$alertmanager_version = '0.6.2'
$blackbox_version = '0.5.0'

$prometheus_url = "https://github.com/prometheus/prometheus/releases/download/v${prometheus_version}/prometheus-${prometheus_version}.linux-amd64.tar.gz"
$alertmanager_url = "https://github.com/prometheus/alertmanager/releases/download/v${alertmanager_version}/alertmanager-${alertmanager_version}.linux-amd64.tar.gz"
$blackbox_url = "https://github.com/prometheus/blackbox_exporter/releases/download/v${blackbox_version}/blackbox_exporter-${blackbox_version}.linux-amd64.tar.gz"

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
}->
file { '/etc/prometheus/rules.d':
  ensure => 'directory',
  owner  => 0,
  group  => 0,
  mode   => '0755',
}
file { '/etc/prometheus/nubis.rules.d':
  ensure => 'directory',
  owner  => 0,
  group  => 0,
  mode   => '0755',
}

file { '/etc/prometheus/nubis.rules.d/platform.prom':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0755',
    source  => 'puppet:///nubis/files/rules/nubis.prom',
    require => File['/etc/prometheus/nubis.rules.d'],
}

file { '/etc/prometheus/nubis.rules.d/squid.prom':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0755',
    source  => 'puppet:///nubis/files/rules/squid.prom',
    require => File['/etc/prometheus/nubis.rules.d'],
}

file { '/etc/prometheus/nubis.rules.d/apache.prom':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0755',
    source  => 'puppet:///nubis/files/rules/apache.prom',
    require => File['/etc/prometheus/nubis.rules.d'],
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

file { '/etc/init/prometheus.conf':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0644',
    source  => 'puppet:///nubis/files/prometheus.upstart',
    require => File['/etc/prometheus'],
}

file { '/etc/init/prometheus.override':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0644',
    content => 'manual',
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

notice ("Grabbing prometheus ${prometheus_version}")
staging::file { "prometheus.${prometheus_version}.tar.gz":
  source => $prometheus_url,
}->
staging::extract { "prometheus.${prometheus_version}.tar.gz":
  strip   => 1,
  target  => '/opt/prometheus',
  creates => '/opt/prometheus/prometheus',
  require => File['/opt/prometheus'],
}

notice ("Grabbing alertmanager ${alertmanager_version}")
staging::file { "alertmanager.${alertmanager_version}.tar.gz":
  source => $alertmanager_url,
}->
staging::extract { "alertmanager.${alertmanager_version}.tar.gz":
  strip   => 1,
  target  => '/opt/prometheus',
  creates => '/opt/prometheus/alertmanager',
  require => File['/opt/prometheus'],
}

notice ("Grabbing blackbox ${blackbox_version}")
staging::file { "blackbox.${blackbox_version}.tar.gz":
  source => $blackbox_url,
}->
staging::extract { "blackbox.${blackbox_version}.tar.gz":
  strip   => 1,
  target  => '/opt/prometheus',
  creates => '/opt/prometheus/blackbox_exporter',
  require => File['/opt/prometheus'],
}

include 'upstart'

upstart::job { 'alertmanager':
    description    => 'Prometheus Alert Manager',
    service_ensure => 'stopped',
    # Never give up
    respawn        => true,
    respawn_limit  => 'unlimited',
    start_on       => '(local-filesystems and net-device-up IFACE!=lo)',
    env            => {
      'SLEEP_TIME' => 1,
      'GOMAXPROCS' => 2,
    },
    user           => 'root',
    group          => 'root',
    script         => '
  if [ -r /etc/profile.d/proxy.sh ]; then
    echo "Loading Proxy settings"
    . /etc/profile.d/proxy.sh
  fi

  exec /opt/prometheus/alertmanager -config.file /etc/prometheus/alertmanager.yml -web.external-url "http://mon.$(nubis-metadata NUBIS_ENVIRONMENT).$(nubis-region).$(nubis-metadata NUBIS_ACCOUNT).$(nubis-metadata NUBIS_DOMAIN)/alertmanager"
',
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

upstart::job { 'blackbox':
    description    => 'Prometheus Blackbox Exporter',
    service_ensure => 'stopped',
    # Never give up
    respawn        => true,
    respawn_limit  => 'unlimited',
    start_on       => '(local-filesystems and net-device-up IFACE!=lo)',
    env            => {
      'SLEEP_TIME' => 1,
      'GOMAXPROCS' => 2,
    },
    user           => 'root',
    group          => 'root',
    script         => '
  if [ -r /etc/profile.d/proxy.sh ]; then
    echo "Loading Proxy settings"
    . /etc/profile.d/proxy.sh
  fi

  exec /opt/prometheus/blackbox_exporter -config.file /etc/prometheus/blackbox.yml -log.level info -log.format "logger:syslog?appname=blackbox_exporter&local=7"
',
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

