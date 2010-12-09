class SweeperController < ActionController::Base
  def expire_action_proxy(options)
    options[:only_path] = true
    path = Rails.application.routes.url_helpers.url_for(options)
    fragment_name = "#{LocalImpressHost}#{path}"
    expire_fragment(fragment_name)
  end
end
