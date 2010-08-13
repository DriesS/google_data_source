# Super class for reportings to be rendered with Google visualizations
# Encapsulates the aggregation of the reporting data based on a configuration.
#
# The configuration is implemented by inherting from +ActiveRecord+ and switching off
# the database stuff. Thus the regular +ActiveRecord+ validators and parameter assignments
# including type casting cab be used
#
# The ActiveRecord extension is copied from the ActiveForm plugin (http://github.com/remvee/active_form)
class Reporting < ActiveRecord::Base
  attr_accessor :query, :group_by

  # 'Abstract' method that has to be overridden by subclasses
  # Sets the @data and @columns instance variables depending on the configuration
  # @data and @columns must be compatible with the +set+ method of +GoogleDataSource::Base+
  def aggregate
    @columns = []
    @data    = []
  end

  # Lazy getter for the columns object
  def columns
    aggregate if @columns.nil?
    @columns
  end

  # Lazy getter for the data object
  def data
    aggregate if @data.nil?
    @data
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

  # Returns the grouping columns as array
  def group_by
    @group_by ||= []
  end

  class << self
    # Uses the +simple_parse+ method of the SqlParser to setup a reporting
    # from a query. The where clause is intepreted as reporting configuration (activerecord attributes)
    def from_params(params)
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
    def column(name, options = {})
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
