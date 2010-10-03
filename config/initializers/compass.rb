require 'compass'
rails_root = Rails.root.to_s
Compass.add_project_configuration(Rails.root.join(rails_root, "config", "compass.rb"))
Compass.configure_sass_plugin!
Compass.handle_configuration_change!
