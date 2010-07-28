module GoogleDataSource
  class InvalidData < Base
    def initialize(gviz_params)
      super(gviz_params)
    end

    def validate
      super
      add_error(:out, "Invalid output format: #{@params[:out]}. Valid ones are json,csv,html")
    end
  end
end
