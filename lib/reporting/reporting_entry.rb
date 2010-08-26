# This class represents a single reporting entry.
# Casting for numerical values and a '+' for the addition of different object
# is included.
class ReportingEntry
  # The raw attributes hash
  attr_reader :attributes

  # These constants define fields which are casted to integers/float
  # in the accessor. Also these fields are added when adding two
  # SuperReportingEntries.
  #
  # DON'T USE THIS FOR IDs (e.g. ad_id)
  SUMMABLE_INT_FIELDS_REGEXP   = /OVERWRITE_THIS_IN_SUBCLASS/
  SUMMABLE_FLOAT_FIELDS_REGEXP = /OVERWRITE_THIS_IN_SUBCLASS/

  # Standard constructor
  # takes attributes as hash (like OpenStruct)
  def initialize(attributes = {})
    @attributes = HashWithIndifferentAccess.new(attributes)
  end

  # Offers an +OpenStruct+ like access to the values stored in +@attributes+
  # Uses the information from +SUMMABLE_*_FIELDS_REGEXP+ to cast to numerical
  # values.
  def method_missing(method_id, *args)
    if @attributes.has_key?(method_id) || method_id.to_s =~ summable_fields_regexp
      return cast(method_id, @attributes[method_id])
    end
    super(method_id, *args)
  end

  # Add another +SuperReportingEntry+ and returns the resulting entry.
  # All attributes specified by +SUMMABLE_FIELD_REGEXP+ are summed up.
  # Further attributes are merged (the own values has priority).
  def +(other)
    result = Hash.new
    (@attributes.keys + other.attributes.keys).uniq.each do |key|
      if (key.to_s =~ summable_fields_regexp)
        result[key] = (self.send(key) + other.send(key))
      else
        result[key] = self.send(key) || other.send(key)
      end
    end
    self.class.new(result)
  end

  protected
    # Helper function to cast string values to numeric values if +key+
    # matches either +SUMMABLE_INT_FIELDS_REGEXP+ or +SUMMABLE_FLOAT_FIELDS_REGEXP+
    def cast(key, value)
      return value.to_i if key.to_s =~ summable_int_fields_regexp
      return value.to_f if key.to_s =~ summable_float_fields_regexp
      value
    end

    # reader for the regexp defining int fields
    def summable_int_fields_regexp
      self.class::SUMMABLE_INT_FIELDS_REGEXP
    end

    # reader for the regexp defining float fields
    def summable_float_fields_regexp
      self.class::SUMMABLE_FLOAT_FIELDS_REGEXP
    end

    # Returns the union of int and float defining regexps
    def summable_fields_regexp
      Regexp.union(summable_int_fields_regexp, summable_float_fields_regexp)
    end
end
