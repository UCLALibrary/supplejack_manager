require "spec_helper"

describe Previewer do

  let(:parser) { Parser.new(name: "Europeana", strategy: "json", content: "class Europeana < HarvesterCore::Json::Base; end") }
  let(:previewer) { Previewer.new(parser, "Data") }
  let(:record) { mock(:record, field_errors: {}, errors: {}).as_null_object }

  before do
    class Europeana < HarvesterCore::Json::Base; end
  end

  describe "#initialize" do
    it "updates the parser content" do
      previewer.parser.content.should eq "Data"
    end

    it "initializes a ParserLoader" do
      previewer.loader.should be_a(HarvesterCore::Loader)
    end
  end

  describe "#fetch_record" do
    let(:job) { mock(:harvest_job).as_null_object }

    context "fetch record from a existing harvest" do
      let(:previewer) { Previewer.new(parser, "Data", 2, "staging", true) }
      let(:invalid_record) { mock(:record, raw_data: "</xml>") }

      before do
        HarvestJob.stub(:search) { [job] }
        job.stub(:invalid_records) { [1,2, invalid_record] }
        Europeana.stub(:new) { record }
      end

      it "should search for the latest Job" do
        HarvestJob.should_receive(:search).with(parser_id: parser.id, environment: "staging", status: "finished", limit: 1) { [job] }
        previewer.fetch_record(Europeana)
      end

      it "should initialize a new record with the raw_data from the database" do
        Europeana.should_receive(:new).with("</xml>", true) { record }
        previewer.fetch_record(Europeana)
      end

      it "should set the attribute values and return the record" do
        record.should_receive(:set_attribute_values)
        previewer.fetch_record(Europeana).should eq record
      end

      it "returns nil when a HarvestJob is not found" do
        HarvestJob.stub(:search) { [] }
        previewer.fetch_record(Europeana).should be_nil
      end
    end

    context "fetch live record" do
      let(:previewer) { Previewer.new(parser, "Data", 2, "staging", nil) }

      it "should fetch the live record" do
        Europeana.should_receive(:records).with(limit: 3) { [1, 2, record] }
        previewer.fetch_record(Europeana).should eq record
      end
    end
  end

  describe "load_record" do
    before(:each) do
      parser.load_file
      Europeana.stub(:records) { [record] }
    end

    it "loads one record" do
      Europeana.should_receive(:records).with({limit: 1}) { [record] }
      previewer.load_record.should eq record
    end

    it "rescues from any error" do
      Europeana.stub(:records).and_raise(StandardError.new("Hi"))
      previewer.load_record.should be_nil
      previewer.fetch_error.should eq "Hi"
    end

    it "returns the third record" do
      previewer = Previewer.new(parser, "Data", 2)
      record3 = mock(:record, id: 3)
      Europeana.stub(:records) { [record, record, record3] }
      previewer.load_record.should eq record3
    end
  end

  describe "#record" do
    let(:loader) { previewer.loader }

    before do
      parser.load_file
      Europeana.stub(:records) { [record] }
    end

    it "loads the parser file" do
      loader.should_receive(:loaded?)
      previewer.record
    end

    it "returns the first record" do
      previewer.stub(:load_record) { record }
      previewer.record.should eq record
    end
  end

  describe "#record?" do
    before do
      parser.load_file
      Europeana.stub(:records) { [] }
    end

    it "returns false" do
      previewer.record?.should be_false
    end

    it "returns true" do
      loader = mock(:loader, loaded?: true, load_error: "Error", parser_class: Europeana)
      previewer.stub(:loader) { loader }
      Europeana.stub(:records) { [record] }
      previewer.record?.should be_true
    end

    it "sets the syntax error" do
      loader = mock(:loader, loaded?: false, load_error: "Error")
      previewer.stub(:loader) { loader }
      previewer.record?.should be_false
      previewer.load_error.should eq "Error"
    end
  end

  describe "#test?" do
    it "should return true" do
      previewer.environment = "test"
      previewer.test?.should be_true
    end

    it "should return false" do
      previewer.environment = "staging"
      previewer.test?.should be_false
    end
  end

  describe "document?" do
    let(:document) { mock(:document).as_null_object }
    let(:record) { mock(:record, document: document) }

    before(:each) do
      previewer.stub(:record) { record }
    end

    it "returns true when document is retrieved correctly" do
      record.stub(:document) { document }
      previewer.document?.should be_true
    end

    it "returns false when document raises an error" do
      record.stub(:document).and_raise(StandardError.new("Error!"))
      previewer.document?.should be_false
      previewer.document_error.should eq "Error!"
    end
  end

  describe "#attributes_json" do
    let(:record) { mock(:record, attributes: {title: "Json!"}).as_null_object }

    it "returns the json in a pretty format" do
      previewer.stub(:record) { record }
      previewer.attributes_json.should eq JSON.pretty_generate({title: "Json!"})
    end
  end

  describe "#attributes_output" do
    let(:attributes_json) { JSON.pretty_generate({title: "Json!"}) }

    before do
      previewer.stub(:attributes_json) { attributes_json }
    end

    it "returns highlighted json" do
      output = %q{{\n  <span class=\"key\"><span class=\"delimiter\">&quot;</span><span class=\"content\">title</span><span class=\"delimiter\">&quot;</span></span>: <span class=\"string\"><span class=\"delimiter\">&quot;</span><span class=\"content\">Json!</span><span class=\"delimiter\">&quot;</span></span>\n}}
      previewer.attributes_output.should match(output)
    end
  end

  describe "#field_errors_json" do
    let(:record) { mock(:record, field_errors: {title: "Invalid!"}) }

    before do
      previewer.stub(:record) { record }
    end

    it "returns the json in a pretty format" do
      previewer.field_errors_json.should eq JSON.pretty_generate({title: "Invalid!"})
    end

    it "returns nil when there are no field_errors" do
      record.stub(:field_errors) { {} }
      previewer.field_errors_json.should be_nil
    end
  end

  describe "#field_errors_output" do
    let(:field_errors_json) { JSON.pretty_generate({title: "Invalid!"}) }

    before do
      previewer.stub(:field_errors?) { true }
      previewer.stub(:field_errors_json) { field_errors_json }
    end

    it "returns highlighted json" do
      output = %q{{\n  <span class=\"key\"><span class=\"delimiter\">&quot;</span><span class=\"content\">title</span><span class=\"delimiter\">&quot;</span></span>: <span class=\"string\"><span class=\"delimiter\">&quot;</span><span class=\"content\">Invalid!</span><span class=\"delimiter\">&quot;</span></span>\n}}
      previewer.field_errors_output.should match(output)
    end

    it "returns nil when there are no field_errors" do
      previewer.stub(:field_errors?) { false }
      previewer.field_errors_output.should be_nil
    end
  end

  describe "#field_errors?" do
    before { previewer.stub(:record) { record } }

    it "returns false when there are no field_errors" do
      previewer.field_errors?.should be_false
    end

    it "returns true when there are field_errors" do
      record.stub(:field_errors) { {title: "Invalid"} }
      previewer.field_errors?.should be_true
    end
  end

  describe "#validation_errors?" do

    before { previewer.stub(:record) { record } }

    it "returns false when there are no validation_errors" do
      previewer.validation_errors?.should be_false
    end

    it "returns true when there are validation_errors" do
      record.stub(:errors) { {title: "Invalid"} }
      previewer.validation_errors?.should be_true
    end
  end


end
