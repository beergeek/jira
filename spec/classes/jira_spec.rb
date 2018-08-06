require 'spec_helper'

describe 'jira' do
  let :facts do
    {
      os: { 'family' => 'RedHat', 'release' => { 'major' => '7' } },
      osfamily: 'RedHat',
      operatingsystem: 'RedHat',
    }
  end

  context 'With defaults (but setting JAVA_HOME)' do
    let :params do
      {
        java_home: '/var/java',
      }
    end

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
          'creates'       => '/opt/atlassian/jira/atlassian-jira-software-7.11.1-standalone',
          'cleanup'       => true,
          'user'          => 'jira',
          'group'         => 'jira',
        ).that_requires('File[/opt/atlassian/jira]')
      end

      it do
        is_expected.to contain_file('/opt/atlassian/jira/current').with(
          'ensure'  => 'link',
          'target'  => '/opt/atlassian/jira/atlassian-jira-software-7.11.1-standalone',
        )
      end
    end

    describe 'jira::config' do
      it do
        is_expected.to contain_file_line('jira_home_dir').with(
          'ensure'  => 'present',
          'path'    => '/opt/atlassian/jira/atlassian-jira-software-7.11.1-standalone/atlassian-jira/WEB-INF/classes/jira-application.properties',
          'line'    => 'jira.home=/var/atlassian/application-data/jira',
        )
      end

      it do
        is_expected.to contain_file('base_config').with(
          'ensure'  => 'file',
          'owner'   => 'jira',
          'group'   => 'jira',
          'mode'    => '0644',
          'source'  => 'puppet:///modules/jira/dbconfig.xml',
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
        java_home: '/var/java'
      }
    end

    describe 'jira::config' do
      it do
        is_expected.to contain_archive('/tmp/mysql-connector-java-5.1.46.tar.gz').with(
          'ensure'          => 'present',
          'extract'         => true,
          'extract_command' => "tar -zxf %s --strip-components 1 --exclude='lib*' */mysql-connector-java-5.1.46.jar",
          'extract_path'    => '/opt/atlassian/jira/atlassian-jira-software-7.11.1-standalone/lib',
          'source'          => 'https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.46.tar.gz',
          'creates'         => '/opt/atlassian/jira/atlassian-jira-software-7.11.1-standalone/lib/mysql-connector-java-5.1.46.jar',
          'cleanup'         => true,
          'user'            => 'jira',
          'group'           => 'jira',
        )
      end

      it do
        is_expected.to contain_file('java_args').with(
          'ensure'  => 'file',
          'path'    => '/opt/atlassian/jira/atlassian-jira-software-7.11.1-standalone/bin/setenv.sh',
          'owner'  => 'jira',
          'group'  => 'jira',
          'mode'   => '0644',
        ).with_content(/JVM_SUPPORT_RECOMMENDED_ARGS=" -Djira\.upgrade\.fail\.if\.mysql\.unsupported=false"/)
      end

      it do
        is_expected.to contain_file_line('db_type').with(
          'ensure'  => 'present',
          'path'    => '/var/atlassian/application-data/jira/dbconfig.xml',
          'line'    => "    <database-type>mysql</database-type>",
          'match'   => '^( |\t)*<database-type>',
          'after'   => '^( |\t)*<delegator-name>',
        ).that_requires("File[base_config]")
      end

      it do
        is_expected.to contain_file_line('db_url').with(
          'ensure'  => 'present',
          'path'    => '/var/atlassian/application-data/jira/dbconfig.xml',
          'line'    => "    <url>jdbc:mysql://address=(protocol=tcp)(host=mysql0.puppet.vm)(port=3306)/jiradb?useUnicode=true&amp;characterEncoding=UTF8&amp;sessionVariables=default_storage_engine=InnoDB</url>",
          'match'   => '^( |\t)*<url>',
          'after'   => '^( |\t)*<jdbc-datasource>',
        ).that_requires("File_line[db_type]")
      end

      it do
        is_expected.to contain_file_line('db_driver').with(
          'ensure'  => 'present',
          'path'    => '/var/atlassian/application-data/jira/dbconfig.xml',
          'line'    => "    <driver-class>com.mysql.jdbc.Driver</driver-class>",
          'match'   => '^( |\t)*<driver-class>',
          'after'   => '^( |\t)*<url>',
        ).that_requires("File_line[db_url]")
      end

      it do
        is_expected.to contain_file_line('db_user').with(
          'ensure'  => 'present',
          'path'    => '/var/atlassian/application-data/jira/dbconfig.xml',
          'line'    => "    <username>jira</username>",
          'match'   => '^( |\t)*<username>',
          'after'   => '^( |\t)*<driver-class>',
        ).that_requires("File_line[db_driver]")
      end

      it do
        is_expected.to contain_file_line('db_password').with(
          'ensure'  => 'present',
          'path'    => '/var/atlassian/application-data/jira/dbconfig.xml',
          'line'    => "    <password>password123</password>",
          'match'   => '^( |\t)*<password>',
          'after'   => '^( |\t)*<username>',
        ).that_requires("File_line[db_user]")
      end
    end
  end

  context 'jira with HTTPS' do
    let :params do
      {
        manage_db_settings: false,
        java_home: '/var/java',
        https: true,
      }
    end

    describe 'jira::config' do
      it do
        is_expected.to contain_file('tomcat_connector').with(
          'ensure' => 'file',
          'path'   => '/opt/atlassian/jira/atlassian-jira-software-7.11.1-standalone/conf/server.xml',
          'owner'  => 'jira',
          'group'  => 'jira',
          'mode'   => '0644',
        ).with_content(%r{8443})
      end
    end
  end
end
