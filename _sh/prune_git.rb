#!/usr/bin/env ruby
## du   -d 1|sort -n
## http://stevelorek.com/how-to-shrink-a-git-repository.html
require 'pty'

class GitPrunner
  attr_accessor :name
  def initialize(name)
    @name = name
  end

  def self.sorted_folders
    res     = %x(du -m -d 1 |sort -n)
    folders = res.split("\n").reverse.map{|x| x.split("\t").last}.map{|x| x[2..-1]}
    folders.reject!{|x| x == nil}
    folders
  end

  def self.show_overview
    %x(du -m -d 1 |sort -n)
  end

  def prune
    in_folder(name) do
      log "cleaning up #{name}"
      log "size before:  #{size_in_mb} MB"
      execute "rm -rf .git/refs/original/"
      execute "git reflog expire --expire=now --all"
      execute "git gc --prune=now"
      execute "git gc --aggressive --prune=now"
      log "size after:  #{size_in_mb} MB"
    end
  end

  def in_folder(folder, &block)
    old = Dir.pwd
    Dir.chdir(folder)
    yield
    Dir.chdir(old)
  end

  def size_in_mb
    %x(du -m -d 0).split.first
  end

  def log(msg)
    puts "--- #{msg}"
  end

  def execute(cmd)
    begin
      PTY.spawn( cmd ) do |stdin, stdout, pid|
        begin
          stdin.each { |line| print line }
        rescue Errno::EIO
        end
      end
    rescue PTY::ChildExited
      puts "The child process exited!"
    end
  end
end

#puts GitPrunner.show_overview
regex = ARGV[0]

to_prune = GitPrunner.sorted_folders
to_prune = to_prune.grep(%r(#{regex})) if regex
puts "WILL PRUNE "  + to_prune.join(",")
to_prune.each do |folder|
  GitPrunner.new(folder).prune
end
