require "#{File.expand_path(File.dirname(__FILE__))}/test_helper"

class ReportingRendererTest < ActiveSupport::TestCase
  test "render" do
    class TestController < ActionController::Base
      def test(reporting)
        render :reporting => reporting
      end
    end

    class TestReporting < ::Reporting
      def has_form?
        true
      end
    end

    reporting  = TestReporting.new
    controller = TestController.new
    datasource = GoogleDataSource::DataSource::Base.from_params(:reqId => 123)

    # stubs
    controller.stubs(:render_for_text).returns('')
    GoogleDataSource::DataSource::Base.stubs(:from_params).returns(datasource)

    # rendering a reporting with form should trigger the rendering of the form partial
    controller.expects(:render_without_reporting).with({:partial => reporting.partial})

    # the response of the data source has to be generated
    datasource.expects(:response).returns("")

    controller.test(reporting)
  end
end
