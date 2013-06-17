#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'

class FolderAnalyzer
  attr_accessor :folder_name
  def initialize(name)
    @folder_name = name
  end

  def projects
    @projects ||= File.read(File.join(folder_name, "projects.txt")).split("\n")
  end
end


class ProjectParser
  def self.instance
    @instance ||= ProjectParser.new
  end

  def initialize
    ensure_cache
  end

  def result(git_url)
    doc = get_doc(git_url)
    return {} unless doc
    begin
      return {
        :commits_count    => commits_count(doc),
        :repo_description => repo_description(doc),
        :stargazers_count => stargazers_count(doc),
        :forks_count      => forks_count(doc)
      }
    rescue Exception => e
      binding.pry
    end
  end

  def printable_result(git_url)
    p_info = result(git_url)
    project_name = git_url.split("/")[3..-1].join("/").gsub(/\.git/, "")

    info = "\n  #{p_info[:repo_description]}\n   #{p_info[:commits_count]}, #{p_info[:stargazers_count]} stars, #{p_info[:forks_count]} forks"
    "#{project_name}: #{info}\n"
  end

  def get_doc(git_url)
    url = get_http_url(git_url)
    #puts "parsing #{url}"
    html = http_get(url)
    return nil unless html
    doc  = Nokogiri::XML(html)
  end

  def commits_count(doc)
    doc.css('p.history-link').text.strip
  end

  def repo_description(doc)
    doc.css('div#repository_description p').text.gsub("Read more", "").strip
  end

  def stargazers_count(doc)
    doc.css('ul.pagehead-actions a.social-count').first.text.strip
  end

  def forks_count(doc)
    doc.css('ul.pagehead-actions a.social-count').last.text.strip
  end

  def latest_commit(doc)
    # https://github.com/dump247/angular.tree/commits/master.atom
  end


  def http_get(url)
    cached_file = cache_key(url)
    if File.exists?(cached_file)
      File.open(cached_file, "r:UTF-8").read
    else
      begin
        html = open(url).read
      rescue OpenURI::HTTPError => e
        puts "**** ERROR *****: #{url} returned #{e.message}"
        return nil
      end
      File.open(cached_file, "w:UTF-8") do |f|
        f.puts html
      end
      html
    end
  end

  def cache_key(url)
    fname = url.gsub(/\.git/, "").split("/")[3..-1].join("__")
    File.join(".cache", fname)
  end

  def get_http_url(git_url)
    git_url.gsub(/\.git$/, "")
  end

  def ensure_cache
    `mkdir -p .cache`
  end
end

class ReadmeWriter
  REGEX = /\<\!-- PROJECTS_LIST_START --\>(.*)\<\!-- PROJECTS_LIST_END --\>/m
  REGEX_START = "<!-- PROJECTS_LIST_START -->"
  REGEX_END   = "<!-- PROJECTS_LIST_END -->"
  EMPTY_LIST  = "#{REGEX_START}\n#{REGEX_END}"

  attr_accessor :folder
  attr_accessor :content

  def initialize(folder)
    @folder = folder
    ensure_html_comments
  end

  def add_projects_list(results)
    indented_results = results.join("\n").split("\n").map{|x| "    #{x}"}.map{|x| x.rstrip }.join("\n")
    list_content = REGEX_START + "\n#{indented_results}\n" + REGEX_END
    @content     = content.gsub(REGEX, list_content)
    save
  end

  def clear_projects_list
    @content = content.gsub(REGEX, EMPTY_LIST)
    save
  end

  def content
    @content ||= File.open(path, "r:UTF-8").read
  end

  def path
    File.join(folder, "Readme.md")
  end

  def save
    File.open(path, "w:UTF-8") do |f|
      f.puts content
    end
  end

  def git_commit
    `cd #{folder} && git add Readme.md && git commit -m "readme updated"`
  end

  def ensure_html_comments
    unless content.match(/PROJECTS_LIST_START/) && content.match(/PROJECTS_LIST_END/)
      @content = content + "\n\n" + EMPTY_LIST
      save
    end
  end
end

class Gitrepo
  attr_accessor :repo_name
  def initialize(repo_name)
    @repo_name = repo_name
  end

  def repo_path
    "git@github.com:mindreframer/#{repo_name}.git"
  end

  def update
    unless File.exists?(repo_name)
      clone
    else
      update_repo
    end
  end

  def clone
    `git clone #{repo_path} #{repo_name}`
  end

  def update_repo
    `cd #{repo_name} && git pull --rebase`
  end
end

class ProjectsExecuter
  FOLDERS = %w(angularjs docker elixir erlang golang hetzner lua-useful nginx-lua).map{|x| "#{x}-stuff"}
  def initialize

  end

  def folders
    FOLDERS
  end

  def update_projects_lists
    folders.each do |f|
      analyzer = FolderAnalyzer.new(f)
      results = []
      analyzer.projects.each do |p|
        puts "pulling info for repo #{p}"
        r = ProjectParser.instance.printable_result(p)
        results << r
      end

      readmewriter = ReadmeWriter.new(f)
      #readmewriter.clear_projects_list
      readmewriter.add_projects_list(results)
      readmewriter.git_commit
    end
  end

  def update_repos
    folders.each do |f|
      repo = Gitrepo.new(f)
      puts "updating repo #{f}"
      repo.update
    end
  end
end

pe = ProjectsExecuter.new
#pe.update_repos
pe.update_projects_lists