# Clone all of a group's repos into a local directory
#
# @param targets
#    Name of `gitlab_inventory` Targets (or inventory group)
#
# @param target_dir
#    Local directory to clone repos into
#
# @param collision_strategy
#    Action to take when a local repo directory already exists
#
# @param clone_protocol
#    'http' or 'ssh'
#
# @param return_result
#    When `true`, plan returns data in a ResultSet
#
plan gitlab_inventory::clone_git_repos(
  TargetSpec $targets = 'gitlab_projects',
  Stdlib::Absolutepath $target_dir = "${system::env('PWD')}/_repos",
  Enum[fail,skip,overwrite,fetch] $collision_strategy = 'skip',
  Enum[http,ssh] $clone_protocol = 'http',
  Boolean $return_result  = false
){
  apply('localhost', '_description' => "Ensure target directory at '${target_dir}'"){
    file{ $target_dir: ensure => directory }
  }
  $gitlab_projects = get_targets($targets)

  $clone_results = $gitlab_projects.map |$project| {

    out::message( "== cloning '${project.facts['path']}'..." )

    $clone_url = $clone_protocol ? {
      'ssh'   => $project.facts['ssh_url_to_repo'],
      default => $project.facts['http_url_to_repo'],
    }

    # Handle collisions with existing directories
    $clone_dest_dir = "${target_dir}/${project.facts['path']}"
    if file::exists($clone_dest_dir){
      case $collision_strategy {
        'skip': {
          log::warn("SKIPPED: '${project.facts['path']}' - local directory already exists at clone destination '${clone_dest_dir}'")
          next(false)
        }
        'fail': { fail_plan("FATAL: local directory already exists at destination '${clone_dest_dir}'") }
        'overwrite': {
          log::error("WARNING: Removing and re-cloning existing directory at destination '${clone_dest_dir}'")
          run_command("rm -rf ${clone_dest_dir}",'localhost')
        }
        'fetch': {
          log::warning("INFO: Directory exists at destination '${clone_dest_dir}'; fetching all remotes instead of cloning")
          run_command("cd ${clone_dest_dir}; git fetch --all --tags; git checkout ${project.facts['default_branch']}",'localhost')
          next(false)
        }
        default: { fail_plan("FATAL: local directory already exists at destination '${clone_dest_dir}' and collision_strategy '${collision_strategy}' is unrecognized") }
      }
    }

    # Clone project
    run_command("cd ${target_dir.shellquote}; git clone '${clone_url}' '${project.facts['path']}'", 'localhost')
  }

  if $return_result {
    return( $clone_results )
  }
  # This runs concurrently, but can be a LOT slower than just cloning the repos
  # with run_command in a loop:
  ###apply($gitlab_projects, '_description' => "Ensure targets are cloned into '${target_dir}'"){
  ###  vcsrepo{ "${target_dir}/${facts.get('path')}":
  ###    ensure   => latest,
  ###    provider => 'git',
  ###    source   => $clone_url,
  ###  }
  ###}
}
