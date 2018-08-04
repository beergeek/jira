# A description of what this class does
#
# @summary A short summary of the purpose of this class
#
# @example
#   include jira::service
class jira::service {

  service { 'jira1':
    ensure => running,
    enable => true,
  }
}
