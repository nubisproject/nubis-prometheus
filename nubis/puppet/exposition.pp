$exposition_version = '0.2.0'
$exposition_url = "https://github.com/nubisproject/nubis-prometheus-exposition/releases/download/v${exposition_version}/nubis-prometheus-exposition_linux"
$exposition_file_name = 'nubis-prometheus-exposition'

notice ("Grabbing ${exposition_file_name} ${exposition_version}")

staging::file { "/usr/local/bin/${exposition_file_name}":
  source => $exposition_url,
  target => "/usr/local/bin/${exposition_file_name}",
}
->exec { "chmod /usr/local/bin/${exposition_file_name}":
  command => "chmod 755 /usr/local/bin/${exposition_file_name}",
  path    => ['/sbin','/bin','/usr/sbin','/usr/bin','/usr/local/sbin','/usr/local/bin'],
}

# Add a cron entry
cron::job { "${exposition_file_name}-cron":
    minute  => '*/10',
    command => "nubis-cron ${exposition_file_name} /usr/local/bin/${exposition_file_name} --region $(nubis-region)";
}
