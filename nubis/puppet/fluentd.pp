class { 'fluentd':
  service_ensure => stopped
}

fluentd::configfile { 'prometheus': }

#XXX: Needs proper format
#level=info ts=2017-11-16T14:48:31.109335507Z caller=main.go:220 msg="Loaded config file"

fluentd::source { 'prometheus':
  configfile  => 'prometheus',
  type        => 'tail',
  format      => 'none',
  time_format => '%FT%H:%M:%SZ',
  tag         => 'forward.prometheus.stdout',
  config      => {
    'path'     => '/var/log/prometheus.log',
    'pos_file' => '/var/log/prometheus.log.pos',
  },
}
