# Subclass of +Reporting+ class
# Offers a variety of helpers to manage reportings that are generated via pure SQL queries
#
class SqlReporting < Reporting

  # Returns the columns string for the select clause
  def sql_select(additional_columns = [], mapping = {})
    (map_columns((select + group_by).uniq, mapping, true) << additional_columns).flatten.join(', ')
  end

  # Returns the columns string for the group by clause
  def sql_group_by(additional_columns = [], mapping = {})
    (map_columns(group_by, mapping) << additional_columns).flatten.join(', ')
  end

  # TODO make protected?
  def map_columns(columns, mapping = {}, with_alias = false)
    mapped = []
    columns.each do |column|
      mapped << column if is_sql_column?(column)
    end
    mapped.collect do |column|
      if mapping.has_key?(column)
        with_alias ? "#{mapping[column]} #{column}" : mapping[column]
      else
        sql_column_name(column, :with_alias => with_alias) 
      end
    end
  end

  # Returns the join statements which are needed for the given +columns+
  def sql_joins(*columns)
    columns = select + group_by + where.keys if columns.empty?
    columns.flatten!

    # get all tables needed
    tables = columns.inject([]) do |tables, c|
      sql = datasource_columns[c][:sql]
      tables << sql[:table] if sql && sql.is_a?(Hash)
      tables
    end.compact.uniq

    # explode dependencies
    sql_joins = tables.collect do |table|
      result = [@@sql_tables[table]]
      while result.last.has_key?(:depends)
        result << @@sql_tables[result.last[:depends]]
      end
      result.reverse
    end.flatten.uniq

    sql_joins.collect { |t| t[:join] }.join(' ')
  end

  # Returns all datasource columns that correcpond to a SQL column
  def sql_columns
    datasource_columns.keys.delete_if { |c| !is_sql_column?(c) }.collect(&:to_sym)
  end

  # Returns +true+ if +column+ is a SQL column
  def is_sql_column?(column)
    datasource_columns.has_key?(column) && datasource_columns[column][:sql]
  end

  # Maps the column name using the +:sql+ definitions of the columns
  #
  # === options
  # * +:with_alias+ Returns 'mapped_name name' instead of mapped_name
  #
  def sql_column_name(column, options = {})
    return false unless is_sql_column?(column)
    sql = datasource_columns[column][:sql]
    return column.to_s if sql == true

    parts = []
    parts << sql[:table] if sql[:table]
    parts << (sql[:column] || column).to_s
    sql_name = parts.join('.')

    sql_name << " #{column}" if options[:with_alias]
    sql_name
  end

  class << self
    # Defines a SQL table that is not the 'main table'
    #
    # === Options
    # * +join+    Defines the SQL JOIN statement to join this table (mandatory)
    # * +depends+ Defines a table, this table depends on to join correclty (optional)
    #
    def table(name, options = {})
      @@sql_tables ||= HashWithIndifferentAccess.new
      @@sql_tables[name] = options
    end
  end
end