require "#{File.expand_path(File.dirname(__FILE__))}/test_helper"

class ReportingTest < ActiveSupport::TestCase
  class TestReporting < Reporting
    attr_reader :aggregate_calls
    filter :name
    filter :from_date, :type => :date
    filter :to_date,   :type => :date
    filter :in_foo

    select_default   %w(name age)
    group_by_default %w(name)

    column :name,         :type => :string
    column :age,          :type => :number
    column :address,      :type => :string
    column :fullname,     :type => :string, :requires => :name
    column :fullfullname, :type => :string, :requires => :fullname
    column :circle_a,     :requires => :circle_b
    column :circle_b,     :requires => :circle_a

    def initialize(*args)
      #@select = %w(name age)
      @aggregate_calls = 0
      super(*args)
    end

    def aggregate
      @aggregate_calls += 1
      []
    end
  end

  class TestReportingB < Reporting
    column :name_b, :type => :string
    column :age_b,  :type => :number

    select_default %w(name_b)
    group_by_default %w(age_b)
  end

  def setup
    @reporting = TestReporting.new
  end

  test "rows should call aggregate once and only once" do
    @reporting.data
    @reporting.data
    assert_equal 1, @reporting.aggregate_calls
  end

  test "from_params" do
    query = "where name = 'test name' and from_date = '2010-01-01'"
    r = TestReporting.from_params({:tq => query})
    assert_equal "test name", r.name
    assert_equal "2010-01-01".to_date, r.from_date
  end

  test "select default value" do
    r = TestReporting.new
    assert_equal %w(name age), r.select
  end

  test "group by default value" do
    r = TestReporting.new
    assert_equal %w(name), r.group_by
  end

  test "from_params should set select" do
    query = "select name"
    r = TestReporting.from_params({:tq => query})
    assert_equal ['name'], r.select
  end

  test "select should explode a * column" do
    query = "select *"
    r = TestReporting.from_params({:tq => query})
    r.add_virtual_column(:virtual)

    assert_equal %w(name age address fullname fullfullname circle_a circle_b virtual), r.select
  end

  test "from_parmas should set group_by" do
    query = "select name group by name"
    r = TestReporting.from_params({:tq => query})
    assert_equal ['name'], r.group_by
  end

  test "from_params should also take regular get parameters (not the query) into account" do
    params = HashWithIndifferentAccess.new({:tq => '', :test_reporting => {:name => 'John'}})
    r = TestReporting.from_params(params, 'test_reporting')
    assert_equal "John", r.name
  end

  test "from_params should also take regular get parameters into account (with custom param name)" do
    params = HashWithIndifferentAccess.new({:tq => '', :reporting => {:name => 'John'}})
    r = TestReporting.from_params(params, :reporting)
    assert_equal "John", r.name
  end

  test "from_params_with_date_range" do
    query = "where `date` >= '2010-01-01' and `date`<='2010-02-01'"
    r = TestReporting.from_params({:tq => query})
    assert_equal "2010-01-01".to_date, r.from_date
    assert_equal "2010-02-01".to_date, r.to_date
  end

  test "setting datasource columns" do
    assert_equal :string, @reporting.datasource_columns[:name][:type]
    assert_equal :string, TestReporting.datasource_columns[:name][:type]
  end

  test "get column definitions with respect to custom column labels and select" do
    columns = @reporting.columns
    assert_equal 2,       columns.size
    assert_equal 'name',  columns[0][:id]
    assert_equal :string, columns[0][:type]
  end

  test "different subclasses can have different sets of columns" do
    assert TestReporting.datasource_columns != TestReportingB.datasource_columns
  end

  test "different subclasses can have different default selects and groupings" do
    a = TestReporting.new
    b = TestReportingB.new
    assert a.group_by != b.group_by
    assert a.select != b.select
  end

  test "should set limit and offset in from_params" do
    reporting = TestReporting.from_params(:tq => "limit 10 offset 5")
    assert_equal 10, reporting.limit
    assert_equal 5, reporting.offset
  end

  test "should set the order_by attribute in from_params" do
    reporting = TestReporting.from_params(:tq => "order by name")
    assert_equal ['name', :asc], reporting.order_by
  end

  test "should return nil for order by, limit and offset is not set" do
    reporting = TestReporting.new
    assert_nil reporting.order_by
    assert_nil reporting.limit
    assert_nil reporting.offset
  end

  test "parse in( ) statement and put in 'in_xxx' attribute" do
    reporting = TestReporting.from_params(:tq => "where foo in (1, 2)")
    assert_equal %w(1 2), reporting.in_foo
  end

  test "translation of column labels" do
    assert_equal 'AgeReportings', @reporting.column_label(:age)
    assert_equal 'AddressModels', @reporting.column_label(:address)
  end

  test "the rows method should accept a reqired_columns option" do
    @reporting.select   = %w(age)
    @reporting.group_by = []
    assert_equal %w(age), @reporting.required_columns
    @reporting.data(:required_columns => %w(name))
    assert_equal %w(age name), @reporting.required_columns
  end

  test "serialization and deserialization" do
    @reporting.select   = %w(age)
    @reporting.group_by = %w(age)
    @reporting.order_by = %w(name)
    @reporting.limit    = 10
    @reporting.offset   = 20
    @reporting.name     = "John"

    serialized = @reporting.serialize
    reporting = TestReporting.deserialize(serialized)

    assert_equal @reporting.select, reporting.select
    assert_equal @reporting.group_by, reporting.group_by
    assert_equal @reporting.order_by, reporting.order_by
    assert_equal @reporting.limit, reporting.limit
    assert_equal @reporting.offset, reporting.offset
    assert_equal @reporting.name, reporting.name
  end

  test "from_params should recognize a serialized object and deserialize it" do
    @reporting.select   = %w(age)
    @reporting.group_by = %w(age)
    @reporting.name     = "John"
    serialized = @reporting.serialize
    reporting = TestReporting.from_params(@reporting.to_params)

    assert_equal @reporting.select, reporting.select
    assert_equal @reporting.group_by, reporting.group_by
    assert_equal @reporting.name, reporting.name
  end
  
  test 'from_parmas should accept a hash without a module name' do
    reporting = TestReporting.from_params('reporting_test_test_reporting' => { 'select' => %w(age) })
    assert_equal %w(age), reporting.select
  end
  
  test 'to_params should export the hash with a module name by default' do
    assert_equal %w(reporting_test_test_reporting), @reporting.to_params.keys
  end

  test "initialize should handle date string with grace" do
    reporting = TestReporting.new(:from_date => '2010-01-01')
    assert_equal Date.parse('2010-01-01'), reporting.from_date
  end

  test "account for the 'requires' option in column definition" do
    reporting = TestReporting.new
    reporting.select   = %w(fullname)
    reporting.group_by = []
    result = reporting.required_columns
    assert_equal 2, result.size
    assert result.include?('name')
    assert result.include?('fullname')
  end

  test "'requires' option in column definition should work recursivly" do
    reporting = TestReporting.new
    reporting.select   = %w(fullfullname)
    reporting.group_by = []
    result = reporting.required_columns
    assert_equal 3, result.size
    assert result.include?('name')
    assert result.include?('fullname')
    assert result.include?('fullfullname')
  end

  test "recognize circle dependencies in column and throw exception" do
    reporting = TestReporting.new
    reporting.select   = %w(circle_a)
    reporting.group_by = []
    assert_raise CircularDependencyException do
      reporting.required_columns
    end
  end

  test "required_columns should handle virtual columns with grace" do
    reporting = TestReporting.new
    reporting.select = %w(virtual_column name)
    assert_equal %w(virtual_column name), reporting.required_columns
  end

  ################################
  # Test ActiveRecord extension
  ################################

  test "class loads" do
    assert_nothing_raised { Reporting }
  end
  
  test "can add filters" do
    self.class.class_eval %q{
      class CanAddColumns < Reporting
        %w(foo bar test).each { |c| filter c }
      end
    }
    assert_equal 3, CanAddColumns.columns.size
  end
  
  test "type properly set" do
    self.class.class_eval %q{
      class TypeProperlySet < Reporting
        %w(string text date datetime boolean).each do |type|
          filter "a_#{type}".to_sym, :type => type.to_sym
        end
      end
    }
    
    assert TypeProperlySet.columns.size > 0, 'no filters added'
    
    %w(string text date datetime boolean).each do |type|
      assert_equal type, TypeProperlySet.columns_hash["a_#{type}"].sql_type
    end
  end
  
  test "default properly set" do
    self.class.class_eval %q{
      class DefaultPropertlySet < Reporting
        filter :bicycle, :default => 'batavus'
      end
    }
    assert_equal 'batavus', DefaultPropertlySet.new.bicycle
  end
  
  test "columns are humanizable" do
    self.class.class_eval %q{
      class Humanizable < Reporting
        filter :bicycle, :human_name => 'fiets'
      end
    }
    
    assert_equal 'fiets', Humanizable.columns_hash['bicycle'].human_name
  end
  
  test "fail on illegal options" do
    assert_raises ArgumentError do
      self.class.class_eval %q{
        class FailOnIllegalOption < Reporting
          filter :foo, :bar => 'yelp!'
        end
      }
    end
  end
  
  CALLBACKS_CALLED_FOR_VALID = %w(before_validation after_validation before_validation_on_create after_validation_on_create before_save after_save before_create after_create)
  CALLBACKS_NOT_CALLED_FOR_VALID = %w(before_validation_on_update after_validation_on_update)
  CALLBACKS_FOR_VALID = CALLBACKS_CALLED_FOR_VALID + CALLBACKS_NOT_CALLED_FOR_VALID

  test "callbacks called on valid" do
    self.class.class_eval %q{
      class WithCallbackSuccess < Reporting
        CALLBACKS_FOR_VALID.each do |callback|
          attr_accessor "#{callback}_called"
          send(callback){|obj| obj.send("#{callback}_called=", true)}
        end
      end
    }
    
    obj = WithCallbackSuccess.new
    assert obj.save
    CALLBACKS_CALLED_FOR_VALID.each do |callback|
      assert obj.send("#{callback}_called"), "expected #{callback} to be called"
    end
    CALLBACKS_NOT_CALLED_FOR_VALID.each do |callback|
      assert !obj.send("#{callback}_called"), "expected #{callback} not to be called"
    end
  end

  CALLBACKS_CALLED_FOR_INVALID = %w(before_validation before_validation_on_create after_validation after_validation_on_create)
  CALLBACKS_NOT_CALLED_FOR_INVALID = %w(before_validation_on_update after_validation_on_update before_save after_save before_create after_create)
  CALLBACKS_FOR_INVALID = CALLBACKS_CALLED_FOR_INVALID + CALLBACKS_NOT_CALLED_FOR_INVALID

  test "callbacks called on invalid" do
    self.class.class_eval %q{
      class WithCallbackFailure < Reporting
        filter :required
        validates_presence_of :required
        
        CALLBACKS_FOR_INVALID.each do |callback|
          attr_accessor "#{callback}_called"
          send(callback){|obj| obj.send("#{callback}_called=", true)}
        end
      end
    }
    
    obj = WithCallbackFailure.new
    assert !obj.save
    CALLBACKS_CALLED_FOR_INVALID.each do |callback|
      assert obj.send("#{callback}_called"), "expected #{callback} to be called"
    end
    CALLBACKS_NOT_CALLED_FOR_INVALID.each do |callback|
      assert !obj.send("#{callback}_called"), "expected #{callback} not to be called"
    end
  end

  test "create gbang raises no exception on valid" do
    self.class.class_eval %q{
      class CreateBangSuccess < Reporting; end
    }
    
    assert_nothing_raised do
      CreateBangSuccess.create!
    end
  end

  test "create bang raises exception on invalid" do
    self.class.class_eval %q{
      class CreateBangFailure < Reporting
        filter :required_field
        validates_presence_of :required_field
      end
    }
    
    assert_raises ActiveRecord::RecordInvalid do
      CreateBangFailure.create!
    end
  end
end
