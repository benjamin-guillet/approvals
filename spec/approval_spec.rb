require 'spec_helper'

describe Approvals::Approval do
  let(:description) { 'spec/approvals/fairy_dust_and_unicorns' }
  let(:example) { stub('example', :full_description => 'fairy dust ') }

  describe "#normalize" do
    it "downcases" do
      Approvals::Approval.normalize("KTHXBYE").should eq("kthxbye")
    end

    it "replaces spaces with underscores" do
      Approvals::Approval.normalize("the spec").should eq("the_spec")
    end

    it "leaves numbers alone" do
      Approvals::Approval.normalize('a 2009 party').should eq("a_2009_party")
    end

    it "deletes funky characters" do
      Approvals::Approval.normalize('the !@\#$%^&*(){}+| name').should eq("the_name")
    end

    it "collapses spaces before replacing with underscores" do
      Approvals::Approval.normalize('omf             g').should eq('omf_g')
    end

    it "deletes all sorts of spaces" do
      name = <<-FUNKY_NAME

The::Class       \t \r\n \fname
      FUNKY_NAME
      Approvals::Approval.normalize(name).should eq('the_class_name')
    end
  end

  it "knows the approved_path" do
    approval = Approvals::Approval.new(example, 'and unicorns')
    approval.approved_path.should eq("#{description}.approved.txt")
  end

  it "knows the received path" do
    approval = Approvals::Approval.new(example, 'and unicorns')
    approval.received_path.should eq("#{description}.received.txt")
  end

  context "approvals" do
    before :each do
      @approved_file = "#{description}.approved.txt"
      @received_file = "#{description}.received.txt"
    end

    after :each do
      File.delete(@approved_file) if File.exists?(@approved_file)
      File.delete(@received_file) if File.exists?(@received_file)
    end

    describe "on the filesystem" do

      it "writes the approved file if it doesn't exist" do
        File.delete(@approved_file) if File.exists?(@approved_file)

        Approvals::Approval.new(example, 'and unicorns')

        File.exists?(@approved_file).should be_true
        File.read(@approved_file).should eq('')
      end

      it "doesn't overwrite an existing approved file" do
        File.open(@approved_file, 'w') do |f|
          f.write "this doesn't get deleted"
        end

        Approvals::Approval.new(example, 'and unicorns')

        File.exists?(@approved_file).should be_true
        File.read(@approved_file).should eq("this doesn't get deleted")
      end

      it "knows the contents of the approved file" do
        File.open(@approved_file, 'w') do |f|
          f.write "drunk unicorns spew rainbows"
        end

        approval = Approvals::Approval.new(example, 'and unicorns')
        approval.approved.should eq('drunk unicorns spew rainbows')
      end

      it "can return received provided it is set" do
        approval = Approvals::Approval.new(example, 'and unicorns', 'sparkles!')
        approval.received.should eq('sparkles!')
      end

      it "writes the received contents to file" do
        approval = Approvals::Approval.new(example, 'and unicorns', 'oooh, shiney!')

        File.exists?(@received_file).should be_true
        File.read(@received_file).should eq("oooh, shiney!")
      end

      it "cleans up the received file if the approval passes"
    end

    describe "the heart of the matter!" do
      it "recognizes a match as a pass" do
        approval = Approvals::Approval.new(example, 'and unicorns', 'xyz')
        approval.stub(:approved => 'xyz')

        approval.should_not be_failed
      end

      it "recognizes a mismatch as a failure" do
        approval = Approvals::Approval.new(example, 'and unicorns', 'xyz')
        approval.stub(:approved => 'abc')

        approval.should be_failed
      end
    end

    it "fails magnificently" do
      approval = Approvals::Approval.new(example, 'and unicorns', 'xyz')
      message = <<-FAILURE_MESSAGE

        Approval Failure:

        The received contents did not match the approved contents.

        Inspect the differences in the following files:
        #{approval.received_path}
        #{approval.approved_path}

        If you like what you see in the *.received.txt file, you can approve it
        like so:

        mv #{approval.received_path} #{approval.approved_path}


      FAILURE_MESSAGE

      approval.failure_message.should eq(message)
    end
  end
end