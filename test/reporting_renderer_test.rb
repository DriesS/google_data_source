require "#{File.expand_path(File.dirname(__FILE__))}/test_helper"

class ReportingRendererTest < ActiveSupport::TestCase
  test "render" do
    class TestController < ActionController::Base
      def test(reporting)
        render :reporting => reporting
      end

      def regular
        render :text => "foo"
      end
    end

    class TestReporting < ::Reporting
    end

    reporting  = TestReporting.new
    controller = TestController.new
    datasource = GoogleDataSource::DataSource::Base.from_params(:reqId => 123)

    # stubs
    controller.stubs(:render_for_text).returns('')
    GoogleDataSource::DataSource::Base.stubs(:from_params).returns(datasource)

    # regular rendering should still work
    controller.expects(:render_without_reporting).with({:text => "foo"})

    # the response of the data source has to be generated
    datasource.expects(:response).returns("")

    controller.test(reporting)
    controller.regular
  end
end
