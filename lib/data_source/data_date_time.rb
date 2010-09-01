module GoogleDataSource
  module DataSource
    class DataDateTime
      def initialize(datetime)
        @datetime = datetime
      end
    
      def to_json(options=nil)
        if @datetime
          "\"Date(#{@datetime.year}, #{@datetime.month-1}, #{@datetime.day}, #{@datetime.hour}, #{@datetime.min}, #{@datetime.sec})\""
        else
          "null"
        end
      end
    end
  end
end
