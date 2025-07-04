# Reference

<!-- DO NOT EDIT: This document was generated by Puppet Strings -->

## Table of Contents

### Classes

* [`elastic_stack::repo`](#elastic_stack--repo): Set up the package repository for Elastic Stack components

## Classes

### <a name="elastic_stack--repo"></a>`elastic_stack::repo`

elastic_stack::repo

#### Examples

##### 

```puppet
include elastic_stack::repo
```

#### Parameters

The following parameters are available in the `elastic_stack::repo` class:

* [`oss`](#-elastic_stack--repo--oss)
* [`prerelease`](#-elastic_stack--repo--prerelease)
* [`priority`](#-elastic_stack--repo--priority)
* [`proxy`](#-elastic_stack--repo--proxy)
* [`version`](#-elastic_stack--repo--version)
* [`base_repo_url`](#-elastic_stack--repo--base_repo_url)
* [`gpg_key_source`](#-elastic_stack--repo--gpg_key_source)
* [`apt_keyring_name`](#-elastic_stack--repo--apt_keyring_name)

##### <a name="-elastic_stack--repo--oss"></a>`oss`

Data type: `Boolean`

Whether to use the purely open source (i.e., bundled without X-Pack) repository

Default value: `false`

##### <a name="-elastic_stack--repo--prerelease"></a>`prerelease`

Data type: `Boolean`

Whether to use a repo for prerelease versions, like "6.0.0-rc2"

Default value: `false`

##### <a name="-elastic_stack--repo--priority"></a>`priority`

Data type: `Optional[Integer]`

A numeric priority for the repo, passed to the package management system

Default value: `undef`

##### <a name="-elastic_stack--repo--proxy"></a>`proxy`

Data type: `String`

The URL of a HTTP proxy to use for package downloads (YUM only)

Default value: `'absent'`

##### <a name="-elastic_stack--repo--version"></a>`version`

Data type: `Integer`

The (major) version of the Elastic Stack for which to configure the repo

Default value: `7`

##### <a name="-elastic_stack--repo--base_repo_url"></a>`base_repo_url`

Data type: `Optional[String]`

The base url for the repo path

Default value: `undef`

##### <a name="-elastic_stack--repo--gpg_key_source"></a>`gpg_key_source`

Data type: `Stdlib::Filesource`

The gpg key for the repo

Default value: `'https://artifacts.elastic.co/GPG-KEY-elasticsearch'`

##### <a name="-elastic_stack--repo--apt_keyring_name"></a>`apt_keyring_name`

Data type: `String[1]`

The keyring filename to create (APT only)
The filename extention is important here.
Use `.asc` if the key is armored and `.gpg` if it's unarmored

Default value: `'elastic-keyring.asc'`

