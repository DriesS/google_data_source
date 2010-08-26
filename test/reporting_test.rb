require "#{File.expand_path(File.dirname(__FILE__))}/test_helper"

class ReportingTest < ActiveSupport::TestCase
  class TestReporting < Reporting
    attr_reader :aggregate_calls
    filter :name
    filter :from_date, :type => :date
    filter :to_date,   :type => :date

    select_default   %w(name age)
    group_by_default %w(name)

    column :name,      :type => :string
    column :age,       :type => :number
    column :address,   :type => :string

    def initialize(*args)
      #@select = %w(name age)
      @aggregate_calls = 0
      super(*args)
    end

    def aggregate
      @aggregate_calls += 1
      @rows = []
    end
  end

  class TestReportingB < Reporting
    column :name_b, :type => :string
    column :age_b,  :type => :number

    select_default %w(name_b)
    group_by_default %w(age_b)
  end

  class TestFormReporting < Reporting
    has_form :partial => "partial.html"
  end

  class TestNoFormReporting < Reporting
  end

  def setup
    @reporting = TestReporting.new
  end

  test "rows should call aggregate once and only once" do
    @reporting.rows
    @reporting.rows
    assert_equal 1, @reporting.aggregate_calls
  end

  test "partial" do
    assert_equal "test_reporting_form.html", @reporting.partial
  end

  test "form_id" do
    assert_equal "test_reporting_form", @reporting.form_id
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

  #test "overriding default values an instance level" do
  #  r = TestReporting.new
  #  r.instance_variable_set(:@defaults, {:select => []})
  #  assert_equal %w(), r.select
  #end

  test "from_params should set select" do
    query = "select name"
    r = TestReporting.from_params({:tq => query})
    assert_equal ['name'], r.select
  end

  test "select should explode a * column" do
    query = "select *"
    r = TestReporting.from_params({:tq => query})
    r.virtual_column(:virtual) { |row| "" }
    assert_equal %w(name age address virtual), r.select
  end

  test "from_parmas should set group_by" do
    query = "select name group by name"
    r = TestReporting.from_params({:tq => query})
    assert_equal ['name'], r.group_by
  end

  test "from_params should also take regular get parameters (not the query) into account" do
    params = HashWithIndifferentAccess.new({:tq => '', :test_reporting => {:name => 'John'}})
    r = TestReporting.from_params(params)
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
    @reporting.column_labels = {
      :name => "Nom"
    }
    columns = @reporting.columns
    assert_equal 2,       columns.size
    assert_equal 'name',  columns[0][:id]
    assert_equal :string, columns[0][:type]
    assert_equal 'Nom',   columns[0][:label]
    assert_equal 'Age',   columns[1][:label]
  end

  test "columns method should strip all data, that does not belong in the datasource (virtual column proc)" do
    @reporting.virtual_column(:virtual) { |row| '' }
    @reporting.select = ['virtual']
    assert !@reporting.columns.first.has_key?('proc')
  end

  test "add data" do
    assert_equal [], @reporting.rows
    @reporting.add_row({ :name => 'John', :age => 30, :address => 'Samplestreet 11'})
    assert_equal      1, @reporting.rows.size
    assert_equal      2, @reporting.rows.first.size
    assert_equal 'John', @reporting.rows.first[0]
    assert_equal     30, @reporting.rows.first[1]
  end

  test "add row should accept OpenStruct like objects" do
    @reporting.add_row(OpenStruct.new(:name => 'John', :age => 30, :address => 'Samplestreet 11'))
    assert_equal      1, @reporting.rows.size
    assert_equal      2, @reporting.rows.first.size
    assert_equal 'John', @reporting.rows.first[0]
    assert_equal     30, @reporting.rows.first[1]
  end

  test "use formatter when adding data" do
    @reporting.formatters[:name] = Proc.new do |name|
      "<strong>#{name}</strong>"
    end
    @reporting.add_row({ :name => 'John', :age => 30, :address => 'Samplestreet 11'})
    assert @reporting.rows.first[0].has_key?(:f)
    assert @reporting.rows.first[0].has_key?(:v)
    assert_equal "<strong>John</strong>", @reporting.rows.first[0][:f]
  end

  test "setting formatter with formatter convenience method" do
    @reporting.formatter(:name) do |name|
      "<strong>#{name}</strong>"
    end
    @reporting.add_row({ :name => 'John', :age => 30, :address => 'Samplestreet 11'})
    assert_equal "<strong>John</strong>", @reporting.rows.first[0][:f]
  end

  test "the formatter should be called by add_row with the required columns" do
    @reporting.formatter(:name, :age) do |name, age|
      "#{name} = #{age}"
    end
    @reporting.add_row({ :name => 'John', :age => 30, :address => 'Samplestreet 11'})
    assert_equal "John = 30", @reporting.rows.first[0][:f]
  end

  test "has_virtual_column?" do
    assert !@reporting.is_virtual_column?(:summary)
    @reporting.virtual_column :summary do |row|
      "#{row[:name]} - #{row[:age]}"
    end
    assert @reporting.is_virtual_column?(:summary)
  end

  test "virtual column rendering" do
    @reporting.virtual_column :summary do |row|
      "#{row[:name]} - #{row[:age]}"
    end
    @reporting.select = %w(summary)
    @reporting.add_row({ :name => 'John', :age => 30, :address => 'Samplestreet 11'})

    assert_equal 'John - 30', @reporting.rows.first.first
  end

  test "column setup for virtual columns" do
    @reporting.virtual_column :summary do |row|
      "#{row[:name]} - #{row[:age]}"
    end
    @reporting.select = %w(summary)
    assert_equal 1, @reporting.columns.size
  end

  test "should consider type option when adding a virtual_column" do
    @reporting.virtual_column :one, :type => :number do |row|
      1
    end
    assert_equal :number, @reporting.virtual_columns[:one][:type]
  end

  test "should add columns to required_columns if option is give in virtual_column" do
    @reporting.virtual_column :one, :requires => [:age] { |row| 1 }
    assert @reporting.required_columns.include?('age')
  end

  test "should add columns to required_columns if option is give in formatter" do
    @reporting.formatter(:age, :name) { |row| 1 }
    @reporting.select = %w(age)
    @reporting.group_by = []
    assert_equal 2, @reporting.required_columns.size
    assert @reporting.required_columns.include?('name')
    assert @reporting.required_columns.include?('age')
  end

  test "only include required column if dependent column is selected" do
    @reporting.formatter :age, :requires => [:name] { |row| 1 }
    @reporting.select   = %w(address)
    @reporting.group_by = []
    assert !@reporting.required_columns.include?('name')
    assert !@reporting.required_columns.include?('age')
  end

  test "has_form class method" do
    reporting = TestFormReporting.new
    assert reporting.has_form?
    assert_equal 'partial.html', reporting.partial
  end

  test "without has_form class method" do
    reporting = TestNoFormReporting.new
    assert !reporting.has_form?
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
