# The majority of The Supplejack Manager code is Crown copyright (C) 2014, New Zealand Government,
# and is licensed under the GNU General Public License, version 3. Some components are 
# third party components that are licensed under the MIT license or otherwise publicly available. 
# See https://github.com/DigitalNZ/supplejack_manager for details. 
# 
# Supplejack was created by DigitalNZ at the National Library of NZ and the Department of Internal Affairs. 
# http://digitalnz.org/supplejack

require "spec_helper"

describe HarvestJob do

  let(:user) { mock_model(User, id: "333").as_null_object }
  let(:job) { HarvestJob.new(user_id: "1234567", parser_id: "7654321") }

  describe ".from_parser" do
    let(:parser) { mock(:parser, id: "1234") }

    it "initializes a new HarvestJob" do
      job = HarvestJob.from_parser(parser)
      job.parser_id.should eq "1234"
    end

    it "sets the user_id" do
      job = HarvestJob.from_parser(parser, user)
      job.user_id.should eq "333"
    end
  end

  describe ".build" do
    it "initializes a new HarvestJob with default attributes" do
      job = HarvestJob.build
      [:parser_id, :limit, :user_id, :version_id, :environment].each do |attribute|
        job.send(attribute).should be_nil
      end
    end

    it "overrides the attributes passed" do
      job = HarvestJob.build(parser_id: "12345")
      job.parser_id.should eq "12345"
    end
  end

  describe ".search" do
    let(:jobs) { [job] }

    before(:each) do
      HarvestJob.stub(:find) { jobs }
      jobs.stub(:http) { {} }
    end

    context "environment defined" do
      it "finds all active harvest jobs" do
        HarvestJob.should_receive(:find).with(:all, params: {status: "active", page: 1, environment: ["staging", "production"]})
        HarvestJob.search.should eq jobs
      end

      it "finds all finished harvest jobs" do
        HarvestJob.should_receive(:find).with(:all, params: {status: "finished", page: 1, environment: ["staging", "production"]})
        HarvestJob.search("status" => "finished")
      end

      it "paginates through the records" do
        HarvestJob.should_receive(:find).with(:all, params: {status: "finished", page: "2", environment: ["staging", "production"]})
        HarvestJob.search("status" => "finished", "page" => "2")
      end

      it "does not change the workers site and key" do
        HarvestJob.should_not_receive(:change_worker_env!)
        HarvestJob.search("status" => "finished", "page" => "2")
      end
    end

    it "changes the HarvestJob's site and key to the staging site and key" do
       HarvestJob.should_receive(:change_worker_env!).with('staging')
       HarvestJob.search({"status" => "finished", "page" => "2"}, 'staging')
    end

    it "finds parser if provided" do
      HarvestJob.should_receive(:find).with(:all, params: {status: "finished", page: "2", environment: ["staging", "production"], parser_id: "123"})
      HarvestJob.search({"status" => "finished", "page" => "2", "parser" => "123"}, 'staging')
    end
  end

  describe ".change_worker_env!" do
    it "should change the site and key for a given class" do
      Figaro.should_receive(:env).with('staging') { {"WORKER_HOST" => "http://host.work", "WORKER_API_KEY" => "abc123"} }
      HarvestJob.change_worker_env!('staging')
      HarvestJob.site.should eq URI("http://host.work")
      HarvestJob.user.should eq "abc123"
    end
  end

  describe "#user" do
    it "finds the user based on the user_id" do
      User.should_receive(:find).with("1234567")
      job.user
    end

    it "returns nil when not found" do
      job.user.should be_nil
    end

    it "returns nil when no user_id is present" do
      job = HarvestJob.new
      job.user.should be_nil
    end
  end

  describe "#parser" do
    it "finds the parser based on the parser_id" do
      Parser.should_receive(:find).with("7654321")
      job.parser
    end

    it "returns nil when not found" do
      job.parser.should be_nil
    end

    it "returns nil when no parser_id is present" do
      job = HarvestJob.new
      job.parser.should be_nil
    end
  end

  describe "#finished?" do
    it "returns true" do
      job.status = "finished"
      job.finished?.should be_true
    end

    it "returns false" do
      job.status = "active"
      job.finished?.should be_false
    end
  end

  describe "#total_errors_count" do
    it "should add the failed, harvest errors and invalid record counts" do
      job.stub(:failed_records_count) { 5 }
      job.stub(:invalid_records_count) { 3 }
      job.stub(:harvest_errors_count) { 2 }
      job.total_errors_count.should eq 10
    end
  end

end
