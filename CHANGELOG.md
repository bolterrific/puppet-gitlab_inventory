# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [0.2.0]

**Added**

* Inventory task is now completely self-sufficient
  - All dependencies are provided by Bolt's AIO package
  - This should make it simpler to manage network-isolated GitLab instances―you
    just need this repo and Bolt
* Added a new example Bolt plan, `gitlab_inventory::clone_git_repos`

**Removed**

* Removed dependency on external gems:
  - Removed dependency on `gitlab` RubyGem.
  - Removed requirement to run `gem install --user-install -g gems.deps.rb`
* From now on, all Gitlab API calls are handled via Bolt's natively vendored
  gems (like Faraday).

**Fixed**

* The `visibility` inventory parameter no longer fails when given a String
  (String must be one of: `public`, `internal`, or `private`)

## [0.1.1]

**Fixed**

* (Forge-only) Removed broken plan files from tarball published to the Forge

## [0.1.0]

**Added**

* Initial project
* Inventory plugin that returns GitLab group projects as `local` transport Targets
* Example Bolt project with working Plans and `inventory.yaml`

[Unreleased]: https://github.com/bolterrific/puppet-gitlab_inventory/compare/0.1.1...main
[0.1.0]: https://github.com/bolterrific/puppet-gitlab_inventory/releases/tag/0.1.0
[0.1.1]: https://github.com/bolterrific/puppet-gitlab_inventory/compare/0.1.0...0.1.1
[0.2.0]: https://github.com/bolterrific/puppet-gitlab_inventory/compare/0.1.1...0.2.0


