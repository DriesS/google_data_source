class Reporting < ActiveForm
  def aggregate
    # override this method
    @columns = []
    @data    = []
  end

  def columns
    aggregate if @columns.nil?
    @columns
  end

  def data
    aggregate if @data.nil?
    @data
  end

  def partial
    "#{self.class.name.underscore}_form.html"
  end

  def form_id
    "#{self.class.name.underscore}_form"
  end

  def has_form?
    false
  end
end
