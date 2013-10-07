require 'rubygems'
require 'bundler/setup'
require 'shellwords'

class Command

  class CommandError < StandardError
  end

  def initialize(line)
    @line = line
  end

  def run
    # puts "Running #{@line}"
    res = `#{@line} 2>&1`
    raise CommandError, res unless $? == 0
    res
  end

end

# This class wraps all the source control and build commands for a project.
class Project

  DEFAULT_BUILD_SCRIPT_PATH = "./script/build"

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
    res = run_command "git log --pretty=oneline origin^..origin"
    res[/^[^ ]+/]
  end

  # Updates the repository to latest changes
  def update
    run_command "git fetch"
  end

  private

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

class Nitpicker
  # 1. Update everything
  # 2. Get latest revision
  # 3. If revision has been build, do nothing
  # 4. If revision hasn't been build, build it
  # 5. Save result in a log file
  # 6. Display result of the build
end

#p = Project.new('/home/benoit/eyeka/apps/orca-upload')

#puts "Ruby: #{p.ruby_version}"

#res = p.build '4d9690766d4c2ae7c4431404ab0581d76f170e76'
#File.open('result.log', 'w') do |f|
#  f << res
#end
#
#puts $?

#p.update
#rev = p.latest_revision
#puts p.build rev
