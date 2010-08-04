module GoogleDataSource
  module Helper
    def google_data_source_includes
      html  = '<script type="text/javascript" src="http://www.google.com/jsapi"></script>'
      html << javascript_include_tag('google_datatable')
      html
    end

    def google_visualization(type, url = nil, options = {})
      # extract options that are not meant for the javascript part
      container_id = options.delete(:container_id) || "google_#{type.underscore}"

      # camelize option keys
      js_options = options.to_a.inject({}) {|memo, opt| memo[opt.first.to_s.camelize(:lower)] = opt.last; memo}

      url ||= url_for(:format => 'datasource')
      html = javascript_tag("DataSource.Visualization.create('#{type.camelize}', '#{url}', '#{container_id}', #{js_options.to_json});")
      html << content_tag(:div, :id => container_id) { }
      html
    end

    def google_datatable(url = nil, options = {})
      google_visualization('Table', url, options)
    end

    def google_timeline(url = nil, options = {})
      google_visualization('TimeLine', url, options)
    end
  end
end
