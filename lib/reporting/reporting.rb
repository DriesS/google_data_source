class CircularDependencyException < Exception; end

# Super class for reportings to be rendered with Google visualizations
# Encapsulates the aggregation of the reporting data based on a configuration.
#
# The configuration is implemented by inherting from +ActiveRecord+ and switching off
# the database stuff. Thus the regular +ActiveRecord+ validators and parameter assignments
# including type casting cab be used
#
# The ActiveRecord extension is copied from the ActiveForm plugin (http://github.com/remvee/active_form)
class Reporting < ActiveRecord::Base
  attr_accessor :query, :group_by, :select, :order_by, :limit, :offset
  attr_reader :virtual_columns #, :required_columns
  attr_writer :id
  class_inheritable_accessor :datasource_filters, :datasource_columns, :datasource_defaults, :sql_filters

  # Stadanrd constructor
  def initialize(*args)
    @required_columns = []
    @virtual_columns = {}
    super(*args)
  end
  
  # Returns an instance of our own connection adapter
  # 
  def self.connection
    @adapter ||= ActiveRecord::ConnectionAdapters::ReportingAdapter.new
  end

  # Returns an ID which is used by frontend components to generate unique dom ids 
  # Defaults to the underscoreized classname
  def id
    @id || self.class.name.underscore.split('/').last #gsub('/', '_')
  end

  # helper method used by required_columns
  # Returns all columns required by a certain column resolving the dependencies recursively
  def required_columns_for(column, start = nil)
    return [] unless self.datasource_columns.has_key?(column)
    raise CircularDependencyException.new("Column #{start} has a circular dependency") if column.to_sym == start
    columns = [self.datasource_columns[column][:requires]].flatten.compact
    columns.collect { |c| [c, required_columns_for(c, start || column.to_sym)] }.flatten
  end

  # Returns the columns that have to be selected
  def required_columns
    (select + group_by + @required_columns).inject([]) do |columns, column|
      columns << required_columns_for(column)
      columns << column
    end.flatten.map(&:to_s).uniq
  end

  # Adds required columns
  def add_required_columns(*columns)
    @required_columns = (@required_columns + columns.flatten.collect(&:to_s)).uniq
  end

  # 'Abstract' method that has to be overridden by subclasses
  # Returns an array of rows written to #rows and accessible in DataSource compatible format in #rows_as_datasource
  # 
  def aggregate
    []
  end

  # Returns the data rows
  # Calls the aggregate method first if rows do not exist
  #
  def data(options = {})
    add_required_columns(options[:required_columns])
    @rows ||= aggregate
  end

  # Lazy getter for the columns object
  def columns
    select.inject([]) do |columns, column|
      columns << {
        :type => all_columns[column][:type]
      }.merge({
        :id    => column.to_s,
        :label => column_label(column)
      })
    end
  end

  # Retrieves the I18n translation of the column label
  def column_label(column, default = nil)
    return '' if column.blank?
    defaults = ['reportings.{{model}}.{{column}}', 'models.attributes.{{model}}.{{column}}'].collect do |scope|
      scope.gsub!('{{model}}', self.class.name.underscore.gsub('/', '.'))
      scope.gsub('{{column}}', column.to_s)
    end.collect(&:to_sym)
    defaults << column.to_s.humanize
    I18n.t(defaults.shift, :default => defaults)
  end

  # Returns the select columns as array
  def select
    (@select ||= (defaults[:select] || [])).collect { |c| c == '*' ? all_columns.keys : c }.flatten
  end

  # Returns the grouping columns as array
  def group_by
    @group_by ||= (defaults[:group_by] || [])
  end

  # add a virtual column
  def add_virtual_column(name, type = :string)
    virtual_columns[name.to_sym] = {
      :type => type
    }
  end

  # Returns a list of all columns (real and virtual)
  def all_columns
    datasource_columns.merge(virtual_columns)
  end

  # Returns the +defaults+ Hash
  # Convenience wrapper for instance access
  def defaults
    self.class.defaults #.merge(@defaults || {})
  end

  # Attribute reader for datasource_columns
  def datasource_columns
    self.class.datasource_columns || { }
  end

  # Returns a serialized representation of the reporting
  def serialize
    to_param.to_json
  end

  def to_param # :nodoc:
    attributes.merge({
      :select   => select,
      :group_by => group_by,
      :order_by => order_by,
      :limit => limit,
      :offset => offset
    })
  end

  # Returns the serialized Reporting in a Hash that can be used for links
  # and which is deserialized by from_params
  def to_params(key = self.class.name.underscore.gsub('/', '_'))
    HashWithIndifferentAccess.new( key => to_param )
  end

  class << self

    # Defines a displayable column of the datasource
    # Type defaults to string
    def column(name, options = {})
      self.datasource_columns ||= HashWithIndifferentAccess.new
      default_options = { :type  => :string }
      datasource_columns[name] = default_options.merge(options)
    end

    # Returns the defaults class variable
    def defaults
      self.datasource_defaults ||= Hash.new
    end

    # Sets the default value for select
    def select_default(select)
      defaults[:select] = select
    end

    # Sets the default value for group_by
    def group_by_default(group_by)
      defaults[:group_by] = group_by
    end

    # Returns a reporting from a serialized representation
    def deserialize(value)
      self.new(JSON.parse(value))
    end

    # Uses the +simple_parse+ method of the SqlParser to setup a reporting
    # from a query. The where clause is intepreted as reporting configuration (activerecord attributes)
    def from_params(params, key = self.name.underscore.gsub('/', '_'))
      return self.deserialize(params[key]) if params.has_key?(key) && params[key].is_a?(String)

      reporting = self.new(params[key])
      return reporting unless params.has_key?(:tq)

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
            when 'in'
              attributes["in_#{k}"] = condition.value
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
      attributes[:order_by] = query.orderby
      attributes[:limit]    = query.limit
      attributes[:offset]   = query.offset
      attributes.merge!(params[key]) if params.has_key?(key)
      #reporting.update_attributes(attributes)
      reporting.attributes = attributes
      reporting.query = params[:tq]
      reporting
    end

    ############################
    # ActiveRecord overrides
    ############################
    def columns # :nodoc:
      self.datasource_filters ||= []
    end

    # Define an attribute.  It takes the following options:
    # [+:type+] schema type
    # [+:default+] default value
    # [+:null+] whether it is nullable
    # [+:human_name+] human readable name
    def filter(name, options = {})
      name = name.to_s
      options.each { |k,v| options[k] = v.to_s if Symbol === v }
      
      # Adds the new value to the sql_filters hash
      #
      self.sql_filters ||= {}
      self.sql_filters[name] = options
      self.sql_filters[name][:type] ||= :string

      if human_name = options.delete(:human_name)
        name.instance_variable_set('@human_name', human_name)
        def name.humanize; @human_name; end
      end
      
      columns << ActiveRecord::ConnectionAdapters::Column.new(
        name,
        sql_filters[name][:default],
        sql_filters[name][:type],
        options.include?(:null) ? options[:null] : true
      )
      
      # raise ArgumentError.new("unknown option(s) #{options.inspect}") unless options.empty?
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
    end
    
    result
  end
  
  def save! # :nodoc:
    save or raise ActiveRecord::RecordInvalid.new(self)
  end
end
