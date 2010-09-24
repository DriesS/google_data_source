require 'csv'
#require 'action_pack'

module GoogleDataSource
  module DataSource
    class CsvData < Base
      #include ActionView::Helpers::NumberHelper
      def response
        result = CSV.generate(:col_sep => ';') do |csv|
          csv << columns.map { |col| col.label || col.id || col.type }
          data.each do |datarow|
            csv << datarow.map do |c|
              c.is_a?(Hash) ? c[:v] : c
              # TODO
              #value.is_a?(Float) ? number_with_delimiter(value) : value
            end
          end
        end
        result.force_encoding 'UTF-8'
      end
    end
  end
end
