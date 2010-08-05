module GoogleDataSource
  module Reporting
    module Helper
      # Shows a reporting consisting of a visualization and a form for configuration
      # +type+ can be either
      # * 'Table'
      # * 'TimeLine'
      # +reporting+ is the +Reporting+ object to be displayed
      # Have a look at +google_visualization+ helper for +url+ and +options+ parameter
      def google_reporting(type, reporting, url = nil, options = {})
        # no form
        return google_visualization(type, url, options) unless reporting.has_form?

        # form
        html  = google_visualization(type, url, options.merge(:form => reporting.form_id))
        html << content_tag("form", :id => reporting.form_id, :class => 'formtastic') do
          render :partial => reporting.partial
        end
        html
      end

      # Shows a timeline reporting
      def google_reporting_timeline(reporting, url = nil, options = {})
        google_reporting('TimeLine', reporting, url, options)
      end

      # Shows a table reporting
      def google_reporting_table(reporting, url = nil, options = {})
        google_reporting('Table', reporting, url, options)
      end
    end
  end
end