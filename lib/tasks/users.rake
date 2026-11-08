namespace :users do
  # Support tools for account requests. These use the same code paths as the
  # self-serve buttons on the Settings page, so prefer pointing users there!
  # These are for when someone can't log in to do it themselves.

  def find_auth_user!(name_or_email)
    raise ArgumentError, "usage: rake users:<task>[name_or_email]" if name_or_email.blank?
    AuthUser.find_by(name: name_or_email) ||
      AuthUser.find_by(email: name_or_email) ||
      AuthUser.find_by(neopass_email: name_or_email) ||
      raise(ActiveRecord::RecordNotFound, "no user matching #{name_or_email.inspect}")
  end

  def describe_auth_user(auth_user)
    user = auth_user.user
    puts "Name:          #{auth_user.name}"
    puts "Email:         #{auth_user.email.inspect}"
    puts "NeoPass email: #{auth_user.neopass_email.inspect}"
    puts "Created at:    #{auth_user.created_at}"
    puts "Sign-ins:      #{auth_user.sign_in_count} (last: #{auth_user.last_sign_in_at})"
    if user
      puts "Items:         #{user.closet_hangers.count} in #{user.closet_lists.count} lists"
      puts "Outfits:       #{user.outfits.count}"
      puts "Contributions: #{user.contributions.count} (#{user.points} points)"
    else
      puts "(No matching user record in the main database!)"
    end
  end

  def write_export(auth_user)
    export = AccountExport.new(auth_user)
    dir = Rails.root.join("tmp", "account-exports")
    FileUtils.mkdir_p(dir)
    path = dir.join(export.filename)
    File.write(path, export.to_json)
    path
  end

  desc "Export all of a user's data to a JSON file in tmp/account-exports"
  task :export, [:name_or_email] => :environment do |_, args|
    auth_user = find_auth_user!(args[:name_or_email])
    describe_auth_user(auth_user)
    puts "Wrote export to #{write_export(auth_user)}"
  end

  desc "Export, then permanently delete, a user's account and data"
  task :delete, [:name_or_email] => :environment do |_, args|
    auth_user = find_auth_user!(args[:name_or_email])
    describe_auth_user(auth_user)
    AccountDeletion.new(auth_user).check_allowed!

    puts "Wrote export to #{write_export(auth_user)}"

    print "\nTo permanently delete this account, type its name again: "
    confirmation = $stdin.gets&.strip
    if confirmation != auth_user.name
      puts "Name didn't match, so we won't delete anything. Goodbye!"
      next
    end

    result = AccountDeletion.new(auth_user).call
    puts "Deleted #{result.name.inspect}:"
    result.counts.each { |kind, count| puts "  - #{kind}: #{count}" }
  end
end
