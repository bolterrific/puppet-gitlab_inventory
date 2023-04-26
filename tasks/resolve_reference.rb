#!/opt/puppetlabs/bolt/bin/ruby
# frozen_string_literal: true

require_relative ENV['TASK_HELPER_RB'] || '../../ruby_task_helper/files/task_helper.rb'

require 'pathname'
require 'json'
require 'yaml'

require 'uri'
require 'faraday'
require 'faraday_middleware'

# Ruby lifted and chopped from
#   https://github.com/puppetlabs/vmfloaty + https://github.com/puppetlabs/txgh
class Http
  def self.url?(url)
    uri = URI.parse(url)
    return true if uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    false
  end

  def self.get_conn(url, ssl: { verify: false }, headers: nil, verbose: false)
    raise 'Did not provide a url to connect to' if url.nil?
    url = "https://#{url}" unless url?(url)
    connection = Faraday.new(url: url, ssl: ssl, headers: headers) do |f|
      f.request :multipart
      f.request :json
      f.request :retry
      f.request :url_encoded

      f.response :json
      f.response :logger if verbose

      f.use(FaradayMiddleware::FollowRedirects)
      f.adapter(Faraday.default_adapter)
    end
    connection
  end
end


# Bare-bones GitLab API shim that auto-depaginates results
class GitLabMRI
  def self.client(endpoint:, private_token:)
    GitLabMRI.new(endpoint, private_token)
  end

  def initialize(endpoint, private_token)
    headers = {
     'PRIVATE-TOKEN' => private_token,
     'Content-Type' => 'application/json',
    }
    @conn = Http.get_conn(endpoint, headers: headers)
  end

  def depaginate(res)
    data = res.body
    until "#{res.headers['x-next-page']}".empty?
      links = []
      res.headers['link'].scan(/<(?<foo>http[^>]+)>; rel="(?<bar>[^"]+)"/){ |x,y| links << [y,x] }
      links = links.to_h

      unless links.key? 'next'
        raise("ERROR: totally expected a 'next' key in 'links' header: #{res.headers['link']}")
      end
      res = @conn.get(links['next'].strip)
      data += res.body
    end
    data
  end

  def namespaces(search: )
    url = "#{@conn.url_prefix}/namespaces"
    depaginate( @conn.get(url) )
  end

  def group_projects(group, order_by: 'name', sort: 'asc')
    url = "#{@conn.url_prefix}/groups/#{group}/projects?order_by=#{order_by}&sort=#{sort}"
    depaginate( @conn.get(url) )
  end

  def user_projects(user, order_by: 'name', sort: 'asc')
    url = "#{@conn.url_prefix}/users/#{user}/projects?order_by=#{order_by}&sort=#{sort}"
    depaginate( @conn.get(url) )
  end
end


# Return GitLab project for a group/user as Bolt Inventory Targets
class GitlabGroup < TaskHelper
  def task(name: nil, **kwargs) # rubocop:disable Lint/UnusedMethodArgument
    Dir["#{kwargs[:extra_gem_path]}/gems/*/lib"].each { |path| $LOAD_PATH << path } # for gitlab

    group               = kwargs[:group]
    gitlab_api_token    = kwargs[:gitlab_api_token]
    gitlab_api_endpoint = kwargs[:gitlab_api_endpoint]
    archived_projects   = kwargs[:archived_projects]
    visibility          = kwargs[:visibility]
    transport_type      = kwargs[:transport_type]
    block_list          = kwargs[:block_list]
    allow_list          = kwargs[:allow_list]

    @client = GitLabMRI.client(
      endpoint: gitlab_api_endpoint,
      private_token: gitlab_api_token,
    )
    namespaces = @client.namespaces(search: group)
    raise("ERROR: could not find a group or user named '#{group}'") if namespaces.empty?
    namespace = namespaces.first

    projects = (
      if namespace['kind'] == 'group'
        @client.group_projects(group)
      else
        @client.user_projects(group)
      end
    )

    projects.reject! do |project|
      next(true) if project['archived'] && !archived_projects
      next(true) if visibility && !visibility.include?(project['visibility'])
      if block_list
        patterns = block_list.select { |item| item =~ %r{\A/.*/\Z} }
        next(true) if patterns.any? { |p| project['path'] =~ Regexp.new(p.sub(%r{\A/}, '').sub(%r{/\Z}, '')) }
        next(true) if (block_list - patterns).any? { |block_str| project['path'] == block_str }
      end
      next unless allow_list
      patterns = allow_list.select { |item| item =~ %r{\A/.*/\Z} }
      p_match = patterns.any? { |p| project['path'] =~ Regexp.new(p.sub(%r{\A/}, '').sub(%r{/\Z}, '')) }
      s_match = (allow_list - patterns).any? { |allow_str| project['path'] == allow_str }
      next(true) unless p_match || s_match
    end

    targets = projects.map do |project|
      target = YAML.safe_load <<~YAML
        name: '#{project['path_with_namespace']}'
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
