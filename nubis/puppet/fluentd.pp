class { 'fluentd':
  service_ensure => stopped
}

fluentd::configfile { 'prometheus': }

fluentd::source { 'prometheus':
  configfile  => 'prometheus',
  type        => 'tail',
  format      => 'json',
  time_format => '%FT%H:%M:%SZ',
  tag         => 'forward.prometheus.stdout',
  config      => {
    'path'     => '/var/log/prometheus.log',
    'pos_file' => '/var/log/prometheus.log.pos',
  },
}
