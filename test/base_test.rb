require 'test/unit'
require 'rubygems'
require 'active_support'
require 'active_support/test_case'
require 'action_controller'
require 'active_record'
require "#{File.expand_path(File.dirname(__FILE__))}/../init"

# Setup Database and Models
ActiveRecord::Base.establish_connection(
  :adapter => "sqlite3",
  :database => ":memory:"
)

def setup_db
  ActiveRecord::Schema.define do
    create_table "items", :force => true do |t|
      t.column "name", :string
      t.column "description", :text
      t.column "number", :integer
    end
  end
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end

class Item < ActiveRecord::Base; end

#Fixtures.create_fixtures('test/fixtures/', ActiveRecord::Base.connection.tables)

class BaseTest < ActiveSupport::TestCase
  def setup
    setup_db
  end

  def teardown
    teardown_db
  end

  test "from_params should parse the tqx parameter" do
    ds = GoogleDataSource::Base.from_params({ :tqx => 'reqId:123;out:csv;version:0.5' })
    assert_equal '123', ds[:reqId]
    assert_equal 'csv', ds[:out]
    assert_equal '0.5', ds[:version]
  end

  test "the tqx should be settable via []=" do
    ds = GoogleDataSource::Base.from_params({})
    ds[:reqId] = '123'
    assert_equal '123', response_hash(ds)['reqId']
  end

  test "response should include the right reqId" do
    ds = GoogleDataSource::Base.from_params({ :tqx => 'reqId:123' })
    response = response_hash(ds)
    assert_equal '123', response['reqId']
  end

  test "from_params should consider the out parameter" do
    ds = GoogleDataSource::Base.from_gdata_params({ :out => 'csv' })
    assert ds.is_a?(GoogleDataSource::CsvData)
    ds = GoogleDataSource::Base.from_gdata_params({ :out => 'html' })
    assert ds.is_a?(GoogleDataSource::HtmlData)
    ds = GoogleDataSource::Base.from_gdata_params({ :out => 'json' })
    assert ds.is_a?(GoogleDataSource::JsonData)
    ds = GoogleDataSource::Base.from_gdata_params({ :out => '' })
    assert ds.is_a?(GoogleDataSource::InvalidData)
  end

  test "should be invalid if an error is added" do
    ds = GoogleDataSource::Base.from_params({})
    assert ds.valid?
    ds.add_error(:foo, 'bar')
    assert !ds.valid?
  end

  test "should be invalid if no reqId is given" do
    ds = GoogleDataSource::Base.from_params({:tqx => "out:csv"})
    ds.validate
    assert !ds.valid?
  end

  test "invalidity if version is not supported" do
    ds = GoogleDataSource::Base.from_params({:tqx => "reqId:0;version:0.5"})
    ds.validate
    assert !ds.valid?
  end

  test "invalidity if output format is not supported" do
    ds = GoogleDataSource::Base.from_params({:tqx => "reqId:0;out:pdf"})
    ds.validate
    assert !ds.valid?
  end

  test "set should set columns and data correctly" do
    ds = GoogleDataSource::Base.from_params({})
    columns = [
      GoogleDataSource::Column.new(:id => 'A', :label => 'One', :type => 'string'),
      GoogleDataSource::Column.new(:id => 'B', :label => 'Two', :type => 'string')
    ]
    columns_hash = [
      { :type => "string", :id => "A", :label => 'One', :pattern => nil },
      { :type => "string", :id => "B", :label => 'Two', :pattern => nil }
    ]
      
    ds.set(columns, test_data)
    assert_equal columns_hash, ds.cols
    assert_equal test_data, ds.data
  end

  test "set should throw an exception for unknown columns types" do
    ds = GoogleDataSource::Base.from_params({})
    columns = [GoogleDataSource::Column.new(:id => 'A', :label => 'One', :type => 'currency')]
    assert_raise ArgumentError do
      ds.set(columns, test_data)
    end
  end

  test "guess_columns" do
    items = [Item.create(:name => "name", :description => "description", :number => 0)]
    ds = GoogleDataSource::Base.from_params({})
    columns = ds.guess_columns(items)
    puts columns.inspect

    col_name        = columns.select{|c| c.id == 'name'}.first
    col_description = columns.select{|c| c.id == 'description'}.first
    col_number      = columns.select{|c| c.id == 'number'}.first

    assert !col_name.nil?
    assert !col_description.nil?
    assert !col_number.nil?

    # TODO check types
  end

  test "smart_set" do
    items = [Item.create(:name => "Item Name", :description => "description", :number => 0)]
    ds = GoogleDataSource::Base.from_params({})

    columns = [GoogleDataSource::Column.new(:id => 'name', :label => 'Name', :type => 'string')]
    ds.smart_set(items, columns) do |item|
      [item.name]
    end

    assert_equal 1, ds.cols.size
    assert_equal 'Name', ds.cols.first[:label]
    assert_equal "Item Name", ds.data.first.first
  end

  def test_data
    [
      ['00', '01'],
      ['10', '11']
    ]
  end

  def response_hash(datasource)
    json = datasource.response.match(/setResponse\(({.*})\)/)[1]
    ActiveSupport::JSON.decode(json)
  end

end
