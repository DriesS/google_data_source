# Super class for reportings to be rendered with Google visualizations
# Encapsulates the aggregation of the reporting data based on a configuration.
#
# The configuration is implemented by inherting from +ActiveRecord+ and switching off
# the database stuff. Thus the regular +ActiveRecord+ validators and parameter assignments
# including type casting cab be used
#
# The ActiveRecord extension is copied from the ActiveForm plugin (http://github.com/remvee/active_form)
class Reporting < ActiveRecord::Base
  attr_accessor :query, :group_by, :select, :column_labels, :formatters, :virtual_columns
  cattr_reader :datasource_columns

  def initialize(*args)
    @virtual_columns = HashWithIndifferentAccess.new
    @formatters      = HashWithIndifferentAccess.new
    @column_labels   = HashWithIndifferentAccess.new
    super(*args)
  end

  # 'Abstract' method that has to be overridden by subclasses
  # Sets the @data and @columns instance variables depending on the configuration
  # @data and @columns must be compatible with the +set+ method of +GoogleDataSource::Base+
  def aggregate
    @rows = []
  end

  # Returns the data rows
  # Calls the aggregate method first if rows do not exist
  def rows
    aggregate if @rows.nil?
    @rows || []
  end

  # Add a row to the rows set returned by rows
  # Takes a hash and stores only selected columns applying the formatters if existent.
  #
  # This method should be called from the aggregate method of subclasses
  def add_row(row)
    row = HashWithIndifferentAccess.new(row)
    @rows ||= []
    @rows << select.inject([]) do |columns, column|
      if is_virtual_column?(column)
        columns << virtual_columns[column][:proc].call(row)
      elsif has_formatter?(column)
        columns << {
          :f => formatters[column.to_sym].call(row[column], row),
          :v => row[column]
        }
      else
        columns << row[column]
      end
    end
  end

  # Lazy getter for the columns object
  def columns
    select.inject([]) do |columns, column|
      columns << {
        :type => all_columns[column][:type]
      }.merge({
        :id    => column.to_s,
        :label => column_labels[column.to_sym] ? column_labels[column.to_sym] : column.to_s.humanize
      })
    end
  end

  # Returns true if formatter formatter for a certain column is defined
  def has_formatter?(column_name)
    @formatters.has_key?(column_name)
  end

  # Convenience method for formatter definition
  def formatter(column, &block)
    formatters[column] = block
  end

  # Returns the path the form partial. May be overriden by subclass
  def partial
    "#{self.class.name.underscore.split('/').last}_form.html"
  end

  # Returns the DOM id of the form. May be overriden by subclass
  def form_id
    "#{self.class.name.underscore.split('/').last}_form"
  end

  # Returns +true+ if reporting is configuraible via a form
  # May be overridden by subclass
  def has_form?
    false
  end

  # Returns the select columns as array
  def select
    (@select ||= []).collect { |c| c == '*' ? all_columns.keys : c }.flatten
  end

  # Returns the grouping columns as array
  def group_by
    @group_by ||= []
  end

  # Return true if virtual column with name exists
  def is_virtual_column?(name)
    virtual_columns.has_key?(name)
  end

  # Sets up a virtual column with name and block with is called with a row
  # and returns a string or a hash like {v: "real value", f: "formatted value"}
  def virtual_column(name, type = :string, &block)
    virtual_columns[name.to_sym] = {
      :type => type,
      :proc => block
    }
  end

  # Returns a list of all columns (real and virtual)
  def all_columns
    datasource_columns.merge(virtual_columns)
  end

  class << self
    # TODO docu
    def column(name, options = {})
      @@datasource_columns ||= HashWithIndifferentAccess.new
      default_options = { :type  => :string }
      datasource_columns[name] = default_options.merge(options)
    end

    # Uses the +simple_parse+ method of the SqlParser to setup a reporting
    # from a query. The where clause is intepreted as reporting configuration (activerecord attributes)
    def from_params(params, key = self.name.underscore.split('/').last)
      return self.new unless params.has_key?(:tq)

      query = GoogleDataSource::DataSource::SqlParser.simple_parse(params[:tq])
      attributes = Hash.new
      query.conditions.each do |k, v|
        if v.is_a?(Array)
          v.each do |condition|
            case condition.op
            when '<='
              attributes["to_#{k}"] = condition.value
            when '>='
              attributes["from_#{k}"] = condition.value
            else
              # raise exception for unsupported operator?
            end
          end
        else
          attributes[k] = v
        end
      end
      attributes[:group_by] = query.groupby
      attributes[:select]   = query.select
      attributes.merge!(params[key]) if params.has_key?(key)
      reporting = self.new(attributes.symbolize_keys)
      reporting.query = params[:tq]
      reporting
    end

    ############################
    # ActiveRecord overrides
    ############################
    def columns # :nodoc:
      @columns ||= []
    end

    # Define an attribute.  It takes the following options:
    # [+:type+] schema type
    # [+:default+] default value
    # [+:null+] whether it is nullable
    # [+:human_name+] human readable name
    def filter(name, options = {})
      name = name.to_s
      options.each { |k,v| options[k] = v.to_s if Symbol === v }
      
      if human_name = options.delete(:human_name)
        name.instance_variable_set('@human_name', human_name)
        def name.humanize; @human_name; end
      end
      
      columns << ActiveRecord::ConnectionAdapters::Column.new(
        name,
        options.delete(:default),
        options.delete(:type) || :string,
        options.include?(:null) ? options.delete(:null) : true
      )
      
      raise ArgumentError.new("unknown option(s) #{options.inspect}") unless options.empty?
    end

    def abstract_class # :nodoc:
      true
    end
  end

  ############################
  # ActiveRecord overrides
  ############################

  def save # :nodoc:
    if result = valid?
      callback(:before_save)
      callback(:before_create)
      
      # do nothing!
      
      callback(:after_save)
      callback(:after_create)
    end
    
    result
  end
  
  def save! # :nodoc:
    save or raise ActiveRecord::RecordInvalid.new(self)
  end
end
