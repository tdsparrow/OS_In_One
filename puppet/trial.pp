# assumes that eth0 is the public interface
$public_interface        = 'em1'
# assumes that eth1 is the interface that will be used for the vm network
# this configuration assumes this interface is active but does not have an
# ip address allocated to it.
$private_interface       = 'em2'
# credentials
$admin_email             = 'root@localhost'
$admin_password          = 'admin123'
$keystone_db_password    = 'keystone_db_pass'
$keystone_admin_token    = 'keystone_admin_token'
$nova_db_password        = 'nova_pass'
$nova_user_password      = 'nova_pass'
$glance_db_password      = 'glance_pass'
$glance_user_password    = 'glance_pass'
$rabbit_password         = 'openstack_rabbit_password'
$rabbit_user             = 'openstack_rabbit_user'
$fixed_network_range     = '10.0.2.0/24'
$fixed_network_range_v6  = 'fec0::/64'
$floating_network_range  = '192.168.101.64/28'
# switch this to true to have all service log at verbose
$verbose                 = true
# by default it does not enable atomatically adding floating IPs
$auto_assign_floating_ip = false

#secret_key
$secret_key		 = 'ADMIN'

#mysql_root_passwd
$mysql_root_passwd        = 'embms1234'

include 'apache'

class { 'openstack::all':
  public_address          => $ipaddress_em1,
  public_interface        => $public_interface,
  private_interface       => $private_interface,
  admin_email             => $admin_email,
  admin_password          => $admin_password,
  keystone_db_password    => $keystone_db_password,
  keystone_admin_token    => $keystone_admin_token,
  nova_db_password        => $nova_db_password,
  nova_user_password      => $nova_user_password,
  glance_db_password      => $glance_db_password,
  glance_user_password    => $glance_user_password,
  rabbit_password         => $rabbit_password,
  rabbit_user             => $rabbit_user,
  libvirt_type            => 'kvm',
  floating_range          => $floating_network_range,
  fixed_range             => $fixed_network_range,
  fixed_range_v6             => $fixed_network_range_v6,
  verbose                 => $verbose,
  auto_assign_floating_ip => $auto_assign_floating_ip,
  secret_key 		  => $secret_key,
  mysql_root_password 	  => $mysql_root_passwd,
  quantum 		  => false,
  cinder		  => false,
  network_config	  => { use_ipv6 => true },

}

class { 'openstack::auth_file':
  admin_password       => $admin_password,
  keystone_admin_token => $keystone_admin_token,
  controller_node      => '127.0.0.1',
}

