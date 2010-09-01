module GoogleDataSource
  module DataSource
    # Superclass for all data source implementations
    # Offers methods for getting and setting the data and column definitions of
    # the data source
    class Base
      # Callback defines a JavaScript snippet that is appended to the regular
      # data-source reponse. This is currently used to refresh the form in
      # reportings (validation)
      attr_accessor :callback, :reporting, :column_labels, :formatters, :virtual_columns

      # Define accessors for the data source data, columns and errors
      attr_reader :errors
      
      # Creates a new instance and validates it. 
      # Protected method so it can be used from the subclasses
      def initialize(gdata_params)
        @virtual_columns  = HashWithIndifferentAccess.new
        @formatters       = HashWithIndifferentAccess.new
        @column_labels    = HashWithIndifferentAccess.new
        @required_columns = {}

        @raw_data = []
        @columns  = []

        @params = gdata_params
        @errors = {}
        @version = "0.6"
      
        validate
      end
      protected :initialize
      

      # Returns true if formatter formatter for a certain column is defined
      def has_formatter?(column_name)
        @formatters.has_key?(column_name)
      end

      # Convenience method for formatter definition
      def formatter(column, *requires, &block)
        set_required_columns(column, requires) #if options.has_key?(:requires)
        formatters[column] = block
      end

      # Return true if virtual column with name exists
      def is_virtual_column?(name)
        virtual_columns.has_key?(name)
      end

      # Sets up a virtual column with name and block with is called with a row
      # and returns a string or a hash like {v: "real value", f: "formatted value"}
      def virtual_column(name, options = {},  &block)
        @raw_data.add_virtual_column(name, options[:type] || :string) if @raw_data.respond_to?(:add_virtual_column)
        set_required_columns(name, options[:requires]) if options.has_key?(:requires)
        virtual_columns[name.to_sym] = {
          :type => options[:type] || :string,
          :proc => block
        }
      end

      # Getter with empty array default
      def required_columns
        required = column_ids.inject([]) { |columns, column| columns << @required_columns[column.to_sym] }.flatten.compact
        (required + column_ids).map(&:to_s).uniq
      end

      # Add a list of columns to the list of required columns (columns that have to be fetched)
      def set_required_columns(column, requires = [])
        @required_columns[column.to_sym] = requires
      end

      # Creates a new data source object from the get parameters of the data-source
      # request.
      def self.from_params(params)
        # Exract GDataSource params from the request.
        gdata_params = {}
        tqx = params[:tqx]
        unless tqx.blank?
          gdata_params[:tqx] = true
          tqx.split(';').each do |kv|
            key, value = kv.split(':')
            gdata_params[key.to_sym] = value
          end
        end
      
        # Create the appropriate GDataSource instance from the gdata-specific parameters
        gdata_params[:out] ||= "json"    
        gdata = from_gdata_params(gdata_params)
      end
      
      # Factory method to create a GDataSource instance from a serie of valid GData
      # parameters, as described in the official documentation (see above links).
      # 
      # +gdata_params+ can be any map-like object that maps keys (like +:out+, +:reqId+
      # and so forth) to their values. Keys must be symbols.
      def self.from_gdata_params(gdata_params)
        case gdata_params[:out]
        when "json"
          JsonData.new(gdata_params)
        when "html"
          HtmlData.new(gdata_params)
        when "csv"
          CsvData.new(gdata_params)
        else
          InvalidData.new(gdata_params)
        end
      end
      
      # Access a GData parameter. +k+ must be symbols, like +:out+, +:reqId+.
      def [](k)
        @params[k]
      end
    
      # Sets a GData parameter. +k+ must be symbols, like +:out+, +:reqId+.
      # The instance is re-validated afterward.
      def []=(k, v)
        @params[k] = v
        validate
      end
    
      # Checks whether this instance is valid (in terms of configuration parameters)
      # or not.
      def valid?
        @errors.size == 0
      end
    
      # Manually adds a new validation error. +key+ should be a symbol pointing
      # to the invalid parameter or element.
      def add_error(key, message)
        @errors[key] = message
        return self
      end
      
      # Sets the unformatted data of the datasource
      # +data+ is an array either of Hash objects or arbitrary objects 
      # * Hashes must have keys as column ids
      # * Arbitrary object must repond to column id named methods
      #
      def data=(data)
        # reset formatted data
        @data     = nil

        # set unformatted data
        @raw_data = data
        validate

        # register virtual columns
        if data.respond_to?(:add_virtual_column)
          @virtual_columns.each { |k, v| data.add_virtual_column(k.to_sym, v[:type]) }
        end
      end

      # Returns the formatted data in the datasource format
      #
      def data
        @data unless @data.nil?

        # get data from object (eg. Reporting)
        data = @raw_data.respond_to?(:data) ?
          @raw_data.data(:required_columns => required_columns) :
          @raw_data

        # Run formatters and virtual columns
        @data = data.collect do |row|
          row = OpenStruct.new(row) if row.is_a?(Hash)

          column_ids.inject([]) do |columns, column|
            if is_virtual_column?(column)
              columns << virtual_columns[column][:proc].call(row)
            elsif has_formatter?(column)
              columns << {
                :f => formatters[column.to_sym].call(row),
                :v => row.send(column)
              }
            else
              columns << row.send(column)
            end
          end
        end
      end

      # Returns the ids of the columns
      #
      def column_ids
        columns.collect(&:id)
      end

      # Sets the columns which should be sent by the datasource
      # +columns+ is an array of either Hashes with keys (:id, :type, :label)
      # or +Column+ objects
      #
      def columns=(columns)
        @columns = columns.map { |c| c.is_a?(Column) ? c : Column.new(c) }
        @columns.each do |col|
          raise ArgumentError, "Invalid column type: #{col.type}" unless col.valid?
        end
      end

      # Returns the columns in a datasource compatible format
      # Applies all labels set
      def columns
        @columns.each { |c| c.label = column_labels.delete(c.id) if column_labels.has_key?(c.id) }
        @columns
      end

      # Make cols alias for json ... classes
      alias_method :cols, :columns
      deprecate :cols

      # Sets the raw data and the columns simultaniously and tries to guess the
      # columns if not set.
      # +data+ may be an array of rows or an object of a class that support a data(options)
      # and a columns method
      #
      def set(data, columns = nil)
        self.data     = data
        self.columns  = columns || guess_columns(@raw_data)
      end

      # Tries to get a clever column selection from the items collection.
      # Currently only accounts for ActiveRecord objects
      # +items+ is an arbitrary collection of items as passed to the +set+ method
      def guess_columns(data)
        return data.columns if data.respond_to? :columns

        columns = []
        klass = data.first.class
        klass.columns.each do |column|
          columns << Column.new({
            :id => column.name,
            :label => column.name.humanize,
            :type => 'string' # TODO get the right type
          })
        end
        columns
      end

      # Validates this instance by checking that the configuration parameters
      # conform to the official specs.
      def validate
        @errors.clear

        # check validity
        if @raw_data.respond_to?(:valid?) && ! @raw_data.valid?
          add_error(:reqId, "Form validation failed")
        end

        if @params[:tqx]
          add_error(:reqId, "Missing required parameter reqId") unless @params[:reqId]
        
          if @params[:version] && @params[:version] != @version
            add_error(:version, "Unsupported version #{@params[:version]}")
          end
        end
      end
    
      # Empty method. This is a placeholder implemented by subclasses that
      # produce the response according to a given format.
      def response
      end
      
      # Empty method. This is a placeholder implemented by subclasses that return the correct format
      def format
      end
    end
  end
end
