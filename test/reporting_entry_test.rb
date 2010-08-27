require "#{File.expand_path(File.dirname(__FILE__))}/test_helper"

class ReportingEntryTest < ActiveSupport::TestCase
  class TestReportingEntry < ReportingEntry
    SUMMABLE_INT_FIELDS_REGEXP    = /int/
    SUMMABLE_FLOAT_FIELDS_REGEXP = /float/
  end

  def setup
  end

  test "OpenStrcut like access" do
    entry = TestReportingEntry.new(:foo => 'bar')
    assert_equal 'bar', entry.foo
  end

  test "NoMethodError when attribute is not set" do
    entry = TestReportingEntry.new()
    assert_raise NoMethodError do
      entry.foo
    end
  end

  test "int values casting" do
    entry = TestReportingEntry.new(:int => "1")
    assert_equal 1, entry.int
    assert entry.int.is_a?(Integer)
  end

  test "float values casting" do
    entry = TestReportingEntry.new(:float => "1.5")
    assert_equal 1.5, entry.float
    assert entry.float.is_a?(Float)
  end

  test "accessors for numeric values should return 0 if the values are not defined" do
    entry = TestReportingEntry.new
    assert_equal 0, entry.int
    assert_equal 0.0, entry.float
  end

  test "the + method should add up all numeric values while merging all others" do
    entry1 = TestReportingEntry.new(:int => 1, :float => 1.5, :foo => 'bar')
    entry2 = TestReportingEntry.new(:int => 2, :float => 2.5, :foo => 'bar')
    sum = entry1 + entry2

    assert_equal 3,     sum.int
    assert_equal 4.0,   sum.float
    assert_equal 'bar', sum.foo
  end
end