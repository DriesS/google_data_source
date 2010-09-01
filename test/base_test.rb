require "#{File.expand_path(File.dirname(__FILE__))}/test_helper"

class TestReporting < Reporting
  column :name, :type => :string
  column :age,  :type => :number

  def aggregate
    [
      { :name => "John", :age => 20 },
      { :name => "Jim",  :age => 30 }
    ]
  end

  def select
    %w(name age)
  end
end

class TestAggregator
  attr_reader :columns

  def initialize(data, columns)
    @data = data
    @columns = columns
  end

  def data(options = {})
    @data
  end

  def callback
    "alert('foo');"
  end
end

class BaseTest < ActiveSupport::TestCase
  include GoogleDataSource::DataSource

  def setup
    setup_db
    @reporting = TestReporting.new
    @datasource = Base.from_params({})
  end

  def teardown
    teardown_db
  end

  test "from_params should parse the tqx parameter" do
    datasource = Base.from_params({ :tqx => 'reqId:123;out:csv;version:0.5' })
    assert_equal '123', datasource[:reqId]
    assert_equal 'csv', datasource[:out]
    assert_equal '0.5', datasource[:version]
  end

  test "the tqx should be settable via []=" do
    @datasource[:reqId] = '123'
    assert_equal '123', response_hash(@datasource)['reqId']
  end

  test "response should include the right reqId" do
    datasource = GoogleDataSource::DataSource::Base.from_params({ :tqx => 'reqId:123' })
    response = response_hash(datasource)
    assert_equal '123', response['reqId']
  end

  test "from_params should consider the out parameter" do
    datasource = Base.from_gdata_params({ :out => 'csv' })
    assert datasource.is_a?(CsvData)
    datasource = Base.from_gdata_params({ :out => 'html' })
    assert datasource.is_a?(HtmlData)
    datasource = Base.from_gdata_params({ :out => 'json' })
    assert datasource.is_a?(JsonData)
    datasource = Base.from_gdata_params({ :out => '' })
    assert datasource.is_a?(InvalidData)
  end

  test "should be invalid if an error is added" do
    assert @datasource.valid?
    @datasource.add_error(:foo, 'bar')
    assert !@datasource.valid?
  end

  test "should be invalid if no reqId is given" do
    datasource = Base.from_params({:tqx => "out:csv"})
    datasource.validate
    assert !datasource.valid?
  end

  test "invalidity if version is not supported" do
    datasource = Base.from_params({:tqx => "reqId:0;version:0.5"})
    datasource.validate
    assert !datasource.valid?
  end

  test "invalidity if output format is not supported" do
    datasource = Base.from_params({:tqx => "reqId:0;out:pdf"})
    datasource.validate
    assert !datasource.valid?
  end

  test "guess_columns" do
    items = [Item.create(:name => "name", :description => "description", :number => 0)]
    columns = @datasource.guess_columns(items)

    col_name        = columns.select{|c| c.id == :name}.first
    col_description = columns.select{|c| c.id == :description}.first
    col_number      = columns.select{|c| c.id == :number}.first

    assert !col_name.nil?
    assert !col_description.nil?
    assert !col_number.nil?

    # TODO check types
  end

  test "columns setter should convert hashes to Column objects" do
    @datasource.columns = [
      { :id => 'foo', :type => :string }
    ]
    assert_equal 1, @datasource.columns.size
    assert_kind_of Column, @datasource.columns.first
  end

  test "throw exception on invalid column type" do
    assert_raise ArgumentError do
      @datasource.columns = [
        { :id => 'foo', :type => :bar }
      ]
    end
  end

  test "set with array as data and columns array" do
    @datasource.set(test_data, test_columns)
    raw_data = @datasource.instance_variable_get(:@raw_data)
    assert_equal test_data, raw_data
    assert_equal 2, @datasource.columns.size
    assert_equal :name, @datasource.columns.first.id
    assert_equal :age,  @datasource.columns.last.id
  end

  test "set with an aggregator class" do
    @datasource.set(test_aggregator)

    # check for columns
    assert_equal 2, @datasource.columns.size
    assert_equal :name, @datasource.columns.first.id

    # check for data
    assert_equal "John", @datasource.data.first[0]
    assert_equal 20, @datasource.data.first[1]
  end

  test "simple response" do
    @datasource.set(test_aggregator)
    result = response_hash(@datasource)
    assert_equal '0.6',   result['version']
    assert_equal 2,       result['table']['cols'].size
    assert_equal 'name',  result['table']['cols'].first['id']
    assert_equal 'string',result['table']['cols'].first['type']
    assert_equal 'John',  result['table']['rows'].first['c'].first['v']
  end

  test "formatter" do
    @datasource.set(test_aggregator)
    @datasource.formatter :name do |row|
      "<strong>#{row.name}</strong>"
    end
    data = response_data(@datasource)
    assert_equal "John",                  data.first[0]['v']
    assert_equal "<strong>John</strong>", data.first[0]['f']
  end

  test "formatter should add required columns" do
    aggregator = TestAggregator.new(test_data, [{ :id => :name, :type => :string }])
    @datasource.set(aggregator)
    # should only require name column
    assert_equal 1, @datasource.required_columns.size

    # should also require age column
    @datasource.formatter :name, :age do |row|
      "foo"
    end
    assert_equal 2, @datasource.required_columns.size
    assert @datasource.required_columns.include?('name')
    assert @datasource.required_columns.include?('age')
  end

  test "has_formatter?" do
    assert ! @datasource.has_formatter?(:name)
    @datasource.formatter :name do |row|
      "foo"
    end
    assert @datasource.has_formatter?(:name)
  end

  test "column_ids" do
    @datasource.set(test_aggregator)
    assert_equal %w(name age).collect(&:to_sym), @datasource.column_ids
  end

  test "virtual_column" do
    aggregator = TestAggregator.new(test_data, [{ :id => :summary, :type => :string }])
    @datasource.set(aggregator)
    @datasource.virtual_column :summary do |row|
      "#{row.name} - #{row.age}"
    end

    data = response_data(@datasource)
    assert_equal "John - 20", data[0][0]['v']
    assert_equal "Jim - 30",  data[1][0]['v']
  end

  test "is_virtual_column?" do
    assert ! @datasource.is_virtual_column?(:summary)
    @datasource.virtual_column :summary do |row|
      "foo"
    end
    assert @datasource.is_virtual_column?(:summary)
  end

  test "virtual_column should add required columns if given as option" do
    aggregator = TestAggregator.new(test_data, [{ :id => :name, :type => :string }, { :id => :summary }])
    @datasource.set(aggregator)

    assert_equal 2, @datasource.required_columns.size
    @datasource.virtual_column :summary, :requires => [:age] do |row|
      "foo"
    end
    assert_equal 3, @datasource.required_columns.size
  end

  test "virtual_column should try to inform the aggregator about the column definition, virtual_column first" do
    aggregator = test_aggregator
    aggregator.expects(:add_virtual_column).with(:summary, :string)

    @datasource.virtual_column :summary do |row|
      "#{row.name} - #{row.age}"
    end
    @datasource.set(aggregator)
  end

  test "virtual_column should try to inform the aggregator about the column definition, set first" do
    aggregator = test_aggregator
    aggregator.expects(:add_virtual_column).with(:summary, :string)

    @datasource.set(aggregator)
    @datasource.virtual_column :summary do |row|
      "#{row.name} - #{row.age}"
    end
  end

  test "set column label" do
    @datasource.set(test_aggregator)
    @datasource.column_labels = {
      :name => "Name"
    }
    columns = response_columns(@datasource)
    puts columns.inspect
    assert_equal "Name", columns.first['label']
  end

  def test_data
    [
      { :name => "John", :age => 20},
      { :name => "Jim",  :age => 30}
    ]
  end

  def test_columns
    [
      { :id => :name, :type => :string },
      { :id => 'age', :type => :number}
    ]
  end

  def test_aggregator
    TestAggregator.new(test_data, test_columns)
  end

  def response_hash(datasource)
    json = datasource.response.match(/setResponse\(({.*})\)/)[1]
    ActiveSupport::JSON.decode(json)
  end

  def response_columns(datasource)
    response_hash(datasource)['table']['cols']
  end

  def response_data(datasource)
    response_hash(datasource)['table']['rows'].collect { |r| r['c'] }
  end

end
