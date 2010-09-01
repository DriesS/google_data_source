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
        return google_visualization(type, url, options) unless options.delete(:form)

        # form
        # default options
        options = {
          :form          => reporting_form_id(reporting),
          :autosubmit    => true,
          :form_position => :bottom
        }.update(options)
        
        visualization_html = google_visualization(type, url, options)

        form_html = content_tag("form", :id => reporting_form_id(reporting), :class => 'formtastic') do
          render :partial => reporting_form_partial(reporting)
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

      # Returns callback JS code that sends the rendered form partial
      # So validation errors can be displayed
      def form_render_callback(reporting, options = {})
        "$('##{reporting_form_id(reporting)}').html(#{render(:partial => reporting_form_partial(reporting), :locals => {:reporting => reporting}).to_json});"
      end

      # Shows a select tag for grouping selection on a given reporting
      # TODO more docu
      # TODO really take namespace from classname?
      def reporting_group_by_select(reporting, select_options, i = 1, options = {})
       select_options = reporting_options_for_select(reporting, select_options, options)

       tag_name = "#{reporting.class.name.underscore}[groupby(#{i}i)]"
       current_option = (reporting.group_by.size < i) ? nil : reporting.group_by[i-1]
       option_tags = options_for_select(select_options, current_option)
       select_tag(tag_name, option_tags, options)
      end

      # Shows a Multiselect box for the columns to 'select'
      def reporting_select_select(reporting, select_options, options = {})
        select_options = reporting_options_for_select(reporting, select_options, options)

        tag_name = "#{reporting.class.name.underscore}[select]"
        option_tags = options_for_select(select_options, reporting.select)
        select_tag(tag_name, option_tags, :multiple => true)
      end

      # Adds labels to the select options when columns are passed in
      def reporting_options_for_select(reporting, select_options, options = {})
       if (select_options.is_a?(Array))
         select_options = select_options.collect { |column| [reporting.column_label(column), column] }
         select_options.unshift('') if options.delete(:include_blank)
       end
       select_options
      end

      # Registers form subit hooks
      # This way the standard form serialization can be overwritten
      def reporting_form_hooks(reporting)
        hooks = OpenStruct.new
        yield(hooks)

        json = []
        %w(select).each do |hook|
          next if hooks.send(hook).nil?
          json << "#{hook}: function(){#{hooks.send hook}}"
        end
        js = "DataSource.FilterForm.setHooks(#{reporting_form_id(reporting).to_json}, {#{json.join(', ')}});"
        javascript_tag(js)
      end

      # Returns the standard DOM id for reporting forms
      def reporting_form_id(reporting)
        "#{reporting.id}_form"
      end

      # Returns the standard partial for reporting forms
      def reporting_form_partial(reporting)
        "#{reporting.id}_form.html"
      end
    end
  end
end
