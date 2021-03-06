#
# The `puppetmaster` role sets up a master system, synchronizes files from
# Amazon, and generally enables SE Team specific patterns dependent on master
# capabilities.
#
class role::puppetmaster (
  $r10k_environments_dir    = '/etc/puppetlabs/puppet/environments',
  $r10k_environments_remote = 'https://github.com/puppetlabs-seteam/puppet-environments',
  $srv_root                 = '/var/seteam-files',
) {
  # Custom PE Console configuration
  include console_env
  include git
  include apache

  # Puppet master firewall rules
  include profile::firewall
  Firewall {
    require => Class['profile::firewall::pre'],
    before  => Class['profile::firewall::post'],
    chain   => 'INPUT',
    proto   => 'tcp',
    action  => 'accept',
  }
  firewall { '110 puppetmaster allow all': dport  => '8140';  }
  firewall { '110 dashboard allow all':    dport  => '443';   }
  firewall { '110 mcollective allow all':  dport  => '61613'; }
  firewall { '110 apache allow all':       dport  => '80';    }

  apache::vhost { 'seteam-files':
    vhost_name => '*',
    port       => '80',
    docroot    => $srv_root,
    priority   => '10',
  }

  package { 'r10k':
    ensure   => present,
    provider => pe_gem,
  }

  # Template uses:
  #   - $r10k_environments_dir
  #   - $r10k_environments_remote
  file { '/etc/r10k.yaml':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('role/puppetmaster/r10k.yaml.erb'),
  }

  ini_setting { 'puppet_modulepath':
    ensure  => present,
    path    => '/etc/puppetlabs/puppet/puppet.conf',
    section => 'main',
    setting => 'modulepath',
    value   => "${r10k_environments_dir}/\$environment/modules:/opt/puppet/share/puppet/modules",
  }
  ini_setting { 'puppet_manifestdir':
    ensure  => present,
    path    => '/etc/puppetlabs/puppet/puppet.conf',
    section => 'main',
    setting => 'manifestdir',
    value   => "${r10k_environments_dir}/\$environment/manifests"
  }
  ini_setting { 'puppet_hieraconfig':
    ensure  => present,
    path    => '/etc/puppetlabs/puppet/puppet.conf',
    section => 'main',
    setting => 'hiera_config',
    value   => "${r10k_environments_dir}/\$environment/hiera.yaml"
  }

  exec { 'instantiate_environment':
    path    => '/opt/puppet/bin:/usr/bin:/bin',
    command => '/opt/puppet/bin/r10k deploy environment -p',
    creates => $r10k_environments_dir,
    require => [
      Package['r10k'],
      Class['git'],
      File['/etc/r10k.yaml'],
    ],
  }

}
