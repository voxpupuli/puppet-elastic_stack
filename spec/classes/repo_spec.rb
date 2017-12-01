require 'spec_helper'

describe 'elastic_stack::repo', :type => 'class' do
  default_params = { }
  on_supported_os(facterversion: '2.4').each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }

      describe 'distro-specific package repositories' do
        case facts[:os]['family']
        when 'Debian'
          it { should contain_apt__source('elastic')
            .with(
              :location => 'https://artifacts.elastic.co/packages/6.x/apt'
            ) }
        when 'RedHat'
          it { should contain_yumrepo('elastic')
            .with(
              :baseurl => 'https://artifacts.elastic.co/packages/6.x/yum'
            ) }
        when 'Suse'
          it { should contain_exec('elastic_suse_import_gpg')
            .with(
							:command => "rpmkeys --import https://artifacts.elastic.co/GPG-KEY-elasticsearch"
						) }
          it { should contain_zypprepo('elastic')
            .with(
							:baseurl => 'https://artifacts.elastic.co/packages/6.x/yum'
						) }
          it { should contain_exec('elastics_zypper_refresh_elastic') }
        end
      end

      describe 'overriding version' do
        let(:params) do
          default_params.merge(:version => 10)
        end

        case facts[:os]['family']
        when 'Debian'
          it { should contain_apt__source('elastic')
            .with(
              :location => 'https://artifacts.elastic.co/packages/10.x/apt'
            ) }
        when 'RedHat'
          it { should contain_yumrepo('elastic')
            .with(
              :baseurl => 'https://artifacts.elastic.co/packages/10.x/yum'
            ) }
        when 'Suse'
          it { should contain_exec('elastic_suse_import_gpg')
            .with(
							:command => "rpmkeys --import https://artifacts.elastic.co/GPG-KEY-elasticsearch"
						) }
          it { should contain_zypprepo('elastic')
            .with(
							:baseurl => 'https://artifacts.elastic.co/packages/10.x/yum') }
          it { should contain_exec('elastics_zypper_refresh_elastic') }
        end
      end

      describe 'overriding priority' do
        let(:params) do
          default_params.merge(:priority => 99)
        end

        case facts[:os]['family']
        when 'Debian'
          it { should contain_apt__source('elastic')
            .with(
              :location => 'https://artifacts.elastic.co/packages/6.x/apt',
							:pin			=> 99
            ) }
        when 'RedHat'
          it { should contain_yumrepo('elastic')
            .with(
              :baseurl  => 'https://artifacts.elastic.co/packages/6.x/yum',
							:priority => 99
            ) }
        when 'Suse'
          it { should contain_exec('elastic_suse_import_gpg')
            .with(
							:command => "rpmkeys --import https://artifacts.elastic.co/GPG-KEY-elasticsearch"
						) }
          it { should contain_zypprepo('elastic')
            .with(
							:baseurl  => 'https://artifacts.elastic.co/packages/6.x/yum',
							:priority => 99
						) }
          it { should contain_exec('elastics_zypper_refresh_elastic') }
        end
      end

      describe 'overriding proxy' do
        let(:params) do
          default_params.merge(:proxy => 'http://proxy.com:8080')
        end

        case facts[:os]['family']
        when 'RedHat'
          it { should contain_yumrepo('elastic')
						.with(
							:proxy => 'http://proxy.com:8080'
            ) }
        end
      end

      describe 'overriding prerelease' do
        let(:params) do
          default_params.merge(:prerelease => true)
        end

        case facts[:os]['family']
        when 'Debian'
          it { should contain_apt__source('elastic')
            .with(
              :location => 'https://artifacts.elastic.co/packages/6.x-prerelease/apt',
            ) }
        when 'RedHat'
          it { should contain_yumrepo('elastic')
            .with(
              :baseurl  => 'https://artifacts.elastic.co/packages/6.x-prerelease/yum',
            ) }
        when 'Suse'
          it { should contain_exec('elastic_suse_import_gpg')
            .with(
							:command => "rpmkeys --import https://artifacts.elastic.co/GPG-KEY-elasticsearch"
						) }
          it { should contain_zypprepo('elastic')
            .with(
							:baseurl  => 'https://artifacts.elastic.co/packages/6.x-prerelease/yum',
						) }
          it { should contain_exec('elastics_zypper_refresh_elastic') }
        end

      end
    end
  end
end
