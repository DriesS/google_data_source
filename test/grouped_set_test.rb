require "#{File.expand_path(File.dirname(__FILE__))}/test_helper"

class GroupedSetTest < ActiveSupport::TestCase
  class TestReportingEntry < ReportingEntry
    SUMMABLE_INT_FIELDS_REGEXP   = /^(views|clicks|backfill_views|.*transaction_count)$/
    SUMMABLE_FLOAT_FIELDS_REGEXP = /^(.*_sum|.*_sum_after_share)$/
    NOT_SUMMABLE_FIELDS          = %w(public_website_name)
  end
  
  setup do
    entries = []
    entries << TestReportingEntry.new({:date => Date.today.to_s(:db), :unit_id => "1", :ad_id => "1", :open_sum => "1" })
    entries << TestReportingEntry.new({:date => Date.today.to_s(:db), :unit_id => "2", :ad_id => "1", :open_sum => "2" })
    entries << TestReportingEntry.new({:date => Date.today.to_s(:db), :unit_id => "1", :ad_id => "2", :open_sum => "4" })
    entries << TestReportingEntry.new({:date => Date.today.to_s(:db), :unit_id => "2", :ad_id => "2", :open_sum => "8" })
    entries << TestReportingEntry.new({:date => 1.day.ago.to_s(:db),  :unit_id => "1", :ad_id => "1", :open_sum => "16" })

    @set = GroupedSet.new(entries)
  end

  test "should group by single key" do
    data = @set.regroup(:date)
    assert_equal 2, data.size
    todays_entry = data.select { |e| e.date == Date.today.to_s(:db) }.first
    assert_equal 15.0, todays_entry.open_sum
  end

  test "should group by multiple keys" do
    data = @set.regroup(:date, :ad_id)
    assert_equal 3, data.size
    todays_ad1_entry = data.select { |e| e.date == Date.today.to_s(:db) && e.ad_id == "1"}.first
    assert_equal 3.0, todays_ad1_entry.open_sum
  end

  test "should group by block" do
    data = @set.regroup { |e| e.date }
    assert_equal 2, data.size
    todays_entry = data.select { |e| e.date == Date.today.to_s(:db) }.first
    assert_equal 15.0, todays_entry.open_sum
  end

  test "should collapse" do
    data = @set.collapse
    assert_equal 31.0, data.open_sum
  end
  
  test "something interesting" do
    result = [
              {"campaign_name"=>"Campaign #5", "billing_subject"=>'foo', "campaign_id"=>"8188", "transaction_count"=>"2", "postview_transaction_count"=>"0", "click_transaction_count"=>"0", "sum"=>"45.3000001907349", "status"=>"confirmed", "pricing_association_id"=>"330"}, 
              {"campaign_name"=>"Campaign #6", "billing_subject"=>'blah', "campaign_id"=>"8189", "transaction_count"=>"1", "postview_transaction_count"=>"0", "click_transaction_count"=>"0", "sum"=>"1.10000002384186", "status"=>"confirmed", "pricing_association_id"=>"330"}, 
              {"campaign_name"=>"Campaign #6", "billing_subject"=>'blah', "campaign_id"=>"8189", "transaction_count"=>"1", "postview_transaction_count"=>"0", "click_transaction_count"=>"0", "sum"=>"1.10000002384186", "status"=>"open", "pricing_association_id"=>"330"}, 
              {"campaign_name"=>"Campaign #6", "billing_subject"=>"test", "campaign_id"=>"8189", "transaction_count"=>"1", "postview_transaction_count"=>"0", "click_transaction_count"=>"0", "sum"=>"31337", "status"=>"open", "pricing_association_id"=>"330"}
            ]
    result.collect!{ |re| TestReportingEntry.new(re) }
    result = GroupedSet.new(result)
    result = result.regroup('campaign_id', 'billing_subject')
    assert_equal %w(foo blah test), result.collect(&:billing_subject)
    assert_equal 3, result.size
  end
end
