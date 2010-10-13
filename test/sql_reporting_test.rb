require "#{File.expand_path(File.dirname(__FILE__))}/test_helper"

class SqlReportingTest < ActiveSupport::TestCase
  class TestReporting < SqlReporting
    attr_reader :aggregate_calls
    filter :name,               :sql => true
    filter :lastname
    filter :got_no_sql_column
    filter :building_no,        :type => :number
    filter :test_integer,       :type => :integer
    filter :boolean_thing,      :type => :boolean, :sql => true

    table :notneeded,                         :join => 'JOIN notneeded'
    table :buildings, :depends => :companies, :join => 'JOIN buildings'
    table :companies,                         :join => 'JOIN companies'

    column :firstname,      :type => :string, :sql => true
    column :lastname,       :type => :string, :sql => { :column => :name }
    column :company_name,   :type => :string, :sql => { :table => :companies, :column => :name }
    column :fullname,       :type => :string
    column :building_no,    :type => :number, :sql => { :table => :buildings, :column => :number }
    column :literal_column, :type => :string, :sql => { :table => :companies, :column => 'literal' }

    column :info,           :type => :string, :requires => :firstname
    column :boolean_thing,  :type => :boolean, :sql => { :table => :companies, :column => :my_boolean }
    
    def initialize(*args)
      @aggregate_calls = 0
      super(*args)
    end

    def aggregate
      @aggregate_calls += 1
      @rows = []
    end
  end

  class TestReportingB < TestReporting
    filter :name_b

  end

  def setup
    @reporting = TestReporting.new
  end
  
  test 'should return an array of bind variables for the query' do
    assert_equal({ :name => 'foo' }, TestReporting.new(:name => 'foo', :lastname => 'bar').sql_bind_variables)
  end
  
  test 'should return an array of sql conditions concatinated by AND' do
    conditions = TestReporting.new(:name => 'foo', :boolean_thing => true).sql_conditions
    assert_equal "(name = 'foo') AND (companies.my_boolean = '1')", conditions
  end
  
  test 'should return a condition for a boolean field' do
    assert_equal "(companies.my_boolean = '1')", @reporting.sql_condition_for(:boolean_thing, true)
    assert_equal "(companies.my_boolean = '0' OR ISNULL(companies.my_boolean))", @reporting.sql_condition_for(:boolean_thing, false)
  end

  test 'should return a condition for a number field' do
    assert_equal "(buildings.number = 1 )", @reporting.sql_condition_for(:building_no, 1)
    assert_equal '(buildings.number = \'1\' )', @reporting.sql_condition_for(:building_no, '1')
    assert_equal '(buildings.number = \'0\' OR ISNULL(buildings.number))', @reporting.sql_condition_for(:building_no, '0')
    assert_equal '(buildings.number = 0 OR ISNULL(buildings.number))', @reporting.sql_condition_for(:building_no, 0)
  end

  test 'should return a condition for an integer field' do
    assert_equal '(test_integer = 0 OR ISNULL(test_integer))', @reporting.sql_condition_for(:test_integer, 0)
  end
  test 'should return a condition for a string field' do
    assert_equal '(name = \'foobar\')', @reporting.sql_condition_for(:lastname, 'foobar')
  end

  test 'should safely handle quotes in escaped value' do
    assert_equal '(name = \'"test"\')', @reporting.sql_condition_for(:lastname, '"test"')
    assert_equal "(name = '\\'test\\'')", @reporting.sql_condition_for(:lastname, "'test'")
  end
  
  test "should return an array with values as IN match" do
    assert_equal "(name IN('test','test2'))", @reporting.sql_condition_for(:lastname, %w(test test2))    
  end
  
  test 'should return a condition even if there is no sql column defined for this filter' do
    assert_equal '(got_no_sql_column = \'foobar\')', @reporting.sql_condition_for(:got_no_sql_column, 'foobar')
  end
  
  test "is_sql_column?" do
    assert @reporting.is_sql_column?(:firstname)
    assert @reporting.is_sql_column?('lastname')
    assert !@reporting.is_sql_column?(:fullname)
  end

  test "sql_column_name" do
    assert !@reporting.sql_column_name(:fullname)
    assert_equal 'firstname', @reporting.sql_column_name(:firstname)
    assert_equal 'firstname', @reporting.sql_column_name(:firstname, :with_alias => true)
    assert_equal 'name', @reporting.sql_column_name(:lastname)
    assert_equal 'companies.name', @reporting.sql_column_name(:company_name)
    assert_equal 'companies.name company_name', @reporting.sql_column_name(:company_name, :with_alias => true)
  end

  test "select should consider mapping" do
    @reporting.select = %w(firstname)
    assert_equal 'christian_name firstname', @reporting.sql_select([], 'firstname' => 'christian_name')
  end

  test "group_by should consider mapping" do
    @reporting.group_by = %w(firstname)
    assert_equal 'christian_name', @reporting.sql_group_by([], 'firstname' => 'christian_name')
  end

  test "select some sql and some ruby columns" do
    reporting = reporting_from_query("select firstname, fullname")
    assert_equal "firstname", reporting.sql_select
  end

  test "use column name mappings in sql_select" do
    reporting = reporting_from_query("select company_name, fullname")
    assert_equal "companies.name company_name", reporting.sql_select
  end

  test "sql_columns" do
    assert @reporting.sql_columns.include?(:firstname)
    assert @reporting.sql_columns.include?(:company_name)
    assert !@reporting.sql_columns.include?(:fullname)
  end

  test "select *" do
    reporting = reporting_from_query("select *")
    sql = reporting.sql_columns.collect { |c| reporting.sql_column_name(c, :with_alias => true) }.join (', ')
    assert_equal sql, reporting.sql_select
  end

  test "sql_group_by" do
    reporting = reporting_from_query("group by firstname, fullname")
    assert_equal "firstname", reporting.sql_group_by
  end

  test "sql_group_by should be nil if no grouping exists" do
    reporting = reporting_from_query("")
    assert_nil reporting.sql_group_by
  end

  test "sql_order_by" do
    reporting = reporting_from_query("order by firstname")
    assert_equal "firstname ASC", reporting.sql_order_by
  end

  test "sql_order_by shoul dconsider mapping" do
    reporting = reporting_from_query("order by firstname")
    assert_equal "name ASC", reporting.sql_order_by('firstname' => 'name')
  end

  test "sql_order_by should return nil if order_by is not set" do
    reporting = reporting_from_query("")
    assert_nil reporting.sql_order_by
  end

  test "use column name mappings in sql_group_by" do
    reporting = reporting_from_query("group by firstname, lastname, fullname")
    assert_equal "firstname, name", reporting.sql_group_by
  end

  test "get joins for columns" do
    assert_equal "", @reporting.sql_joins(%w(firstname))
    assert_equal "JOIN companies", @reporting.sql_joins(%w(company_name))
  end

  test "get joins resolving dependencies" do
    assert_equal "JOIN companies JOIN buildings", @reporting.sql_joins(%w(building_no company_name))
  end

  test "columns method should return plain columns without sql option" do
    reporting = reporting_from_query("select *")
    reporting.columns.each do |column|
      assert !column.has_key?(:sql)
    end
  end

  test "join according to the used columns" do
    reporting = reporting_from_query("select firstname")
    assert_equal "", reporting.sql_joins

    reporting = reporting_from_query("select company_name")
    reporting.sql_select
    assert_equal "JOIN companies", reporting.sql_joins
  end

  test "join if columns are added with mark_as_used" do
    reporting = reporting_from_query("select firstname")
    assert_equal "", reporting.sql_joins
    reporting.mark_as_used('company_name')
    assert_equal "JOIN companies", reporting.sql_joins
  end

  test "include required columns in sql_select statement" do
    reporting = reporting_from_query("select firstname")
    reporting.add_required_columns :company_name
    select = reporting.sql_select.split(', ')
    assert_equal 2, select.size
    assert select.include?('firstname')
    assert select.include?('companies.name company_name')
  end

  test "account for columns that require other columns" do
    reporting = reporting_from_query("select info")
    select = reporting.sql_select.split(', ')
    assert_equal 1, select.size
    assert_equal 'firstname', select.first
  end

  test "include joins for required columns" do
    reporting = reporting_from_query("select firstname")
    reporting.add_required_columns :company_name
    assert_equal "JOIN companies", reporting.sql_joins
  end

  test "sql_group_by should recognize the mapping if it's the first parameter" do
    @reporting.group_by = %w(firstname)
    assert_equal "christian_name", @reporting.sql_group_by('firstname' => 'christian_name')
  end

  test "should not append table name if column name is give as string" do
    assert_equal 'literal', @reporting.sql_column_name(:literal_column)
  end

  test "subclasses should inherit sql_tables" do
    reporting = TestReportingB.new
    assert_equal 3, reporting.sql_tables.count
  end

  def reporting_from_query(query)
    TestReporting.from_params({:tq => query})
  end
end
