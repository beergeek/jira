require 'spec_helper'

describe 'jira' do
  let :facts do
    {
      os: { 'family' => 'RedHat', 'release' => { 'major' => '7' } },
      osfamily: 'RedHat',
      operatingsystem: 'RedHat',
    }
  end

  context 'With defaults' do
    it do
      is_expected.to contain_class('jira::install')
      is_expected.to contain_class('jira::config')
      is_expected.to contain_class('jira::service')
    end

    describe 'jira::install' do
      it do
        is_expected.to contain_user('jira').with(
          'ensure'      => 'present',
          'gid'         => 'jira',
          'managehome'  => true,
          'shell'       => '/sbin/nologin',
        )
      end

      it do
        is_expected.to contain_group('jira').with(
          'ensure'  => 'present',
        )
      end

      it do
        is_expected.to contain_file('/opt/atlassian/jira').with(
          'ensure'  => 'directory',
          'owner'   => 'jira',
          'group'   => 'jira',
          'mode'    => '0755',
        )
      end

      it do
        is_expected.to contain_file('/var/atlassian/application-data/jira').with(
          'ensure'  => 'directory',
          'owner'   => 'jira',
          'group'   => 'jira',
          'mode'    => '0755',
        )
      end

      it do
        is_expected.to contain_archive('/tmp/atlassian-jira-7.11.1.tar.gz').with(
          'ensure'        => 'present',
          'extract'       => true,
          'extract_path'  => '/opt/atlassian/jira',
          'source'        => 'https://product-downloads.atlassian.com/software/jira/downloads/atlassian-jira-software-7.11.1.tar.gz',
          'creates'       => '/opt/atlassian/jira/atlassian-jira-7.11.1-standalone',
          'cleanup'       => true,
          'user'          => 'jira',
          'group'         => 'jira',
        ).that_requires('File[/opt/atlassian/jira]')
      end

      it do
        is_expected.to contain_file('/opt/atlassian/jira/current').with(
          'ensure'  => 'link',
          'target'  => '/opt/atlassian/jira/atlassian-jira-7.11.1',
        )
      end
    end

    describe 'jira::config' do
      it do
        is_expected.to contain_file_line('jira_home_dir').with(
          'ensure'  => 'present',
          'path'    => '/opt/atlassian/jira/atlassian-jira-7.11.1/atlassian-jira/WEB-INF/classes/jira-init.properties',
          'line'    => 'jira.home=/var/atlassian/application-data/jira',
        )
      end

      it do
        is_expected.to contain_file('base_config').with(
          'ensure'  => 'file',
          'owner'   => 'jira',
          'group'   => 'jira',
          'mode'    => '0644',
          'source'  => 'puppet:///modules/jira/jira.cfg.xml',
          'replace' => false,
        )
      end

      it do
        is_expected.to contain_file('init_script').with(
          'ensure' => 'file',
          'path'   => '/etc/systemd/system/jira.service',
          'owner'  => 'jira',
          'group'  => 'jira',
          'mode'   => '0744',
        ).with_content(/User=jira\nExecStart=\/opt\/atlassian\/jira\/current\/bin\/start-jira.sh\nExecStop=\/opt\/atlassian\/jira\/current\/bin\/stop-jira.sh/)
      end
    end

    describe 'jira::service' do
      it do
        is_expected.to contain_service('jira').with(
          'ensure' => 'running',
          'enable' => true,
        )
      end
    end
  end

  context 'jira with MySQL database' do
    let :params do
      {
        manage_db_settings: true,
        db_type: 'mysql',
        db_host: 'mysql0.puppet.vm',
        db_name: 'jiradb',
        db_user: 'jira',
        db_password: 'password123',
      }
    end

    describe 'jira::config' do
      it do
        is_expected.to contain_archive('/tmp/mysql-connector-java-5.1.46.tar.gz').with(
          'ensure'          => 'present',
          'extract'         => true,
          'extract_command' => "tar -zxf %s --strip-components 1 --exclude='lib*' */mysql-connector-java-5.1.46.jar",
          'extract_path'    => '/opt/atlassian/jira/atlassian-jira-7.11.1/lib',
          'source'          => 'https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.46.tar.gz',
          'creates'         => '/opt/atlassian/jira/atlassian-jira-7.11.1/lib/mysql-connector-java-5.1.46.jar',
          'cleanup'         => true,
          'user'            => 'jira',
          'group'           => 'jira',
        )
      end

      it do
        is_expected.to contain_file('java_args').with(
          'ensure'  => 'file',
          'path'    => '/opt/atlassian/jira/atlassian-jira-7.11.1/bin/setenv.sh',
          'owner'  => 'jira',
          'group'  => 'jira',
          'mode'   => '0644',
        ).with_content(/: \$\{JVM_SUPPORT_RECOMMENDED_ARGS:=" -Djira\.upgrade\.fail\.if\.mysql\.unsupported=false"\}/)
      end

      it do
        is_expected.to contain_file_line('db_driver').with(
          'ensure'  => 'present',
          'path'    => '/var/atlassian/application-data/jira/jira.cfg.xml',
          'line'    => "    <property name=\"hibernate.connection.driver_class\">com.mysql.jdbc.Driver</property>",
          'match'   => '^( |\\t)*<property name\\="hibernate.connection.driver_class">',
          'after'   => '^( |\\t)*<property name\\="jira.jms.broker.uri">',
        ).that_requires("File[base_config]")
      end

      it do
        is_expected.to contain_file_line('db_password').with(
          'ensure'  => 'present',
          'path'    => '/var/atlassian/application-data/jira/jira.cfg.xml',
          'line'    => "    <property name=\"hibernate.connection.password\">password123</property>",
          'match'   => '^( |\\t)*<property name\\="hibernate.connection.password">',
          'after'   => '^( |\\t)*<property name\\="hibernate.connection.driver_class">',
        )
      end

      it do
        is_expected.to contain_file_line('db_url').with(
          'ensure'  => 'present',
          'path'    => '/var/atlassian/application-data/jira/jira.cfg.xml',
          'line'    => "    <property name=\"hibernate.connection.url\">jdbc:mysql://mysql0.puppet.vm/jiradb?autoReconnect=true</property>",
          'match'   => '^( |\\t)*<property name\\="hibernate.connection.url">',
          'after'   => '^( |\\t)*<property name\\="hibernate.connection.password">',
        )
      end

      it do
        is_expected.to contain_file_line('db_user').with(
          'ensure'  => 'present',
          'path'    => '/var/atlassian/application-data/jira/jira.cfg.xml',
          'line'    => "    <property name=\"hibernate.connection.username\">jira</property>",
          'match'   => '^( |\\t)*<property name\\="hibernate.connection.username">',
          'after'   => '^( |\\t)*<property name\\="hibernate.connection.url">',
        )
      end

      it do
        is_expected.to contain_file_line('db_dialect').with(
          'ensure'  => 'present',
          'path'    => '/var/atlassian/application-data/jira/jira.cfg.xml',
          'line'    => "    <property name=\"hibernate.dialect\">org.hibernate.dialect.MySQL5InnoDBDialect</property>",
          'match'   => '^( |\\t)*<property name\\="hibernate.dialect">',
          'after'   => '^( |\\t)*<property name\\="hibernate.connection.username">',
        )
      end
    end
  end
end
