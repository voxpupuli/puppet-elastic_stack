require 'spec_helper'

rpm_key_cmd = 'rpmkeys --import https://artifacts.elastic.co/GPG-KEY-elasticsearch'

def url(format, version)
  "https://artifacts.elastic.co/packages/#{version}/#{format}"
end

def declare_apt(version: '6.x', **params)
  params[:location] ||= url('apt', version)
  contain_apt__source('elastic').with(params)
end

def declare_yum(version: '6.x', **params)
  params[:baseurl] ||= url('yum', version)
  contain_yumrepo('elastic').with(params)
end

def declare_zypper(version: '6.x', **params)
  params[:baseurl] ||= url('yum', version)
  contain_zypprepo('elastic').with(params)
end

describe 'elastic_stack::repo', type: 'class' do
  default_params = {}
  on_supported_os(facterversion: '2.4').each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }

      describe 'distro-specific package repositories' do
        case facts[:os]['family']
        when 'Debian'
          it { is_expected.to declare_apt }
        when 'RedHat'
          it { is_expected.to declare_yum }
        when 'Suse'
          it { is_expected.to declare_zypper }
          it { is_expected.to contain_exec('elastic_suse_import_gpg').with(command: rpm_key_cmd) }
          it {
            is_expected.to contain_exec('elastic_zypper_refresh_elastic')
              .with(command: 'zypper refresh elastic')
          }
        end
      end

      describe 'overriding version' do
        let(:params) do
          default_params.merge(version: 5)
        end

        case facts[:os]['family']
        when 'Debian'
          it { is_expected.to declare_apt(version: '5.x') }
        when 'RedHat'
          it { is_expected.to declare_yum(version: '5.x') }
        when 'Suse'
          it { is_expected.to declare_zypper(version: '5.x') }
        end
      end

      describe 'overriding priority' do
        let(:params) do
          default_params.merge(priority: 99)
        end

        case facts[:os]['family']
        when 'Debian'
          it { is_expected.to declare_apt(pin: 99) }
        when 'RedHat'
          it { is_expected.to declare_yum(priority: 99) }
        when 'Suse'
          it { is_expected.to declare_zypper(priority: 99) }
        end
      end

      describe 'overriding proxy' do
        let(:params) do
          default_params.merge(proxy: 'http://proxy.com:8080')
        end

        case facts[:os]['family']
        when 'RedHat'
          it { is_expected.to declare_yum(proxy: 'http://proxy.com:8080') }
        end
      end

      describe 'overriding prerelease' do
        let(:params) do
          default_params.merge(prerelease: true)
        end

        case facts[:os]['family']
        when 'Debian'
          it { is_expected.to declare_apt(version: '6.x-prerelease') }
        when 'RedHat'
          it { is_expected.to declare_yum(version: '6.x-prerelease') }
        when 'Suse'
          it { is_expected.to declare_zypper(version: '6.x-prerelease') }
        end
      end
    end
  end
end
