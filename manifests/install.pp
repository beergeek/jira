# A description of what this class does
#
# @summary A short summary of the purpose of this class
#
# @example
#   include jira::install
#
#
#
class jira::install () {

  assert_private()

  if $jira::manage_user {
    user { $jira::jira_user:
      ensure     => present,
      gid        => $jira::jira_grp,
      managehome => true,
      shell      => '/sbin/nologin',
    }
  }

  if $jira::manage_grp {
    group { $jira::jira_grp:
      ensure => present,
    }
  }

  file { [$jira::jira_install_dir, $jira::jira_data_dir]:
    ensure => directory,
    owner  => $jira::jira_user,
    group  => $jira::jira_grp,
    mode   => '0755',
  }

  archive { "/tmp/atlassian-jira-${jira::version}.tar.gz":
    ensure       => present,
    extract      => true,
    extract_path => $jira::jira_install_dir,
    source       => "${jira::source_location}/atlassian-jira-software-${jira::version}.tar.gz",
    creates      => "${jira::jira_install_dir}/atlassian-jira-software-${jira::version}-standalone",
    cleanup      => true,
    user         => $jira::jira_user,
    group        => $jira::jira_grp,
    require      => File[$jira::jira_install_dir],
  }

  file { "${jira::jira_install_dir}/current":
    ensure => link,
    target => "${jira::jira_install_dir}/atlassian-jira-software-${jira::version}-standalone",
  }
}

