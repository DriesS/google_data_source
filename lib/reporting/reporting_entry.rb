# This class represents a single reporting entry.
# Casting for numerical values and a '+' for the addition of different object
# is included.
class ReportingEntry
  # The raw attributes hash
  attr_reader :attributes # TODO remove

  # These constants define fields which are casted to integers/float
  # in the accessor. Also these fields are added when adding two
  # SuperReportingEntries.
  #
  # DON'T USE THIS FOR IDs (e.g. ad_id)
  SUMMABLE_INT_FIELDS_REGEXP   = /OVERWRITE_THIS_IN_SUBCLASS/
  SUMMABLE_FLOAT_FIELDS_REGEXP = /OVERWRITE_THIS_IN_SUBCLASS/
  
  # Columns listed in this array are explicitely not summable
  NOT_SUMMABLE_FIELDS          = %w()

  # Standard constructor
  # takes attributes as hash (like OpenStruct)
  def initialize(attributes = {})
    @attributes = HashWithIndifferentAccess.new(attributes)
  end

  # Offers an +OpenStruct+ like access to the values stored in +@attributes+
  # Uses the information from +SUMMABLE_*_FIELDS_REGEXP+ to cast to numerical
  # values.
  def method_missing(method_id, *args)
    return self.send("lazy_#{method_id}", *args) if self.respond_to?("lazy_#{method_id}")
    if @attributes.has_key?(method_id) || method_id.to_s =~ summable_fields_regexp
      return cast(method_id, @attributes[method_id])
    end
    super(method_id, *args)
  end

  # Add another +SuperReportingEntry+ and returns the resulting entry.
  # All attributes specified by +SUMMABLE_FIELD_REGEXP+ are summed up.
  # Further attributes are merged (the own values has priority).
  def +(other)
    return self.class.composite([self, other])
  end

  # Returns a ReportingEntry object with all non addable values set to nil
  # This is thought be used for sum(mary) rows
  def to_sum_entry
    subject = self
    klass = Class.new(self.class) do
      # overwrite explicitely not summable columns
      #
      subject.send(:not_summable_fields).each do |method_id|
        define_method(method_id) { nil }
      end
      
      # method missing decides if the columns is displayed or not
      #
      define_method(:method_missing) do |method_id, *args|
        (method_id.to_s =~ summable_fields_regexp) ? subject.send(method_id, *args) : nil
      end

      # yes, this actually is a sum entry ;-)
      #
      def is_sum_entry?
        return true
      end
    end
    klass.new
  end

  # Returns a composite element which lazily sums up the summable values of the children
  def self.composite(entries)
    public_methods         = self.instance_methods - Object.public_methods
    summable_methods       = public_methods.select { |method| method.to_s =~ summable_fields_regexp }

    klass = Class.new(self) do
      define_method(:method_missing) do |method_id, *args|
        if (method_id.to_s =~ summable_fields_regexp)
          return entries.inject(0) do |sum, entry|
            sum + entry.send(method_id, *args)
          end
        else
          return entries.first.send(method_id, *args)
        end
      end

      # Delegate all summable method calls to the children
      # by using the method_missing method
      summable_methods.each do |method_id|
        define_method(method_id) do |*args|
          self.method_missing(method_id, *args)
        end
      end
      
      # For better debuggability
      #
      define_method :inspect do
        "CompositeReportingEntry [entries: #{entries.inspect} ]"
      end
    end
    klass.new
  end

  # Returns true if entry is a sum entry (like returned by to_sum_entry)
  def is_sum_entry?
    return false
  end

  protected
    # Helper function to cast string values to numeric values if +key+
    # matches either +SUMMABLE_INT_FIELDS_REGEXP+ or +SUMMABLE_FLOAT_FIELDS_REGEXP+
    def cast(key, value)
      return value.to_i if key.to_s =~ summable_int_fields_regexp
      return value.to_f if key.to_s =~ summable_float_fields_regexp
      value
    end

    # Returns the union of int and float defining regexps
    def self.summable_fields_regexp
      Regexp.union(self::SUMMABLE_INT_FIELDS_REGEXP, self::SUMMABLE_FLOAT_FIELDS_REGEXP)
    end

    # reader for the regexp defining int fields
    def summable_int_fields_regexp
      self.class::SUMMABLE_INT_FIELDS_REGEXP
    end

    # reader for the regexp defining float fields
    def summable_float_fields_regexp
      self.class::SUMMABLE_FLOAT_FIELDS_REGEXP
    end

    # convenience accessor for summable_fields_regexp
    def summable_fields_regexp
      self.class.summable_fields_regexp
    end
    
    # Returns an array of explicitely not summable fields
    #
    def not_summable_fields
      self.class::NOT_SUMMABLE_FIELDS
    end
    
    # For debugging purpose
    #
    def inspect
      "#{self.class.name}: <#{@attributes.inspect}>"
    end
end
