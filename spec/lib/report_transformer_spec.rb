require File.expand_path(File.join(File.dirname(__FILE__), *%w[.. spec_helper]))

describe ReportTransformer do
  describe "when given a version 0 report" do
    before do
      report_object = YAML.load_file(Rails.root.join('spec', 'fixtures', 'reports', 'puppet25', '1_changed_0_failures.yml'))
      report_object.extend(ReportExtensions)
      @report = report_object.to_hash
    end

    it "should run the appropriate transformations" do
      ReportTransformer::ZeroToOne.expects(:transform).with(@report)
      ReportTransformer::OneToTwo.expects(:transform).with(@report)
      report = ReportTransformer.apply(@report)
    end
  end

  describe "when given a version 1 report" do
    before do
      report_object = YAML.load_file(Rails.root.join('spec', 'fixtures', 'reports', 'puppet26', 'report_ok_service_started_ok.yaml'))
      report_object.extend(ReportExtensions)
      @report = report_object.to_hash
    end

    it "should run the appropriate transformations" do
      ReportTransformer::ZeroToOne.expects(:transform).with(@report).never
      ReportTransformer::OneToTwo.expects(:transform).with(@report)
      report = ReportTransformer.apply(@report)
    end
  end

  describe "when converting from version 0 to version 1" do
    before do
      @report = {"report_format" => 0, "logs" => []}
    end
    it "should add an empty hash for resource_statuses" do
      report = ReportTransformer::ZeroToOne.apply(@report)
      report["resource_statuses"].should == {}
    end
    it "should add Puppet version to logs whose source is Puppet" do
      @report["logs"] = [{'file'=>nil, 'line'=>nil, 'level'=>:info, 'message'=>'hello', 'source'=>'Puppet', 'tags'=>%w{foo bar}, 'time'=>Time.parse("2011-01-01")}]
      report = ReportTransformer::ZeroToOne.apply(@report)
      report["logs"][0]["version"].should == "0.25.x"
    end
    it "should set version to nil on logs whose source is not Puppet" do
      @report["logs"] = [{'file'=>nil, 'line'=>nil, 'level'=>:info, 'message'=>'hello', 'source'=>'File[/foo]', 'tags'=>%w{foo bar}, 'time'=>Time.parse("2011-01-01")}]
      report = ReportTransformer::ZeroToOne.apply(@report)
      report["logs"][0].keys.should include("version")
      report["logs"][0]["version"].should == nil
    end
    it "should not set version to on logs that already have a version" do
      @report["logs"] = [{'file'=>nil, 'line'=>nil, 'level'=>:info, 'message'=>'hello', 'source'=>'File[/foo]', 'tags'=>%w{foo bar}, 'time'=>Time.parse("2011-01-01"), 'version'=>32768}]
      report = ReportTransformer::ZeroToOne.apply(@report)
      report["logs"][0]["version"].should == 32768
    end
  end

  describe "when converting from version 1 to version 2" do
    before do
      report_object = YAML.load_file(Rails.root.join('spec', 'fixtures', 'reports', 'puppet26', 'report_ok_service_started_ok.yaml'))
      report_object.extend(ReportExtensions)
      @report = report_object.to_hash
    end

    it "should add a total time metric if one doesn't exist" do
      report = ReportTransformer::OneToTwo.apply(@report)
      report["metrics"]["time"]["total"].round(2).should == 1.82
    end

    it "should not add a total time metric if one does exist" do
      @report["metrics"]["time"]["total"] = 12.0
      report = ReportTransformer::OneToTwo.apply(@report)
      report["metrics"]["time"]["total"].round(2).should == 12
    end

    it "should be able to handle a report with no metrics" do
      @report["metrics"] = {}
      report = ReportTransformer::OneToTwo.apply(@report)
      report["metrics"].should == {}
      report["status"].should == "failed"
    end

    it "should set the status to 'failed' if there were failures" do
      @report["metrics"]["resources"]["failed"] = 5
      report = ReportTransformer::OneToTwo.apply(@report)
      @report["status"].should == "failed"
    end

    it "should set the status to 'changed' if there were changes" do
      @report["metrics"]["resources"]["failed"] = 0
      @report["metrics"]["changes"]["total"] = 5
      report = ReportTransformer::OneToTwo.apply(@report)
      @report["status"].should == "changed"
    end

    it "should set the status to 'unchanged' if there were no changes" do
      @report["metrics"]["resources"]["failed"] = 0
      @report["metrics"]["changes"]["total"] = 0
      report = ReportTransformer::OneToTwo.apply(@report)
      @report["status"].should == "unchanged"
    end

    it "should infer configuration version from resource statuses if possible" do
      @report["resource_statuses"].values.each do |resource_status|
        if resource_status["version"] == 1279826342
          resource_status["version"] = 12345
        end
      end
      report = ReportTransformer::OneToTwo.apply(@report)
      @report["configuration_version"].should == '12345'
    end

    it "should infer configuration version from log objects if not possible through resource statuses" do
      @report["resource_statuses"] = {}
      @report["logs"].each do |log|
        if log["version"] == 1279826342
          log["version"] = 12345
        end
      end
      report = ReportTransformer::OneToTwo.apply(@report)
      @report["configuration_version"].should == '12345'
    end

    it "should infer configuration version from log message as a last resort" do
      @report["resource_statuses"] = {}
      @report["logs"].each do |log|
        if log["version"] == 1279826342
          log["version"] = nil
        end
      end
      report = ReportTransformer::OneToTwo.apply(@report)
      @report["configuration_version"].should == '1279826342'
    end
  end
end
