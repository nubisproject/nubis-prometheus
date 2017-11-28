# Marker to recover from backups on boot only once per instance
# protecting ourselves from soft reboots
file { '/var/lib/prometheus/PRISTINE':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0644',
    content => 'Marker for initial boot of this image',
    require => [
      File['/var/lib/prometheus'],
    ]
}

cron::hourly { 'prometheus-backup':
    minute      => fqdn_rand(60),
    user        => 'root',
    # add 10 minutes of jitter
    command     => 'sleep $(( RANDOM \% 60*10 )) && nubis-cron prometheus-backup /usr/local/bin/prometheus-backup',
    environment => [
      'SHELL=/bin/bash',
    ],
}

file { '/usr/local/bin/prometheus-backup':
    ensure => file,
    owner  => root,
    group  => root,
    mode   => '0755',
    source => 'puppet:///nubis/files/prometheus-backup',
}

file { '/usr/local/bin/prometheus-restore':
    ensure => file,
    owner  => root,
    group  => root,
    mode   => '0755',
    source => 'puppet:///nubis/files/prometheus-restore',
}
