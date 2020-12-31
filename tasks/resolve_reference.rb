#!/opt/puppetlabs/bolt/bin/ruby
require_relative ENV['TASK_HELPER_RB'] || '../../ruby_task_helper/files/task_helper.rb'
#require_relative ENV['PLUGIN_HELPER_RB'] || '../../ruby_plugin_helper/lib/plugin_helper.rb'

require 'pathname'
require 'json'
require 'yaml'

class GitlabGroup < TaskHelper
  def depaginate(paginated_things)
    things = paginated_things
    while paginated_things.has_next_page?
      paginated_things = paginated_things.next_page
      things += paginated_things
    end
    things
  end

  def task(name: nil, **kwargs)
    Dir["#{kwargs[:extra_gem_path]}/gems/*/lib"].each { |path| $LOAD_PATH << path } # for gitlab

    group               = kwargs[:group]
    gitlab_api_token    = kwargs[:gitlab_api_token]
    gitlab_api_endpoint = kwargs[:gitlab_api_endpoint]
    archived_projects   = kwargs[:archived_projects]
    visibility          = kwargs[:visibility]
    transport_type      = kwargs[:transport_type]
    block_list          = kwargs[:block_list]
    allow_list          = kwargs[:allow_list]

    require 'gitlab'
    @client = Gitlab.client(
      endpoint: gitlab_api_endpoint,
      private_token: gitlab_api_token,
    )
    namespaces = depaginate(@client.namespaces(search: group))
    fail("ERROR: could not find a group or user named '#{group}'") if namespaces.empty?
    namespace = namespaces.first

    if namespace.kind == 'group'
      projects = depaginate(@client.group_projects(group, order_by: 'name', sort: 'asc'))
    else
      projects = depaginate(@client.user_projects(group, order_by: 'name', sort: 'asc'))
    end

    projects.reject! do |project|
      next(true) if project.archived && !archived_projects
      next(true) if visibility && !visibility.include?(project.visibility)
      if block_list
        patterns = block_list.select{|item| item =~ %r[\A/.*/\Z] }
        next(true) if patterns.any? { |p| project.name =~ Regexp.new( p.sub(%r[\A/],'').sub(%r[/\Z],'') ) }
        next(true) if (block_list - patterns).any? { |block_str| project.name == block_str }
      end
      if allow_list
        patterns = allow_list.select{|item| item =~ %r[\A/.*/\Z] }
        p_match = patterns.any? { |p| project.name =~ Regexp.new( p.sub(%r[\A/],'').sub(%r[/\Z],'') ) }
        s_match = (allow_list - patterns).any? { |allow_str| project.name == allow_str }
        next(true) unless (p_match || s_match)
      end
    end

    targets = projects.map do |project|
      target = YAML.load <<~YAML
        name: '#{project.path_with_namespace}'
        features:
          - puppet-agent
        config:
          transport: '#{transport_type}'
        vars: {}
        facts: {}
      YAML
      target['facts'] = project.to_hash
      target
    end
    { value: targets }
  end
end

GitlabGroup.run if $PROGRAM_NAME == __FILE__

