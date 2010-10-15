require "#{File.expand_path(File.dirname(__FILE__))}/test_helper"

class ReportingEntryTest < ActiveSupport::TestCase
  class TestReportingEntry < ReportingEntry
    SUMMABLE_INT_FIELDS_REGEXP    = /int|another_value/
    SUMMABLE_FLOAT_FIELDS_REGEXP  = /float/
    NOT_SUMMABLE_FIELDS           = %w(hide_me)

    def reduced
      int - 1
    end

    def another_value
      return 1
    end
    
    def hide_me
      "I'm not shown in sum entry"
    end
    
    def show_me
      "I'm shown!"
    end
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

  test "the composite entry should also support a working + method" do
    entry1 = TestReportingEntry.new(:int => 1, :float => 1.5, :foo => 'bar')
    entry2 = TestReportingEntry.new(:int => 2, :float => 2.5, :foo => 'bar')
    entry3 = TestReportingEntry.new(:int => 3, :float => 3.5, :foo => 'bar')
    sum = entry1 + entry2 + entry3

    assert_equal 6, sum.int
    assert_equal 7.5, sum.float
  end

  test "virtual attributes should also work an composite entries" do
    entry1 = TestReportingEntry.new(:int => 1, :float => 1.5, :foo => 'bar')
    entry2 = TestReportingEntry.new(:int => 2, :float => 2.5, :foo => 'bar')

    assert_equal 0, entry1.reduced
    sum = entry1 + entry2
    assert_equal 2, sum.reduced
  end

  test "to_sum_entry should only set numerical values and strip all others" do
    entry = TestReportingEntry.new(:int => 1, :float => 1.5, :foo => 'bar')
    sum_entry = entry.to_sum_entry

    assert_nil sum_entry.foo
    assert_equal 1, sum_entry.int
    assert_equal 1.5, sum_entry.float
  end

  test "to_sum_entry on composite entries" do
    entry1 = TestReportingEntry.new(:int => 1, :float => 1.5, :foo => 'bar')
    entry2 = TestReportingEntry.new(:int => 2, :float => 2.5, :foo => 'bar')
    sum = (entry1 + entry2).to_sum_entry

    assert_nil sum.foo
    assert_equal 3, sum.int
  end
  
  test 'to_sum_entry should not return any explicitely hidden ruby columns' do
    entry1 = TestReportingEntry.new(:int => 1, :float => 1.5, :foo => 'bar')
    entry2 = TestReportingEntry.new(:int => 1, :float => 1.5, :foo => 'bar')
    assert_equal nil, (entry1 + entry2).to_sum_entry.hide_me
  end

  test 'to_sum_entry should return all ruby columns in sum entry by default' do
    entry1 = TestReportingEntry.new(:int => 1, :float => 1.5, :foo => 'bar')
    entry2 = TestReportingEntry.new(:int => 1, :float => 1.5, :foo => 'bar')
    assert_equal "I'm shown!", (entry1 + entry2).to_sum_entry.show_me
  end

  test "handle summable virtual attributes correclty" do
    entry1 = TestReportingEntry.new()
    entry2 = TestReportingEntry.new()
    sum = entry1 + entry2

    assert_equal 1, entry1.another_value
    assert_equal 2, sum.another_value
  end
  
  test "be able to group by billing_subject" do
    result = [
              {"campaign_name"=>"Campaign #5", "billing_subject"=>'foo', "campaign_id"=>"8188", "transaction_count"=>"2", "postview_transaction_count"=>"0", "click_transaction_count"=>"0", "sum"=>"45.3000001907349", "status"=>"confirmed", "pricing_association_id"=>"330"}, 
              {"campaign_name"=>"Campaign #6", "billing_subject"=>'blah', "campaign_id"=>"8189", "transaction_count"=>"1", "postview_transaction_count"=>"0", "click_transaction_count"=>"0", "sum"=>"1.10000002384186", "status"=>"confirmed", "pricing_association_id"=>"330"}, 
              {"campaign_name"=>"Campaign #6", "billing_subject"=>'blah', "campaign_id"=>"8189", "transaction_count"=>"1", "postview_transaction_count"=>"0", "click_transaction_count"=>"0", "sum"=>"1.10000002384186", "status"=>"open", "pricing_association_id"=>"330"}, 
              {"campaign_name"=>"Campaign #6", "billing_subject"=>"test", "campaign_id"=>"8189", "transaction_count"=>"1", "postview_transaction_count"=>"0", "click_transaction_count"=>"0", "sum"=>"31337", "status"=>"open", "pricing_association_id"=>"330"}
            ]
    result.collect!{ |re| ReportingEntry.new(re) }
    result = result.group_by { |entry| "#{entry.send(:billing_subject)}" }.values
    assert_equal 3, result.size
    
    result = result.collect do |entries|
      # Uses the class of the first element to build the composite element
      entries.first.class.composite(entries)
    end
    
    assert_equal %w(foo blah test), result.collect(&:billing_subject)
  end
  
  test "virtual attributes " do
    assert true
  end
end
