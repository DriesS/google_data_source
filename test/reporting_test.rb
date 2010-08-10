require "#{File.expand_path(File.dirname(__FILE__))}/test_helper"

class ReportingTest < ActiveSupport::TestCase
  class TestReporting < Reporting
    attr_reader :aggregate_calls
    column :name
    column :from_date, :type => :date
    column :to_date, :type => :date

    def initialize(*args)
      @aggregate_calls = 0
      super(*args)
    end

    def aggregate
      @aggregate_calls += 1
      # set data and columns so aggregate is only called once
      @data = []
      @columns = []
    end
  end

  test "columns" do
    r = TestReporting.new
    r.columns
    r.data
    assert_equal 1, r.aggregate_calls
  end

  test "partial" do
    r = TestReporting.new
    assert_equal "test_reporting_form.html", r.partial
  end

  test "form_id" do
    r = TestReporting.new
    assert_equal "test_reporting_form", r.form_id
  end

  test "from_params" do
    query = "where name = 'test name' and from_date = '2010-01-01'"
    r = TestReporting.from_params({:tq => query})
    assert_equal "test name", r.name
    assert_equal "2010-01-01".to_date, r.from_date
  end

  test "from_params_with_date_range" do
    query = "where `date` > '2010-01-01' and `date`<'2010-02-01'"
    r = TestReporting.from_params({:tq => query})
    assert_equal "2010-01-01".to_date, r.from_date
    assert_equal "2010-02-01".to_date, r.to_date
  end

  ################################
  # Test ActiveRecord extension
  ################################

  test "class loads" do
    assert_nothing_raised { Reporting }
  end
  
  test "can add columns" do
    self.class.class_eval %q{
      class CanAddColumns < Reporting
        %w(foo bar test).each { |c| column c }
      end
    }
    assert_equal 3, CanAddColumns.columns.size
  end
  
  test "type properly set" do
    self.class.class_eval %q{
      class TypeProperlySet < Reporting
        %w(string text date datetime boolean).each do |type|
          column "a_#{type}".to_sym, :type => type.to_sym
        end
      end
    }
    
    assert TypeProperlySet.columns.size > 0, 'no columns added'
    
    %w(string text date datetime boolean).each do |type|
      assert_equal type, TypeProperlySet.columns_hash["a_#{type}"].sql_type
    end
  end
  
  test "default properly set" do
    self.class.class_eval %q{
      class DefaultPropertlySet < Reporting
        column :bicycle, :default => 'batavus'
      end
    }
    assert_equal 'batavus', DefaultPropertlySet.new.bicycle
  end
  
  test "columns are humanizable" do
    self.class.class_eval %q{
      class Humanizable < Reporting
        column :bicycle, :human_name => 'fiets'
      end
    }
    
    assert_equal 'fiets', Humanizable.columns_hash['bicycle'].human_name
  end
  
  test "fail on illegal options" do
    assert_raises ArgumentError do
      self.class.class_eval %q{
        class FailOnIllegalOption < Reporting
          column :foo, :bar => 'yelp!'
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
        column :required
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
        column :required_field
        validates_presence_of :required_field
      end
    }
    
    assert_raises ActiveRecord::RecordInvalid do
      CreateBangFailure.create!
    end
  end
end
