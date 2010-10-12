module GoogleDataSource
  module DataSource
    module Helper
      # Includes the JavaScript files neccessary for data source visualization
      # The helper should be called the header of the layout
      def google_data_source_includes(ssl = false)
        html = "<script src='http#{"s" if ssl}://www.google.com/jsapi' type='text/javascript'></script>"
        html << javascript_include_tag('google_datatable')
        html
      end

      # Shows a Google visualization.
      # Available +types+ include:
      # * Table
      # * TimeLine
      # +url+ defines the URL to the data source and defaults to +url_for(:format => 'datasource').
      # The options are generally passed to the visualization JS objects after camlizing the keys
      # Options that are not passed include:
      # * +:container_id+ : The Dom id of the container element
      def google_visualization(type, url = nil, options = {})
        # extract options that are not meant for the javascript part
        container_id = options.delete(:container_id) || "google_#{type.underscore}"

        # camelize option keys
        js_options = options.to_a.inject({}) { |memo, opt| memo[opt.first.to_s.camelize(:lower)] = opt.last; memo }
        
        url ||= url_for(:format => 'datasource')
        html = content_tag(:div, :id => container_id) { }
        html << javascript_tag("DataSource.Visualization.create('#{type.camelize}', '#{url}', '#{container_id}', #{js_options.to_json});")

        html << reporting_controls(container_id, options)
        html
      end

      def reporting_controls(container_id, options)
        html = tag(:div, {:id => "#{container_id}_controls", :class => "data_source_controls"}, true)

        # Add Export links
        unless options[:exportable_as].nil? || options[:exportable_as].empty?
          html << tag(:div, {:id => "#{container_id}_export_as"}, true)
          html << t('google_data_source.export_links.export_as')
          html << ' '
          options[:exportable_as].each do |format|
            html << google_datasource_export_link(format)
          end
          html << ActiveSupport::SafeBuffer.new("</div>")
        end

        html << ActiveSupport::SafeBuffer.new("</div>") # ugly, any ideas?
        html
      end

      # Returns a export link for the given format
      def google_datasource_export_link(format)
        label = t("google_data_source.export_links.#{format}")
        link_to(label, '#', :class => "export_as_#{format}")
      end

      # Shows a Google data table
      def google_datatable(url = nil, options = {})
        google_visualization('Table', url, options)
      end

      # Shows a Google annotated timeline
      def google_timeline(url = nil, options = {})
        google_visualization('TimeLine', url, options)
      end
    end
  end
end
