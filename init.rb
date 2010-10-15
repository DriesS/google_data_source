$:.unshift File.join(File.dirname(__FILE__), 'lib')
 
require 'ostruct'

require 'data_source/base'
require 'data_source/json_data'
require 'data_source/csv_data'
require 'data_source/html_data'
require 'data_source/invalid_data'
require 'data_source/column'
require 'data_source/data_date'
require 'data_source/data_date_time'
require 'data_source/template_handler'

require 'data_source/sql/models'
require 'data_source/sql/parser'
require 'data_source/sql_parser'

require 'reporting/reporting'
require 'reporting/reporting_adapter'
require 'reporting/sql_reporting'
require 'reporting/reporting_entry'
require 'reporting/grouped_set'
require 'reporting/action_controller_extension'

require 'data_source/helper'
require 'reporting/helper'

require 'data_source/test_helper'

# register helper
ActionView::Base.class_eval { include GoogleDataSource::DataSource::Helper }
ActionView::Base.class_eval { include GoogleDataSource::Reporting::Helper }

# register controller exentsion
ActionController::Base.class_eval do
  include GoogleDataSource::Reporting::ActionControllerExtension
  alias_method_chain :render, :reporting
end

# I18n
I18n.load_path.unshift *Dir[File.join(File.dirname(__FILE__), 'lib', 'locale', '*.{rb,yml}')]

# Register TemplateHandler
# TODO set mime type to CSV / HTML according to the output format
Mime::Type.register "application/json", :datasource
ActionView::Template.register_template_handler(:datasource, GoogleDataSource::DataSource::TemplateHandler)
