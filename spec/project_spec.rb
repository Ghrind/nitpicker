require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper.rb'))

describe Project do

  describe '#initialize' do
    it "should fail if working dir does not exist" do
      -> {
        Project.new('my/dir/does/not.exist')
      }.should raise_error ArgumentError
    end

    it "should set @working_dir" do
      get_project('foobar')
      Project.new(project_path('foobar')).instance_variable_get(:@working_dir).should == project_path('foobar')
    end
  end

  describe '#name' do
    it "should return project dir basename" do
      get_project('foobar').name.should == 'foobar'
    end
  end

  describe '#escaped_working_dir' do
    it "should escape working dir path" do
      project = get_project('foobar')
      project.instance_variable_set(:@working_dir, './a space')
      project.escaped_working_dir.should == './a\ space'
    end
  end

  describe '#ruby_version' do
    context "when .ruby-version file exists" do
      it "should return rubye version string" do
        project = get_project('special_ruby', ruby_version: 'ree')
        project.ruby_version.should == 'ree'
      end
    end
    context "when .ruby-version file does not exist" do
      it "should return nil" do
        get_project('foobar').ruby_version.should be_nil
      end
    end
  end

  describe '#build' do
    context "when revision is provided" do
      it "should change revision" do
        project = get_project('foobar')
        project.should_receive(:run_command_with_rvm)

        project.should_receive(:checkout).with('another_revision')
        project.build('another_revision')
      end
    end
    it "should run the build script using rvm" do
      project = get_project('foobar')

      project.should_receive(:run_command_with_rvm).with(Project::DEFAULT_BUILD_SCRIPT_PATH).and_return('result')
      project.build.should == 'result'
    end
  end

  describe '#current_branch' do
    it "should get current branch name" do
      project = get_project('project_git_1', git: true)
      project.send(:current_branch).should == 'master'
    end
  end

  describe '#latest_revision' do
    it "should get the origin for the current branch" do
      project = get_project('project_git_1', git: true)
      project.stub(current_branch: 'mybranch')
      Command.should_receive(:new).with(/origin\/mybranch\^\.\.origin\/mybranch/).and_return(double(Command, run: ''))
      project.latest_revision
    end
    it "should return the latest git revision" do
      project_1 = get_project('project_git_1', git: true)
      project_1.latest_revision.should == '398feb1f547aad595999920ccd45aea51a6acd6e'

      project_2 = get_project('project_git_2', git: :updated)
      project_2.latest_revision.should == 'ed3e309f8889cb3ea377b7f24ddddd80431327a5'
    end
  end

  describe '#update' do
    it "should fetch the latest changes" do
      project = get_project('project_git_1', git: true)
      setup_origin(:updated)

      project.update
      project.latest_revision.should == 'ed3e309f8889cb3ea377b7f24ddddd80431327a5'
    end
  end

  describe '#checkout' do
    it "should reset to the desired revision" do
      project = get_project('project_git_1', git: true)
      current_project_revision(project.name).should == '398feb1f547aad595999920ccd45aea51a6acd6e'
      project.send(:checkout, '00da9efbe2b7e80a039c73d3021fff39b2bed289')
      current_project_revision(project.name).should == '00da9efbe2b7e80a039c73d3021fff39b2bed289'
    end
  end

  describe '#run_command_with_rvm' do
    context "with a specific ruby version" do
      it "should append 'rvm do'" do
        project = get_project('foobar', ruby_version: 'ree')
        project.should_receive(:run_command).with('rvm ree do my_command')
        project.send(:run_command_with_rvm, 'my_command')
      end
    end
    context "without a specific ruby version" do
      it "should run command without adding anything" do
        project = get_project('foobar')
        project.should_receive(:run_command).with('my_command')
        project.send(:run_command_with_rvm, 'my_command')
      end
    end
  end

  describe '#run_command' do

    it "should change directory to working dir" do
      project = get_project('foobar')

      command = double Command, :run => true
      Command.should_receive(:new).with("cd #{project_path('foobar')} && my_command_line").and_return(command)

      project.send(:run_command, 'my_command_line')
    end

    it "should escape working dir" do
      project = get_project('foobar')
      project.should_receive(:escaped_working_dir).and_return('barfoo')

      command = double Command, :run => true
      Command.should_receive(:new).with("cd barfoo && my_command_line").and_return(command)

      project.send(:run_command, 'my_command_line')
    end

    it "should run command" do
      project = get_project('foobar')

      command = double Command
      Command.should_receive(:new).with("cd #{project_path('foobar')} && my_command_line").and_return(command)
      command.should_receive(:run)

      project.send(:run_command, 'my_command_line')
    end
  end

end
