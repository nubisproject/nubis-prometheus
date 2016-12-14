class { 'python':
    pip => 'present',
}

python::pip { 'awscli':
    ensure => '1.11.15',
}

file { '/usr/local/bin/nubis-prometheus-backup':
    ensure => file,
    owner  => root,
    group  => root,
    mode   => '0755',
    source => 'puppet:///nubis/files/backup',
}

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
    user    => 'root',
    command => 'nubis-cron prometheus-backup /usr/local/bin/nubis-prometheus-backup save'
}
