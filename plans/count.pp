# Example plan, prints number of Targets from inventory
#
# @param targets
#    By default: `project_targets` group from inventory
#
plan gitlab_inventory::count(
  TargetSpec $targets = 'gitlab_projects'
){
  $project_targets = get_targets($targets)
  out::message( "Projects: ${project_targets.size}" )
  out::message( "Projects:\n${project_targets.map |$x| { "- ${x.facts['path']}" }.join("\n")}" )
}
