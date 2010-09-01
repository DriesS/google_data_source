module GoogleDataSource
  module DataSource
    class DataDate
      def initialize(date)
        @date = date
      end
    
      def to_json(options=nil)
        if @date
          "\"Date(#{@date.year}, #{@date.month-1}, #{@date.day})\""
        else
          "null"
        end
      end
    end
  end
end
