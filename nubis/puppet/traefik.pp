$traefik_version = '1.4.0-rc4'
$traefik_url = "https://github.com/containous/traefik/releases/download/v${traefik_version}/traefik_linux-amd64"

notice ("Grabbing traefik ${traefik_version}")

staging::file { '/usr/local/bin/traefik':
  source => $traefik_url,
  target => '/usr/local/bin/traefik',
}->
exec { 'chmod /usr/local/bin/traefik':
  command => 'chmod 755 /usr/local/bin/traefik',
  path    => ['/sbin','/bin','/usr/sbin','/usr/bin','/usr/local/sbin','/usr/local/bin'],
}

file { '/etc/traefik':
  ensure => directory,
  owner  => root,
  group  => root,
  mode   => '0640',
}

package {'apache2-utils':
  ensure => '2.4.7-*'
}

upstart::job { 'traefik':
    description    => 'Traefik Load Balancer',
    service_ensure => 'stopped',
    require        => [
      Staging::File['/usr/local/bin/traefik'],
    ],
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
    script         => 'exec /usr/local/bin/traefik --web.readonly=true --loglevel=INFO',
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

file { '/etc/consul/svc-traefik.json':
  ensure => file,
  owner  => root,
  group  => root,
  mode   => '0644',
  source => 'puppet:///nubis/files/svc-traefik.json',
}
