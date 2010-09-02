module GoogleDataSource
  module DataSource
    # A simple template handler for a data source
    # Provides a GoogleDataSource::Base object datasource in the template so the template
    # can fill it with data
    class TemplateHandler < ActionView::TemplateHandler
      include ActionView::TemplateHandlers::Compilable

      def compile(template)
        <<-EOT
        datasource = GoogleDataSource::DataSource::Base.from_params(params)
        #{template.source.dup}
        if !datasource.reporting.nil? && datasource.reporting.has_form?
          datasource.callback = "$('\\\#\#{datasource.reporting.form_id}').html(\#{render(:partial => datasource.reporting.partial).to_json});"
        end

        if datasource.format == 'csv'
          headers['Content-Type']        = 'text/csv; charset=utf-8'
          headers['Content-Disposition'] = "attachment; filename=\\"\#{datasource.export_filename}.csv\\""
        end

        datasource.response
        EOT
      end
    end
  end
end
