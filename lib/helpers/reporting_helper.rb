module GoogleDataSource
  module ReportingHelper
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

    def google_reporting_timeline(reporting, url = nil, options = {})
      google_reporting('TimeLine', reporting, url, options)
    end
  end
end
