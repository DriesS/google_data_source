require "#{File.expand_path(File.dirname(__FILE__))}/test_helper"

class CvsDataTest < ActiveSupport::TestCase
  def setup
    setup_db
  end

  def teardown
    teardown_db
  end

  test "csv rendering" do
    items = [Item.create(:name => "Item Name", :description => "description", :number => 0)]
    ds = GoogleDataSource::DataSource::Base.from_params({:tqx => "reqId:0;out:csv"})

    columns = [
      {:id => 'name', :label => 'Name', :type => 'string'},
      {:id => 'number', :label => 'Number', :type => 'number'},
    ]
    ds.set(items, columns)

    result = CSV.parse(ds.response, :col_sep => ';')
    assert_equal [["Name", "Number"], ["Item Name", "0"]], result
  end

  test "number formating" do
    items = [{:int => 1000000, :float => 1000000000.1}]
    ds = GoogleDataSource::DataSource::Base.from_params({:tqx => "reqId:0;out:csv"})
    columns = [
      {:id => 'int', :type => 'number'},
      {:id => 'float', :type => 'number'},
    ]
    ds.set(items, columns)
    #TODO
  end
end
