require 'csv'

module GoogleDataSource
  module DataSource
    class CsvData < Base
      def response
        result = CSV.generate do |csv|
          csv << cols.map { |col| col[:label] || col[:id] || col[:type] }
          data.each do |datarow|
            csv << datarow.map { |c| c.is_a?(Hash) ? c[:v] : c }
          end
        end
        result.force_encoding 'UTF-8'
      end
    end
  end
end
