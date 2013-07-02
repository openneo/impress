Rack::Attack.throttle('pets/ip', limit: 10, period: 1.minute) do |req|
  Rails.logger.debug "Pets hit? #{req.path.inspect} #{req.ip.inspect}"
  req.ip if req.path.start_with?('/pets/load')
end

PETS_THROTTLE_MESSAGE = "We've received a lot of pet names from you " +
                        "recently, so we're giving our servers a break. Try " +
                        "again in a minute or so. Thanks!"

Rack::Attack.throttled_response = lambda do |env|
  if env['rack.attack.matched'] == 'pets/ip'
    req = ActionDispatch::Request.new(env)
    if req.path.end_with?('.json')
      [503, {}, [PETS_THROTTLE_MESSAGE]]
    else
      flash = req.flash
      flash[:warning] = PETS_THROTTLE_MESSAGE
      [302, {"Location" => "/"}, [PETS_THROTTLE_MESSAGE]]
    end
  else
    [503, {}, ["Retry later"]]
  end
end