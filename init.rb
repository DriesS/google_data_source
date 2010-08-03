this_dir = File.expand_path(File.dirname(__FILE__))
%w(base json_data csv_data html_data invalid_data column data_date data_date_time template_handler reporting reporting_renderer).each do |f|
  require File.join(this_dir, 'lib', 'google_data_source', f)
end

require File.join(this_dir, 'lib', 'helpers', 'google_data_source_helper')
require File.join(this_dir, 'lib', 'helpers', 'reporting_helper')

ActiveRecord::Base.send :include, GoogleDataSource
ActionView::Base.class_eval { include GoogleDataSource::Helper }
ActionView::Base.class_eval { include GoogleDataSource::ReportingHelper }

# Register TemplateHandler
# TODO set mime type to CSV / HTML according to the output format
Mime::Type.register "application/json", :datasource
ActionView::Template.register_template_handler(:datasource, GoogleDataSource::TemplateHandler)
