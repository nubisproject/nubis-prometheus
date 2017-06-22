package {'crudini':
  ensure => present,
}

# XXX: This is just too ugly
#exec { 'apt-get-update-grafana':
#  command => '/usr/bin/apt-get update',
#}->
class { 'grafana':
  install_method => 'repo',
  version        => '3.1.1-1470047149',
  cfg            => {
    app_mode          => 'production',
    'server'          => {
      protocol => 'http',
      root_url => '/grafana',
    },
    'auth.anonymous'  => {
      enabled => true,
    },
    # Needs to be disabled for traefik, enabled for grafana_datasource, hurgh
    'auth.basic'      => {
      enabled => true,
    },
    'auth.proxy'      => {
      enabled => true,
      header_name => 'OIDC_CLAIM_email',
      header_property => 'email',
      auto_sign_up => true,
    }
    users             => {
      allow_sign_up => true,
      auto_assign_org => true,
      auto_assign_org_role => 'Editor',
    },
    'dashboards.json' => {
      enabled => true,
    },
  },
}->
exec {'wait-for grafana startup':
  command => '/bin/sleep 15',
}->
grafana_datasource { 'prometheus':
  grafana_url      => 'http://localhost:3000',
  grafana_user     => 'admin',
  grafana_password => 'admin',
  type             => 'prometheus',
  url              => 'http://localhost:81/prometheus',
  access_mode      => 'proxy',
  is_default       => true,
}->
grafana_datasource { 'elasticsearch':
  grafana_url      => 'http://localhost:3000',
  grafana_user     => 'admin',
  grafana_password => 'admin',
  type             => 'elasticsearch',
  url              => 'http://es.service.consul:8080',
  database         => '[logstash-]YYYY.MM.DD',
  access_mode      => 'proxy',
}->
#grafana_datasource { 'cloudwatch': is not supported ;-(
exec {'create cloudwatch datasource':
  command => '/usr/bin/curl -u admin:admin -H \'Content-Type: application/json\' http://localhost:3000/api/datasources -X POST --data-binary  \'{"name": "cloudwatch", "type":"cloudwatch", "access": "proxy" }\''
}->
exec { 'disable basic auth':
  command => '/usr/bin/crudini --set /etc/grafana/grafana.ini auth.basic enabled false',
  require => [
    Package['crudini'],
  ]
}->
exec {'enable proxy support':
  command => '/bin/echo ". /etc/profile.d/proxy.sh" >> /etc/default/grafana-server'
}

file { '/var/lib/grafana/dashboards':
  ensure  => directory,
  owner   => grafana,
  group   => grafana,
  mode    => '0640',
  recurse => true,
  purge   => true,
  source  => 'puppet:///nubis/files/grafana/dashboards',
  require => [
    Class['grafana'],
  ]
}

file { '/etc/consul/svc-grafana.json':
    ensure => file,
    owner  => root,
    group  => root,
    mode   => '0644',
    source => 'puppet:///nubis/files/svc-grafana.json',
}
