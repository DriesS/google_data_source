%w(base json_data csv_data html_data invalid_data column data_date data_date_time template_handler).each do |f|
  require File.join(File.expand_path(File.dirname(__FILE__)), 'lib', 'google_data_source', f)
end

ActiveRecord::Base.send :include, GoogleDataSource

# Register TemplateHandler
Mime::Type.register "application/json", :datasource
ActionView::Template.register_template_handler(:datasource, GoogleDataSource::TemplateHandler)
