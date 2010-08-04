require "#{File.expand_path(File.dirname(__FILE__))}/test_helper"

class ReportingTest < ActiveSupport::TestCase
  class TestReporting < Reporting
    attr_reader :aggregate_calls

    def initialize
      @aggregate_calls = 0
    end

    def aggregate
      @aggregate_calls += 1
      # set data and columns so aggregate is only called once
      @data = []
      @columns = []
    end
  end

  test "columns" do
    r = TestReporting.new
    r.columns
    r.data
    assert_equal 1, r.aggregate_calls
  end

  test "partial" do
    r = TestReporting.new
    assert_equal "test_reporting_form.html", r.partial
  end

  test "form_id" do
    r = TestReporting.new
    assert_equal "test_reporting_form", r.form_id
  end
end
