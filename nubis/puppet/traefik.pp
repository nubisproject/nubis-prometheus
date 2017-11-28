$traefik_version = '1.4.4'
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
  ensure => '2.4.*'
}

systemd::unit_file { 'traefik.service':
  source => 'puppet:///nubis/files/traefik.systemd',
}->
service { 'traefik':
  enable => true,
}

file { '/etc/consul/svc-traefik.json':
  ensure => file,
  owner  => root,
  group  => root,
  mode   => '0644',
  source => 'puppet:///nubis/files/svc-traefik.json',
}
