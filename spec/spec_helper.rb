require File.expand_path(File.join(File.dirname(__FILE__), '..', 'nitpicker.rb'))
require 'rspec'
require 'rspec/autorun'
require 'fileutils'

# @return [String] The path of the test working dir
def spec_work_dir
  @spec_work_dir ||= File.expand_path(File.join(File.dirname(__FILE__), '..', 'tmp', 'work'))
end

# Initialize working dir
if File.exists?(spec_work_dir)
  FileUtils.rm_rf(spec_work_dir)
end

FileUtils.mkpath(spec_work_dir)

# @return [String] The path of a test project
def project_path(name)
  File.join(spec_work_dir, name)
end

# @param [Object] If a Symbol is provided, it will be used as repository state.
# @return [String] Path of the fixtures git repository (with desired state).
def git_fixtures_path(state = nil)
  name = state.is_a?(Symbol) ? "git_#{state}" : 'git'
  File.join(File.dirname(__FILE__), 'fixtures', name)
end

# @return [String] Path of the test repository
def repository_path
  File.join(File.dirname(__FILE__), '..', 'tmp', 'repository')
end

# Setup the test repository with desired state
def setup_origin(state = nil)
  if File.exists?(repository_path)
    FileUtils.rm_rf(repository_path)
  end
  FileUtils.cp_r(git_fixtures_path(state), repository_path)
end

# Setup a test project with desired options
# @param name [String] Name of the project
# @option options git [TrueClass,FalseClass,NilClass,Symbol] State of the git repository if desired
# @option options ruby_version [String] Specific ruby version if needed
# @return [Project] An initialized Project instance
def get_project(name, options = {})
  project_path = project_path(name)
  if File.exists?(project_path)
    FileUtils.rm_rf(project_path)
  end
  if state = options[:git]
    setup_origin(state)
    Command.new("git clone #{repository_path} #{project_path}").run
  else
    FileUtils.mkdir project_path unless File.exists?(project_path)
  end
  if options[:ruby_version]
    File.open(File.join(project_path(name), '.ruby-version'), 'w') do |file|
      file.puts options[:ruby_version]
    end
  end
  Project.new(project_path)
end

# @return [String] The current git revision of the project
def current_project_revision(name)
  Command.new("cd #{Shellwords.escape(project_path(name))} && git log --pretty=oneline HEAD^..HEAD").run[/^[^ ]+/]
end
