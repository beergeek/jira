class jira::config {

  assert_private()

  File {
    owner   => $jira::jira_user,
    group   => $jira::jira_grp,
    mode    => '0644',
  }

  File_line {
    path    => "${jira::jira_data_dir}/jira.cfg.xml",
  }

  if $facts['os']['name'] == 'Amazon' and $facts['os']['release']['major'] == '4' {
    $init_file = 'jira.systemd.epp'
    $script_path = '/etc/systemd/system/jira.service'
  } elsif $facts['os']['release']['major'] == '6' {
      $init_file = 'jira.init.pp'
      $script_path = '/etc/init.d/jira'
  } elsif $facts['os']['release']['major'] == '7' {
    $init_file = 'jira.systemd.epp'
    $script_path = '/etc/systemd/system/jira.service'
  } else {
    fail("You OS version is either far too old or far to bleeding edge: ${facts['os']['name']} ${facts['os']['release']['major']}")
  }

  if $jira::db_type == 'mysql' {
    # If RHEL7 it uses MariaDB, which is not supported, but we can skip the check
    # -Djira.upgrade.fail.if.mysql.unsupported=false
    # Set db connection data
    $_java_args = "${jira::java_args} -Djira.upgrade.fail.if.mysql.unsupported=false"
    $_db_driver = 'com.mysql.jdbc.Driver'
    $_db_hibernate = 'org.hibernate.dialect.MySQL5InnoDBDialect'
    $_db_url = "jdbc:mysql://${jira::db_host}/${jira::db_name}?autoReconnect=true"
  } else {
    $_java_args = $jira::java_args
    $_db_driver = 'com.mysql.jdbc.Driver'
    $_db_hibernate = 'org.hibernate.dialect.PostgreSQL82Dialect'
    $_db_url = "jdbc:postgresql://${jira::db_host}/${jira::db_name}?autoReconnect=true"
  }

  # Configure the home/data/app directory for jira
  file_line { 'jira_home_dir':
    ensure => present,
    path   => "${jira::jira_install_dir}/atlassian-jira-${jira::version}/atlassian-jira/WEB-INF/classes/jira-init.properties",
    line   => "jira.home=${jira::jira_data_dir}",
  }

  #file { 'base_config':
  #  ensure  => file,
  #  path    => "${jira::jira_data_dir}/jira.cfg.xml",
  #  source  => 'puppet:///modules/jira/jira.cfg.xml',
  #  replace => false,
  #}

  # Startup/Shutdown script
  #file { 'init_script':
  #  ensure  => file,
  #  path    => $script_path,
  #  mode    => '0744',
  #  content => epp("jira/${init_file}", {
  #    jira_user        => $jira::jira_user,
  #    jira_install_dir => "${jira::jira_install_dir}/current",
  #  }),
  #}

  if $jira::manage_db_settings {
    # Check if we have the required info
    if $jira::db_name == undef or $jira::db_host == undef or $jira::db_user == undef or $jira::db_password == undef {
      fail('When `manage_db_settings` is true you must provide `db_name`, `db_host`, `db_user`, and `db_password`')
    }
    # Determine if port is supplied, if not assume default port for database type
    if $jira::db_port == undef or empty($jira::db_port) {
      if $jira::db_type == 'mysql' {
        $_db_port = '3306'
      } else {
        $_db_port = '5432'
      }
    } else {
      $_db_port = $jira::db_port
    }

    # If MySQL we need the driver and set
    if $jira::db_type == 'mysql' {
      archive { "/tmp/${jira::mysql_driver_pkg}":
        ensure          => present,
        extract         => true,
        extract_command => "tar -zxf %s --strip-components 1 --exclude='lib*' */${jira::mysql_driver_jar_name}",
        extract_path    => "${jira::jira_install_dir}/atlassian-jira-${jira::version}/lib",
        source          => "${jira::mysql_driver_source}/${jira::mysql_driver_pkg}",
        creates         => "${jira::jira_install_dir}/atlassian-jira-${jira::version}/lib/${jira::mysql_driver_jar_name}",
        cleanup         => true,
        user            => $jira::jira_user,
        group           => $jira::jira_grp,
      }
    }

    # Database connector config
    file_line { 'db_driver':
      ensure  => present,
      line    => "    <property name=\"hibernate.connection.driver_class\">${_db_driver}</property>",
      match   => '^( |\t)*<property name\="hibernate.connection.driver_class">',
      after   => '^( |\t)*<property name\="jira.jms.broker.uri">',
      require => File['base_config'],
    }

    file_line { 'db_password':
      ensure  => present,
      line    => "    <property name=\"hibernate.connection.password\">${jira::db_password}</property>",
      match   => '^( |\t)*<property name\="hibernate.connection.password">',
      after   => '^( |\t)*<property name\="hibernate.connection.driver_class">',
      require => File_line['db_driver'],
    }

    file_line { 'db_url':
      ensure  => present,
      line    => "    <property name=\"hibernate.connection.url\">${_db_url}</property>",
      match   => '^( |\t)*<property name\="hibernate.connection.url">',
      after   => '^( |\t)*<property name\="hibernate.connection.password">',
      require => File_line['db_password'],
    }

    file_line { 'db_user':
      ensure  => present,
      line    => "    <property name=\"hibernate.connection.username\">${jira::db_user}</property>",
      match   => '^( |\t)*<property name\="hibernate.connection.username">',
      after   => '^( |\t)*<property name\="hibernate.connection.url">',
      require => File_line['db_url'],
    }

    file_line { 'db_dialect':
      ensure  => present,
      line    => "    <property name=\"hibernate.dialect\">${_db_hibernate}</property>",
      match   => '^( |\t)*<property name\="hibernate.dialect">',
      after   => '^( |\t)*<property name\="hibernate.connection.username">',
      require => File_line['db_user'],
    }
  }

  #file { 'java_args':
  #  ensure  => file,
  #  path    => "${jira::jira_install_dir}/atlassian-jira-${jira::version}/bin/setenv.sh",
  #  content => epp('jira/setenv.sh.epp', {
  #    java_args => $_java_args,
  #    java_xms  => $jira::jvm_xms,
  #    java_xmx  => $jira::jvm_xmx,
  #  })
  #}
}
