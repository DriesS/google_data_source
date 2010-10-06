module ActiveRecord
  module ConnectionAdapters
    # This connection adapter does the quoting the way our reporting class should generate it
    # 
    #
    class ReportingAdapter < AbstractAdapter

      def initialize
        super(nil)
      end

      def quoted_true
        "'1'"
      end
      
      def quoted_false
        "'0'"
      end
      
      # Quotes a string, escaping any ' (single quote) and \ (backslash)
      # characters.
      def quote_string(s)
        s.gsub(/\\/, '\&\&').gsub(/'/, "\\\\'") # ' (for ruby-mode)
      end
    end
  end
end