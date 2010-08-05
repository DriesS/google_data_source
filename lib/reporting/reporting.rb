# Super class for reportings to be rendered with Google visualizations
# Encapsulates the aggregation of the reporting data based on a configuration.
# The configuration is implemented as +ActiveForm+ columns and thus can be
# validated using the +ActiveRecord+ +validates_...+ methods
class Reporting < ActiveForm
  # 'Abstract' method that has to be overridden by subclasses
  # Sets the @data and @columns instance variables depending on the configuration
  # @data and @columns must be compatible with the +set+ method of +GoogleDataSource::Base+
  def aggregate
    @columns = []
    @data    = []
  end

  # Lazy getter for the columns object
  def columns
    aggregate if @columns.nil?
    @columns
  end

  # Lazy getter for the data object
  def data
    aggregate if @data.nil?
    @data
  end

  # Returns the path the form partial. May be overriden by subclass
  def partial
    "#{self.class.name.underscore.split('/').last}_form.html"
  end

  # Returns the DOM id of the form. May be overriden by subclass
  def form_id
    "#{self.class.name.underscore.split('/').last}_form"
  end

  # Returns +true+ if reporting is configuraible via a form
  # May be overridden by subclass
  def has_form?
    false
  end
end
