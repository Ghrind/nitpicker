require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper.rb'))

describe Nitpicker do

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

  describe '#build_log_path' do
    it "should return the path for given project, revision" do
      project = get_project('foobar')
      Nitpicker.new(test_working_path).send(:build_log_path, project, 'my_revision').should == project_path(project.name) + '/my_revision.log'
    end
  end

  describe '#build_log_exists?' do
    context "when the file exists" do
      it "should return true" do
        nitpicker = Nitpicker.new(test_working_path)
        project = get_project('foobar')
        File.open(nitpicker.send(:build_log_path, project, 'my_revision'), 'w'){ |f| f << 'foobar' }
        Nitpicker.new(test_working_path).send(:build_log_exists?, project, 'my_revision').should be_true
      end
    end
    context "when the file does not exist" do
      it "should return false" do
        project = get_project('foobar')
        Nitpicker.new(test_working_path).send(:build_log_exists?, project, 'my_revision').should be_false
      end
    end
  end

  describe '#projects' do
    context "when there is no projects" do
      it "should return an empty array" do
        initialize_test_working_dir
        Nitpicker.new(test_working_path).send(:projects).should == []
      end
    end
    it "should find projects" do
      initialize_test_working_dir
      get_project('foobar')
      get_project('foobar_2')
      Nitpicker.new(test_working_path).send(:projects).size.should == 2
    end
    it "should return and array Project instances" do
      initialize_test_working_dir
      get_project('foobar')
      get_project('foobar_2')
      Nitpicker.new(test_working_path).send(:projects).first.class.should == Project
      Nitpicker.new(test_working_path).send(:projects).last.class.should == Project
    end
    it "should ignore files" do
      initialize_test_working_dir
      get_project('foobar')
      get_project('foobar_2')
      File.open(File.join(test_working_path, 'a file'), 'w'){ |f| f << 'foobar' }
      Nitpicker.new(test_working_path).send(:projects).size.should == 2
    end
  end

  describe '#update_and_build' do
    before do
      @project = get_project('foobar')
      @nitpicker = Nitpicker.new(test_working_path)
      @io = StringIO.new
    end

    it "should update project" do
      @project.should_receive(:update)
      @nitpicker.send(:update_and_build, @project)
    end

    context "when project can't be updated" do
      it "should return false" do
        @project.should_receive(:update).and_raise Command::CommandError.new
        @nitpicker.send(:update_and_build, @project).should be_false
      end
      it "should issue an error message" do
        @project.should_receive(:update).and_raise Command::CommandError.new
        @nitpicker.send(:update_and_build, @project, @io)
        @io.rewind
        @io.read.should =~ /Cannot update project/
      end
    end

    it "should find latest revision" do
      @project.should_receive(:update)

      @project.should_receive(:latest_revision).and_return('my_revision')
      @nitpicker.send(:update_and_build, @project)
    end

    context "latest revision can't be found" do
      before do
        @project.should_receive(:update)
        @project.should_receive(:latest_revision).and_raise Command::CommandError.new
      end
      it "should return false" do
        @nitpicker.send(:update_and_build, @project).should be_false
      end
      it "should issue an error message" do
        @nitpicker.send(:update_and_build, @project, @io)
        @io.rewind
        @io.read.should =~ /Cannot get latest revision/
      end
    end

    context "when latest build log exists" do
      before do
        @project.should_receive(:update)
        @project.should_receive(:latest_revision).and_return('my_revision')
        @nitpicker.should_receive(:build_log_exists?).with(@project, 'my_revision').and_return true
      end
      it "should do nothing" do
        @project.should_not_receive(:build)
        @nitpicker.send(:update_and_build, @project)
      end
      it "should return true" do
        @nitpicker.send(:update_and_build, @project).should be_true
      end
    end

    context "when latest build log does not exist" do
      before do
        @project.should_receive(:update)
        @project.should_receive(:latest_revision).and_return('my_revision')
        @nitpicker.should_receive(:build_log_exists?).with(@project, 'my_revision').and_return false
      end
      it "should build project" do
        @project.should_receive(:build)
        @nitpicker.send(:update_and_build, @project)
      end
      context "when build succeed" do
        it "should return true" do
          @project.should_receive(:build)
          @nitpicker.send(:update_and_build, @project).should be_true
        end
        it "should issue an OK message" do
          @project.should_receive(:build)
          @nitpicker.send(:update_and_build, @project, @io)
          @io.rewind
          @io.read.should =~ /Build ok/
        end
      end
      context "when build fails" do
        before do
          @project.should_receive(:build).and_raise Command::CommandError.new
        end
        it "should return false" do
          @nitpicker.send(:update_and_build, @project).should be_false
        end
        it "should issue an error message" do
          @nitpicker.send(:update_and_build, @project, @io)
          @io.rewind
          @io.read.should =~ /Build failed/
        end
      end
    end
  end

  describe '#iterate' do
    before do
      @nitpicker = Nitpicker.new(test_working_path)
      @nitpicker.stub(:sleep)
      @project_1 = get_project('foobar_1')
      @project_2 = get_project('foobar_2')

      @nitpicker.should_receive(:projects).and_return([@project_1, @project_2])
    end
    it "should update and check all project" do
      @nitpicker.should_receive(:update_and_build).with(@project_1, nil)
      @nitpicker.should_receive(:update_and_build).with(@project_2, nil)

      @nitpicker.iterate
    end
    it "should wait after all projects" do
      @nitpicker.should_receive(:sleep).with(Nitpicker::DELAY_BETWEEN_PROJECTS).exactly(2).times
      @nitpicker.iterate
    end
  end

end
