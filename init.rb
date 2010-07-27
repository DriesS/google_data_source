require 'google_data_source'

ActiveRecord::Base.send :include, GoogleDataSource

# Register TemplateHandler
Mime::Type.register "application/json", :datasource
ActionView::Template.register_template_handler(:datasource, GoogleDataSource::TemplateHandler)
