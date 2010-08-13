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
        # default options
        options = {
          :form          => reporting.form_id,
          :autosubmit    => true,
          :form_position => :bottom
        }.update(options)
        
        visualization_html = google_visualization(type, url, options)
        form_html = content_tag("form", :id => reporting.form_id, :class => 'formtastic') do
          render :partial => reporting.partial
        end
        
        options[:form_position] == :bottom ? visualization_html << form_html : form_html << visualization_html
      end

      # Shows a timeline reporting
      def google_reporting_timeline(reporting, url = nil, options = {})
        google_reporting('TimeLine', reporting, url, options)
      end

      # Shows a table reporting
      def google_reporting_table(reporting, url = nil, options = {})
        google_reporting('Table', reporting, url, options)
      end

      # Shows a select tag for grouping selection on a given reporting
      # TODO more docu
      # TODO really take namespace from classname?
      def group_by_select(object, select_options, i = 1, options = {})
       tag_name = "#{object.class.name.underscore}[groupby(#{i}i)]"
       current_option = (object.group_by.size < i) ? nil : object.group_by[i-1]
       option_tags = options_for_select(select_options, current_option)
       select_tag(tag_name, option_tags, options)
      end
    end
  end
end
