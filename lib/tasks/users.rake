namespace :users do
  namespace :image_mode do

    desc "Grants given username access to image mode"
    task :add, :username, :needs => :environment do |t, args|
      user = toggle_user_image_mode(args, true)
      puts "#{user.name} has gained access to image mode"
    end

    desc "Removes given username's access to image mode"
    task :remove, :username, :needs => :environment do |t, args|
      user = toggle_user_image_mode(args, false)
      puts "#{user.name} has lost access to image mode"
    end

    def find_user(args)
      name = args[:username]
      user = User.find_by_name(name)
      raise RuntimeError, "Could not find user with name #{name.inspect}" unless user
      user
    end

    def toggle_user_image_mode(args, image_mode)
      user = find_user(args)
      user.image_mode_tester = image_mode
      user.save!
      user
    end

  end
end

