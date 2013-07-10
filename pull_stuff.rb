#!/usr/bin/env ruby

require './logic'

pe = ProjectsExecuter.new
#pe.update_repos
pe.update_projects_lists

#### update top readme
my_projects  = FOLDERS.map{|x| "http://github.com/mindreframer/#{x}"}
# readmewriter = ReadmeWriter.new('.')
# readmewriter.add_projects_list(my_projects)
# readmewriter.git_commit
# readmewriter.git_push_if_changed
