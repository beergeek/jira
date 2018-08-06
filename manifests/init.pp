# A description of what this class does
#
# @summary A short summary of the purpose of this class
#
# @example
#   include jira
class jira (
  Stdlib::Absolutepath   $java_home,
  Boolean                $http                  = true,
  Boolean                $manage_db_settings    = false,
  Boolean                $manage_user           = true,
  Boolean                $manage_grp            = true,
  String                 $jira_user             = 'jira',
  String                 $jira_grp              = 'jira',
  String                 $version               = '7.11.1',
  Stdlib::Absolutepath   $jira_install_dir      = '/opt/atlassian/jira',
  Stdlib::Absolutepath   $jira_data_dir         = '/var/atlassian/application-data/jira',
  Jira::Db_type          $db_type               = 'postgresql',
  Jira::Memory           $jvm_xms               = '512m',
  Jira::Memory           $jvm_xmx               = '1024m',
  Jira::Pathurl          $source_location       = 'https://product-downloads.atlassian.com/software/jira/downloads',
  Jira::Pathurl          $mysql_driver_source   = 'https://dev.mysql.com/get/Downloads/Connector-J',
  Optional[Stdlib::Fqdn] $db_host               = 'localhost',
  # Version 8 causes issues with Bamboo
  Optional[String]       $mysql_driver_pkg      = 'mysql-connector-java-5.1.46.tar.gz',
  # $mysql_driver_jar_name must come after $mysql_driver_pkg
  Optional[String]       $mysql_driver_jar_name = "${basename($mysql_driver_pkg, '.tar.gz')}.jar",
  Optional[String]       $db_name               = undef,
  Optional[String]       $db_password           = undef,
  Optional[String]       $db_port               = undef,
  Optional[String]       $db_user               = undef,
  Optional[String]       $java_args             = undef,
) {

  if $facts['os']['family'] != 'RedHat' {
    fail("This module is only for the RedHat family, not ${facts['os']['family']}")
  }

  if (versioncmp($version, '7.0.0') < 0) {
    fail('This module is for Jira-software version 7.0.0 and higher')
  }

  contain jira::install
  contain jira::config
  contain jira::service

  Class['jira::install'] -> Class['jira::config'] ~> Class['jira::service']
}
