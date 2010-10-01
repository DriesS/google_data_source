# This class is a Proxy class for sum rows.
#
# It decides on the fly which columns to display and delegates the real call to the subject
#
class SumEntry
  attr_reader :subject
  
  # Initialize a new summary row
  #
  # Expects a ReportingEntry as argument
  #
  def initialize(subject)
    @subject = subject
  end
  
  # This is a sum entry, yes
  #
  def is_sum_entry?
    return true
  end
  
  # This method does the actual proxying work
  #
  def method_missing(method_id, *args)
    (method_id.to_s =~ subject.send(:summable_fields_regexp)) ? subject.send(method_id, *args) : nil
  end
end