# == Class auditd::params
#
# This class is meant to be called from auditd.
# It sets variables according to platform.
#
class auditd::params {
  if ($facts['operatingsystem'] in ['RedHat','CentOS']) or
     ($facts['osfamily'] in ['Suse']) {

    $package_name = 'audit'
    $service_name = 'auditd'
  }
  else {
    fail("${::operatingsystem} not supported")
  }
}
