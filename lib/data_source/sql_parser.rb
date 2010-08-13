module GoogleDataSource
  module DataSource
    class SimpleSqlException < Exception; end

    class SqlParser
      include Sql::Parser

      class << self
        # Parses a simple SQL query and return the result
        # The where statement may only contain equality comparisons that are connected with 'and'
        # Only a single ordering parameter is accepted
        # Throws a +SimpleSqlException+ if these conditions are not satisfied
        def simple_parse(query)
          result = parse(query)
          OpenStruct.new({
            :select => result.select.collect(&:to_s),
            :conditions => simple_where_parser(result.where),
            :orderby => simple_orderby_parser(result.orderby),
            :groupby => simple_groupby_parser(result.groupby),
            :limit => result.limit,
            :offset => result.offset
          })
        end

        # Parses a SQL query and returns the result
        def parse(query)
          parser.parse(query)
        end

        protected
          # Helper to the +simple_parse+ method
          def simple_where_parser(predicate, result = Hash.new)
            case predicate.class.name.split('::').last
            when 'CompoundPredicate'
              raise SimpleSqlException.new("Operator forbidden (use only 'and')") unless predicate.op == :and
              simple_where_parser(predicate.left,  result)
              simple_where_parser(predicate.right, result)
            when 'ComparePredicate'
              case predicate.op
              when :"="
                result[predicate.left.to_s] = predicate.right.to_s
              when :"<", :">", :">=", :"<=", :"<>", :"!="
                result[predicate.left.to_s] ||= Array.new
                result[predicate.left.to_s] << OpenStruct.new(:op => predicate.op.to_s, :value => predicate.right.to_s)
              else
                raise SimpleSqlException.new("Comparator forbidden (use only '=,<,>')") unless predicate.op == :"="
              end
            when 'NilClass'
              # do nothing
            else
              raise SimpleSqlException.new("Unknown syntax error")
            end
            result
          end

          # Helper to the +simple_parse+ method
          def simple_orderby_parser(orderby)
            return nil if orderby.nil?
            raise SimpleSqlException.new("Too many ordering arguments (1 allowed)") if orderby.size > 1
            [orderby.first.expr.to_s, orderby.first.asc ? :asc : :desc]
          end

          # Helper to the +simple_parse+ method
          def simple_groupby_parser(groupby)
            return nil if groupby.nil?
            groupby.exprs.collect(&:to_s)
          end

          # Returns the parser
          def parser
            sql = self.new
            sql.make(sql.relation)
          end
      end
    end
  end
end
