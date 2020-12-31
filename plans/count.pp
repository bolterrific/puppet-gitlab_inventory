# Example plan, prints number of Targets from inventory
#
# @param targets
#    By default: `repo_targets` group from inventory
#
# @param gitlab_api_token
#    GitLab API token.  By default, this will use the `GITHUB_API_TOKEN` environment variable.
#
plan gitlab_inventory::count(
  TargetSpec $targets = 'repo_targets',
  String[1]  $gitlab_api_token = system::env('GITHUB_API_TOKEN'),
){
  $repo_targets = get_targets($targets)
  out::message( "Repos: ${targets.size}" )
}
