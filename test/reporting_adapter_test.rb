require "#{File.expand_path(File.dirname(__FILE__))}/test_helper"

class ReportingAdapterTest < ActiveSupport::TestCase
  setup do
    @adapter = ActiveRecord::ConnectionAdapters::ReportingAdapter.new
  end
  
  test "quote a single quote with a backslash" do
    assert_equal "'foo\\''", @adapter.quote('foo\'')
  end
  
  test "return integers as quoted boolean" do
    assert_equal "'1'", @adapter.quoted_true
    assert_equal "'0'", @adapter.quoted_false
  end
  
  test "quote a backslash with a backslash" do
    assert_equal "'foo\\\\'", @adapter.quote("foo\\")
  end
end