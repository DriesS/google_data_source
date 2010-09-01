module GoogleDataSource
  # Some usefull helpers for testing datasources
  module TestHelper

    # Returns the parsed JSON argument of the datasource response
    def datasource_response
      first_cmd = @response.body.match(/([^;"]*|"(\\"|[^"])*;?(\\"|[^"])*")*;/)[0]
      response = OpenStruct.new(JSON.parse(first_cmd.match(/^[^(]*\((.*)\);$/)[1]))
      response.table = OpenStruct.new(response.table)
      response
    end

    # Returns the columns array of the JSON response
    def datasource_column(column)
      response = datasource_response
      column_no = response.table.cols.collect { |c| c['id'] }.index(column.to_s)
      response.table.rows.collect { |r| r['c'][column_no] }
    end

    # Returns the column ids of the JSON response
    def datasource_column_ids
      datasource_response.table.cols.collect { |c| c['id'] }
    end

  end
end
