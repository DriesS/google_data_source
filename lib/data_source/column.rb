module GoogleDataSource
  module DataSource
    class Column
      attr_accessor :type, :id, :label, :pattern

      COLTYPES = %w(boolean number string date datetime timeofday)
      #COLKEYS  = [:type, :id, :label, :pattern]
      
      def initialize(params)
        @type = (params[:type] || :string).to_s
        @id = params[:id].to_sym
        @label = params[:label]
        @pattern = params[:pattern]
      end

      def valid?
        COLTYPES.include?(type)
      end

      def to_h
        {
          :id => id,
          :type => type,
          :label => label,
          :pattern => pattern
        }
      end
      
    end
  end
end
