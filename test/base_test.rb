require "#{File.expand_path(File.dirname(__FILE__))}/test_helper"

class TestReporting < Reporting
  column :name, :type => :string
  column :age,  :type => :number

  def aggregate
    @rows = [
      ["John", 20],
      ["Jim", 30]
    ]
  end

  def select
    %w(name age)
  end
end

class BaseTest < ActiveSupport::TestCase
  def setup
    setup_db
    @reporting = TestReporting.new
    @datasource = GoogleDataSource::DataSource::Base.from_params({})
  end

  def teardown
    teardown_db
  end

  test "from_params should parse the tqx parameter" do
    ds = GoogleDataSource::DataSource::Base.from_params({ :tqx => 'reqId:123;out:csv;version:0.5' })
    assert_equal '123', ds[:reqId]
    assert_equal 'csv', ds[:out]
    assert_equal '0.5', ds[:version]
  end

  test "the tqx should be settable via []=" do
    ds = GoogleDataSource::DataSource::Base.from_params({})
    ds[:reqId] = '123'
    assert_equal '123', response_hash(ds)['reqId']
  end

  test "response should include the right reqId" do
    ds = GoogleDataSource::DataSource::Base.from_params({ :tqx => 'reqId:123' })
    response = response_hash(ds)
    assert_equal '123', response['reqId']
  end

  test "from_params should consider the out parameter" do
    ds = GoogleDataSource::DataSource::Base.from_gdata_params({ :out => 'csv' })
    assert ds.is_a?(GoogleDataSource::DataSource::CsvData)
    ds = GoogleDataSource::DataSource::Base.from_gdata_params({ :out => 'html' })
    assert ds.is_a?(GoogleDataSource::DataSource::HtmlData)
    ds = GoogleDataSource::DataSource::Base.from_gdata_params({ :out => 'json' })
    assert ds.is_a?(GoogleDataSource::DataSource::JsonData)
    ds = GoogleDataSource::DataSource::Base.from_gdata_params({ :out => '' })
    assert ds.is_a?(GoogleDataSource::DataSource::InvalidData)
  end

  test "should be invalid if an error is added" do
    ds = GoogleDataSource::DataSource::Base.from_params({})
    assert ds.valid?
    ds.add_error(:foo, 'bar')
    assert !ds.valid?
  end

  test "should be invalid if no reqId is given" do
    ds = GoogleDataSource::DataSource::Base.from_params({:tqx => "out:csv"})
    ds.validate
    assert !ds.valid?
  end

  test "invalidity if version is not supported" do
    ds = GoogleDataSource::DataSource::Base.from_params({:tqx => "reqId:0;version:0.5"})
    ds.validate
    assert !ds.valid?
  end

  test "invalidity if output format is not supported" do
    ds = GoogleDataSource::DataSource::Base.from_params({:tqx => "reqId:0;out:pdf"})
    ds.validate
    assert !ds.valid?
  end

  test "set_raw should set columns and data correctly" do
    ds = GoogleDataSource::DataSource::Base.from_params({})
    columns = [
      GoogleDataSource::DataSource::Column.new(:id => 'A', :label => 'One', :type => 'string'),
      GoogleDataSource::DataSource::Column.new(:id => 'B', :label => 'Two', :type => 'string')
    ]
    columns_hash = [
      { :type => "string", :id => "A", :label => 'One', :pattern => nil },
      { :type => "string", :id => "B", :label => 'Two', :pattern => nil }
    ]
      
    ds.set_raw(columns, test_data)
    assert_equal columns_hash, ds.cols
    assert_equal test_data, ds.data
  end

  test "set_raw should throw an exception for unknown columns types" do
    ds = GoogleDataSource::DataSource::Base.from_params({})
    columns = [GoogleDataSource::DataSource::Column.new(:id => 'A', :label => 'One', :type => 'currency')]
    assert_raise ArgumentError do
      ds.set_raw(columns, test_data)
    end
  end

  test "guess_columns" do
    items = [Item.create(:name => "name", :description => "description", :number => 0)]
    ds = GoogleDataSource::DataSource::Base.from_params({})
    columns = ds.guess_columns(items)

    col_name        = columns.select{|c| c.id == 'name'}.first
    col_description = columns.select{|c| c.id == 'description'}.first
    col_number      = columns.select{|c| c.id == 'number'}.first

    assert !col_name.nil?
    assert !col_description.nil?
    assert !col_number.nil?

    # TODO check types
  end

  test "set" do
    items = [Item.create(:name => "Item Name", :description => "description", :number => 0)]
    ds = GoogleDataSource::DataSource::Base.from_params({})

    columns = [GoogleDataSource::DataSource::Column.new(:id => 'name', :label => 'Name', :type => 'string')]
    ds.set(items, columns) do |item|
      [item.name]
    end

    assert_equal 1, ds.cols.size
    assert_equal 'Name', ds.cols.first[:label]
    assert_equal "Item Name", ds.data.first.first
  end

  test "set should take reporting as argument" do
    assert @datasource.reporting.nil?
    @datasource.set(@reporting)
    assert_equal @datasource.reporting, @reporting
  end

  test "set should set reporting rows correctly" do
    @datasource.set(@reporting)
    assert_equal @datasource.data.first, ["John", 20]
    assert_equal @datasource.data.last, ["Jim", 30]
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
