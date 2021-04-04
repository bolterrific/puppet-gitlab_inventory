# gitlab_inventory

#### Table of Contents

<!-- vim-markdown-toc GFM -->

* [Description](#description)
* [Setup](#setup)
  * [Setup Requirements](#setup-requirements)
* [Usage](#usage)
  * [Using the plugin in a Bolt inventory file](#using-the-plugin-in-a-bolt-inventory-file)
* [Reference](#reference)
* [Limitations](#limitations)
* [Development](#development)

<!-- vim-markdown-toc -->

## Description

**gitlab_inventory** is an [inventory reference plugin] for [Puppet
Bolt]. It uses the GitLab API to dynamically provide a list of [`local`
transport] Targets that represent each project under a GitLab group.

This module also contains an example Bolt project with a working
`inventory.yaml` and several Bolt plans.

## Setup

### Setup Requirements

* [Puppet Bolt][bolt]
  * Preferred version: Bolt 3.17+
  * Strict minimum is Bolt 2.15+ (untested)
  * Bolt must be installed from an [OS package][bolt-install] (don't use the RubyGem)
  * **Note:** The example `inventory.yaml` assumes Bolt 2.37+ (see comments)
* A GitLab API personal auth token with sufficient scope

## Usage

To use this plugin in your own Bolt project, configure it to provide `targets`
in the [inventory file].

### Using the plugin in a Bolt inventory file

An example `inventory.yaml` file:

```yaml
version: 2

groups:
  - name: gitlab_projects
    targets:
      - _plugin: gitlab_inventory  # <- Plugin provides `local` Targets
        group:                     # <- GitLab group with Target repos
          _plugin: env_var
          var: GITLAB_GROUP
          default: simp
        # some optional parameters:
        gitlab_api_token:          # <- API token with scope that can get repos
          _plugin: env_var         # <- (provided by another Bolt plugin)
          var: GITLAB_API_PRIVATE_TOKEN
        archived_repos: true
        allow_list:
          - '/^pupmod-simp/'
          - 'simp-core'
        block_list:
          - '/gitlab-oss/'
config:
  transport: local
  local:
    bundled-ruby: true
    tmpdir:
     _plugin: env_var
     var: PWD

```

## Reference

See [REFERENCE.md](./REFERENCE.md)

## Limitations

In order to provide an example Bolt project in the same module as the inventory
plugin, the example `bolt-project.yaml` adds `..` to the `modulepath`.  This
means that (when using the example Bolt project) the folder containing this repo
_must_ be named `gitlab_inventory`.  There may be other weirdness, depending on
whether neighboring directories contain Bolt projects or Puppet modules.

This quirk only affects the example Bolt project; it will not affect the
inventory plugin or Bolt plans from your own Bolt projects.

## Development

Submit PRs at the project's GitHub repository.

[bolt]: https://puppet.com/docs/bolt/latest/bolt.html
[bolt-install]: https://puppet.com/docs/bolt/latest/bolt_installing.html
[inventory file]: https://puppet.com/docs/bolt/latest/inventory_file_v2.html
[inventory reference plugin]: https://puppet.com/docs/bolt/latest/using_plugins.html#reference-plugins
[`local` transport]: https://puppet.com/docs/bolt/latest/bolt_transports_reference.html#local
[gitlab-rb]: https://rubygems.org/gems/gitlab
[Puppet Bolt]: https://puppet.com/docs/bolt/latest/bolt.html
[rvm]: https://rvm.io
