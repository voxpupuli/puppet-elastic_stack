# elastic_stack::repo
#
# @summary Set up the package repository for Elastic Stack components
#
# @example
#   include elastic_stack::repo
#
# @param oss Whether to use the purely open source (i.e., bundled without X-Pack) repository
# @param prerelease Whether to use a repo for prerelease versions, like "6.0.0-rc2"
# @param priority A numeric priority for the repo, passed to the package management system
# @param proxy The URL of a HTTP proxy to use for package downloads (YUM only)
# @param version The (major) version of the Elastic Stack for which to configure the repo
# @param base_repo_url The base url for the repo path
# @param gpg_key_source The gpg key for the repo
# @param apt_keyring_name The keyring filename to create (APT only)
#   The filename extention is important here.
#   Use `.asc` if the key is armored and `.gpg` if it's unarmored  
class elastic_stack::repo (
  Boolean            $oss                       = false,
  Boolean            $prerelease                = false,
  Optional[Integer]  $priority                  = undef,
  String             $proxy                     = 'absent',
  Integer            $version                   = 7,
  Stdlib::Filesource $gpg_key_source            = 'https://artifacts.elastic.co/GPG-KEY-elasticsearch',
  String[1]          $apt_keyring_name          = 'elastic-keyring.asc',
  Optional[String]  $base_repo_url             = undef,
) {
  if $prerelease {
    $version_suffix = '.x-prerelease'
  } else {
    $version_suffix = '.x'
  }

  if $oss {
    $version_prefix = 'oss-'
  } else {
    $version_prefix = ''
  }

  if $version > 2 { # lint:ignore:version_comparison
    $_repo_url = $base_repo_url ? {
      undef   => 'https://artifacts.elastic.co/packages',
      default => $base_repo_url,
    }
    case $facts['os']['family'] {
      'Debian': {
        $_repo_path = 'apt'
      }
      default: {
        $_repo_path = 'yum'
      }
    }
  } else {
    $_repo_url = $base_repo_url ? {
      undef   => 'https://packages.elastic.co/elasticsearch',
      default => $base_repo_url,
    }
    case $facts['os']['family'] {
      'Debian': {
        $_repo_path = 'debian'
      }
      default: {
        $_repo_path = 'centos'
      }
    }
  }

  $base_url = "${_repo_url}/${version_prefix}${version}${version_suffix}/${_repo_path}"
  $description='Elastic package repository.'

  case $facts['os']['family'] {
    'Debian': {
      include apt

      apt::source { 'elastic':
        comment  => $description,
        location => $base_url,
        release  => 'stable',
        repos    => 'main',
        key      => {
          'name'   => $apt_keyring_name,
          'source' => $gpg_key_source,
        },
        pin      => $priority,
      }
    }
    'RedHat', 'Linux': {
      yumrepo { 'elastic':
        descr    => $description,
        baseurl  => $base_url,
        gpgcheck => 1,
        gpgkey   => $gpg_key_source,
        enabled  => 1,
        proxy    => $proxy,
        priority => $priority,
      }
      ~> exec { 'elastic_yumrepo_yum_clean':
        command     => 'yum clean metadata expire-cache --disablerepo="*" --enablerepo="elastic"',
        refreshonly => true,
        returns     => [0, 1],
        path        => ['/bin', '/usr/bin', '/usr/local/bin'],
        cwd         => '/',
      }
    }
    'Suse': {
      # Older versions of SLES do not ship with rpmkeys
      if $facts['os']['name'] == 'SLES' and versioncmp($facts['os']['release']['major'], '11') <= 0 {
        $_import_cmd = "rpm --import ${gpg_key_source}"
      }
      else {
        $_import_cmd = "rpmkeys --import ${gpg_key_source}"
      }

      exec { 'elastic_suse_import_gpg':
        command => $_import_cmd,
        unless  => "test $(rpm -qa gpg-pubkey | grep -i 'D88E42B4' | wc -l) -eq 1",
        notify  => Zypprepo['elastic'],
        path    => ['/bin', '/usr/bin', '/usr/local/bin'],
        cwd     => '/',
      }

      zypprepo { 'elastic':
        baseurl     => $base_url,
        enabled     => 1,
        autorefresh => 1,
        name        => 'elastic',
        gpgcheck    => 1,
        gpgkey      => $gpg_key_source,
        type        => 'yum',
        priority    => $priority,
      }
      ~> exec { 'elastic_zypper_refresh_elastic':
        command     => 'zypper refresh elastic',
        refreshonly => true,
        path        => ['/bin', '/usr/bin', '/usr/local/bin'],
        cwd         => '/',
      }
    }
    default: {
      fail("\"${module_name}\" provides no repository information for OSfamily \"${facts['os']['family']}\"")
    }
  }
}
