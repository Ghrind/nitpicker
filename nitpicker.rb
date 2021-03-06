require 'rubygems'
require 'bundler/setup'
require 'shellwords'
require 'colorize'

class Command

  class CommandError < StandardError
  end

  def initialize(line)
    @line = line
  end

  def run
    res = ''
    Bundler.with_clean_env do
      # puts "Running #{@line}"
      res = `#{@line} 2>&1`
      raise CommandError, res unless $? == 0
    end
    res
  end

end

# This class wraps all the source control and build commands for a project.
class Project

  DEFAULT_BUILD_SCRIPT_PATH = "./script/build"

  attr_reader :working_dir

  def initialize(working_dir)
    raise ArgumentError, "#{working_dir} doesn't exist" unless File.exists?(working_dir)
    @working_dir = working_dir
  end

  # @return [String] the name of the project
  def name
    File.basename(@working_dir)
  end

  # @return [String] Working dir path escaped for shell command
  def escaped_working_dir
    Shellwords.escape(@working_dir)
  end

  # @return [String,NilClass] The ruby version contained in the .ruby-version file or nil.
  def ruby_version
    begin
      return File.read(File.join(@working_dir, '.ruby-version')).strip
    rescue Errno::ENOENT
      return nil
    end
  end

  # @param revision [String] Hash of the desired revision
  # @return [String] Result of the build script for the desired revision
  def build(revision = nil)
    checkout revision if revision
    run_command_with_rvm DEFAULT_BUILD_SCRIPT_PATH
  end

  # @return [String] Latest known revision
  def latest_revision
    res = run_command "git log -1 --pretty=format:%H origin/#{current_branch}^..origin/#{current_branch}"
  end

  # Update the repository to latest changes
  def update
    run_command "git fetch"
  end

  private

  # @return [String] The current git branch
  def current_branch
    run_command("git rev-parse --abbrev-ref HEAD").strip
  end

  # Checkouts the working dir to desired revision
  # @param revision [String] Desired revision
  # @return [String] Result of the git reset command
  def checkout(revision)
    run_command "git reset #{revision} --hard"
  end

  # @param line [String] Command line to run
  # @return [String] Result of the command, ran with rvm if needed.
  def run_command_with_rvm(line)
    if ruby_version
      run_command "rvm #{ruby_version} do #{line}"
    else
      run_command line
    end
  end

  # @param line [String] Command line to run
  # @raise [CommandError] if the command return code is not zero.
  # @return [String] Standard and error output of the command, ran into the working dir.
  def run_command(line)
    Command.new("cd #{escaped_working_dir} && #{line}").run
  end

end

# 1. Fetch latest changes
# 2. Find latest revision
# 3. If there is a build log for this revision, do nothing
# 4. Otherwise, build
# 5. Save result in a log file
# 6. Display result of the build
# 7. Wait for a while
# 8. Go to the next project
class Nitpicker

  # Time to wait before checking another project (in seconds)
  DELAY_BETWEEN_PROJECTS = 5

  def initialize(working_dir)
    raise ArgumentError, "#{working_dir} doesn't exist" unless File.exists?(working_dir)
    @working_dir = working_dir
  end

  # Main loop, check all sequencially until interruption
  #
  # @param io [Object] Anything responding to :puts, all messages will be put in here
  #
  # @todo Clean the build logs after a while
  def run(io = nil)
    previous_projects_statuses = {}

    while true
      projects_statuses = iterate(io)

      if previous_projects_statuses != projects_statuses
        io.puts "Current state:"
        projects_statuses.each_pair do |project_name, status|
          if status
            io.puts "  - #{project_name}: OK".green
          else
            io.puts "  - #{project_name}: Failed".red
          end
        end
      end

      previous_projects_statuses = projects_statuses

      sleep DELAY_BETWEEN_PROJECTS
    end
  rescue Interrupt
    return
  end

  # Update and build each project sequencially
  #
  # @param io [Object] Anything responding to :puts, all messages will be put in here
  def iterate(io = nil)
    projects_statuses = {}
    for project in projects
      projects_statuses[project.name] = update_and_build(project, io)
    end
    projects_statuses
  end

  private

  # Update a project and build it if needed
  #
  # @param project [Project] The project to update and build
  # @param io [Object] Anything responding to :puts, all messages will be put in here
  #
  # @todo Clean the test.log before starting
  #
  # @return [TrueClass,FalseClass] True if everything went well, false otherwise
  def update_and_build(project, io = nil)
    begin
      project.update
    rescue Command::CommandError => error
      if io
        io.puts "Cannot update project #{project.name}".red
        io.puts error.message
      end
      return false
    end
    begin
      revision = project.latest_revision
    rescue Command::CommandError => error
      if io
        io.puts "Cannot get latest revision for project #{project.name}".red
        io.puts error.message
      end
      return false
    end
    if status = build_status(project, revision)
      return status == :success
    else
      io.puts "Starting build for #{project.name} @ #{revision} (#{Time.now.strftime('%Y-%m-%d %H:%M:%S')})" if io
      success = false
      log_path = build_log_path(project, revision)
      File.open(log_path, 'w') do |f|
        begin
          f << project.build(revision)
          success = true
        rescue Command::CommandError => error
          f << error
        end
      end
      if success
        FileUtils.mv log_path, build_log_path(project, revision, :succeed)
        io.puts "Build succeed for #{project.name} @ #{revision}.".green if io
      else
        failed_log_path = build_log_path(project, revision, :failed)
        FileUtils.mv log_path, failed_log_path
        if io
          io.puts "Build failed for #{project.name} @ #{revision}.".red
          io.puts "See #{failed_log_path} for more information."
        end
        return false
      end
    end
    return true
  end

  # @return [Array<Project>] An array of all projects in the working dir
  def projects
    Dir.glob(File.join(@working_dir, '*')).map{|entry| File.directory?(entry) ? Project.new(entry) : nil }.compact
  end

  # @param project [Project]
  # @param revision [String] A git revision hash
  # @return [String] The path of the build log for given project/revision
  def build_log_path(project, revision, status = nil)
    short_rev = revision[0..6]
    path = if File.directory?(File.join(project.working_dir, 'log'))
      File.join(project.working_dir, 'log', short_rev)
    else
      File.join(project.working_dir, short_rev)
    end
    if status.to_s != ''
      path << ".#{status}"
    end
    path + '.log'
  end

  # @param project [Project]
  # @param revision [String] A git revision hash
  # @return [Symbol,NilClass] Return nil if there is no build log, return :success or :failure depanding on build status otherwise.
  def build_status(project, revision)
    return :success if File.exists?(build_log_path(project, revision, :succeed))
    return :failure if File.exists?(build_log_path(project, revision, :failed))
    nil
  end

end

if __FILE__ == $0
  n = Nitpicker.new('work')
  n.run($stdout)
end
