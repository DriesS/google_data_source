# Subclass of +Reporting+ class
# Offers a variety of helpers to manage reportings that are generated via pure SQL queries
#
class SqlReporting < Reporting
  attr_reader :columns_used
  class_inheritable_accessor :sql_tables

  # Container for columns used by any (select, group by, where) statement.
  # Used by the joins method to retrieve the joins needed
  def columns_used
    @columns_used ||= []
  end

  # Marks a column as used so the connected joins will be included
  def mark_as_used(column)
    columns_used << column.to_sym
  end

  # Returns the columns string for the select clause
  def sql_select(additional_columns = [], mapping = {})
    (map_columns(required_columns, mapping, true) << additional_columns).flatten.join(', ')
  end

  # Returns the columns string for the group by clause
  #def sql_group_by(additional_columns = [], mapping = {})
  def sql_group_by(*args)
    mapping = args.extract_options! || {}
    additional_columns = args.first || []
    result = (map_columns(group_by, mapping) << additional_columns).flatten.join(', ')
    result.empty? ? nil : result
  end

  def sql_order_by(mapping = {})
    return nil if order_by.nil?
    column    = order_by[0]
    direction = order_by[1]
    column    = mapping.has_key?(column) ? mapping[column] : sql_column_name(column)
    "#{column} #{direction.to_s.upcase}"
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
    if columns.empty?
      columns = columns_used + required_columns
      columns += where.keys if self.respond_to?(:where)
    end
    columns.uniq!
    columns.flatten!

    # get all tables needed
    tables = columns.inject([]) do |tables, c|
      sql = datasource_columns[c][:sql] if is_sql_column?(c)
      tables << sql[:table] if sql && sql.is_a?(Hash)
      tables
    end.compact.uniq

    # explode dependencies
    sql_joins = tables.collect do |table|
      result = [self.class.sql_tables[table]]
      while result.last.has_key?(:depends)
        result << self.class.sql_tables[result.last[:depends]]
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
    parts << sql[:table] if sql[:table] && !sql[:column].is_a?(String)
    parts << (sql[:column] || column).to_s
    sql_name = parts.join('.')

    sql_name << " #{column}" if options[:with_alias]
    sql_name
  end
  
  # Returns the SQL condition for the given column, depending on the columns type
  #
  def sql_condition_for(column_name, value)
    # use the sql column name to be sure the table name is included if an sql column is defined
    sql_name = is_sql_column?(column_name) ? sql_column_name(column_name) : column_name
    bind_vars = [ ]
    condition = ''
    type = self.class.sql_filters.symbolize_keys[column_name][:type].to_sym
    case type
      when :boolean then
        bind_vars = value
        condition = "(#{sql_name} = ?" + (value == false ? " OR ISNULL(#{sql_name}))" : ')')
      else
        bind_vars = value
        # special handling for zero numbers = allow them to be null too
        if [ :number, :integer ].include?(type) and not value.kind_of?(Array)
          condition = "(#{sql_name} = ? #{(value.to_i.zero? ? "OR ISNULL(#{sql_name})" : "")})"
        else
          condition = value.kind_of?(Array) ? "(#{sql_name} IN(?))" : "(#{sql_name} = ?)"
        end
    end
    self.class.send(:sanitize_sql_array, [ condition, bind_vars ])
  end

  class << self

    # Defines a SQL table that is not the 'main table'
    #
    # === Options
    # * +join+    Defines the SQL JOIN statement to join this table (mandatory)
    # * +depends+ Defines a table, this table depends on to join correclty (optional)
    #
    def table(name, options = {})
      self.sql_tables ||= HashWithIndifferentAccess.new
      sql_tables[name] = options
    end
  end
end
