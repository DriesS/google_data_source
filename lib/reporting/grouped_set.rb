# Represents an array of Objects which can be grouped according to grouping keys
# or a grouping block, which returns the hash used for grouping
#
# The objects must support the '+' operation which is used to implode sets of objects
# with the same grouping hash.
class GroupedSet < Array
  #attr_reader :data

  # Standard constructor
  # +data+ is an Array of Objects implementing a '+' operation
  #def initialize(data)
  #  @data = data
  #end

  # Bang method for the regrouping of the data
  # The method takes either a set of keys or a block as grouping criterion
  #
  # If keys are set the grouping hash is built by calling +object.send(key).to_s+
  # and concatening for all keys. (e.g. if +Object+ supports the method +date+ the
  # grouping by +date+ is calculated by calling +regroup!(:date)+
  #
  # If a block is passed, it is called for every entry and it's result is taken as 
  # grouping hash. (e.g. +regroup! { |entry| entry.date }+ for grouping by date
  #
  # Objects with identical grouping hash are collapsed by calling the '+' operator
  # on them.
  #
  # ATTENTION:
  # This method won't recognize senseless grouping (e.g. calling
  # +regroup! { |entry| entry.date.month }+ followed by
  # +regroup! { |entry| entry.date }+ )
  def regroup(*keys, &block)
    # handle block
    return regroup_by_proc(block) if block_given?

    # handle keys
    block = Proc.new do |entry|
      keys.inject([]) { |memo, column| memo.push entry.send(column.to_sym).to_s }.join('-')
    end
    regroup_by_proc(block)
  end

  # Collapse the collection to a single entry
  def collapse
    regroup.first
  end

  protected
    # Helper method for regroup with groups the data using a proc as grouping hash generator
    def regroup_by_proc(grouping_proc)
      data = self.group_by { |entry| grouping_proc.call(entry) }.values
      result = data.collect do |entries|
        # Uses the class of the first element to build the composite element
        entries.first.class.composite(entries)
      end
      self.class.new(result)
    end
end
