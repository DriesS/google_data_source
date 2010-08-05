module GoogleDataSource
  module DataSource
    class JsonData < Base
      def initialize(gdata_params)
        super(gdata_params)
        @responseHandler = "google.visualization.Query.setResponse"
      end
    
      # Returns the datasource in JSON format. It supports the +responseHandler+
      # parameter. All the errors are returned with the +invalid_request+ key.
      # Warnings are unsupported (yet).
      def response
        rsp = {}
        rsp[:version] = @version
        rsp[:reqId] = @params[:reqId] if @params.key?(:reqId)
        if valid?
          rsp[:status] = "ok"
          rsp[:table] = datatable unless data.nil?      
        else
          rsp[:status] = "error"
          rsp[:errors] = @errors.values.map do |error|
            { :reason => "invalid_request" , :message => error }
          end
        end
        "#{@params[:responseHandler] || @responseHandler}(#{rsp.to_json});#{callback}"
      end
    
      # Renders the part of the JSON response that contains the dataset.
      def datatable
        dt = {}
        dt[:cols] = cols
        dt[:rows] = []
        data.each do |datarow|
          row = []
          datarow.each_with_index do |datacell, colnum|
            if datacell.is_a?(Hash)
              row << {
                :v => convert_cell(datacell[:v], cols[colnum][:type]),
                :f => datacell[:f]
              }
            else
              row << { :v => convert_cell(datacell, cols[colnum][:type])  }
            end
          end
        
          dt[:rows] << { :c => row }
        end
        return dt
      end
      protected :datatable
    
      # Converts a value in the dataset into a format suitable for the 
      # column it belongs to. 
      #
      # Datasets are expected to play nice, and try to adhere to the columns they
      # intend to export as much as possible. This method doesn't do anything more
      # than the very minimum to ensure a formally valid gviz export.
      def convert_cell(value, coltype)
        case coltype
        when "boolean"
          !!value
        when "number"
          value # TODO to_i ???
        when "string"
          value
        when "date"
          DataDate.new(value.is_a?(String) ? Date.parse(value) : value)
        when "datetime"
          DataDateTime.new(value.is_a?(String) ? DateTime.parse(value) : value)
        when "timeofday"
          [ value.hour, value.min, value.sec, value.usec / 1000 ]
        end
      end
      protected :convert_cell
    end
  end
end
