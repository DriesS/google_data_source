module GoogleDataSource
  module Reporting
    module ActionControllerExtension
      # Add the option +:reporting+ to the +render+ method.
      # Takes a +Reporting+ object and renders the data-source response
      # including the form validation results
      def render_with_reporting(*args)
        if !args.first.nil? && args.first.is_a?(Hash) && args.first.has_key?(:reporting)
          reporting = args.first[:reporting]
          datasource = GoogleDataSource::DataSource::Base.from_params(params)
          datasource.set(reporting)
          if reporting.has_form?
            datasource.callback = "$('#{reporting.form_id}').html(#{render(:partial => reporting.partial).to_json});"
          end
          render_for_text datasource.response
        else
          render_without_reporting(*args)
        end
      end
    end
  end
end
