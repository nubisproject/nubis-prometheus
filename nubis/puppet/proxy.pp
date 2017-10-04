class { 'tinyproxy':
  minspareservers => 0,
  maxspareservers => 2,
  startservers    => 1,
  listen          => '127.0.0.1',
  port            => 3128,
}

tinyproxy::upstream { 'squid':
    ensure => present,
    proxy  => 'proxy.service.consul:3128',
}

tinyproxy::noupstream { 'aws-metadata':
    ensure => present,
    match  => '169.254.169.254'
}

tinyproxy::noupstream { 'consul':
    ensure => present,
    match  => '.consul'
}
