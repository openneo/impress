namespace :users do
  # Support tools for account requests. These use the same code paths as the
  # self-serve buttons on the Settings page, so prefer pointing users there!
  # These are for when someone can't log in to do it themselves.

  # Find the one account matching this name or email. If it's ambiguous (e.g.
  # someone registered a username that looks like another person's email), we
  # refuse, so support doesn't act on the wrong account by accident.
  def find_auth_user!(name_or_email)
    raise ArgumentError, "usage: rake users:<task>[name_or_email]" if name_or_email.blank?
    t = AuthUser.arel_table
    matches = AuthUser.where(t[:name].eq(name_or_email).
      or(t[:email].eq(name_or_email)).
      or(t[:neopass_email].eq(name_or_email))).to_a
    if matches.empty?
      raise ActiveRecord::RecordNotFound, "no user matching #{name_or_email.inspect}"
    elsif matches.size > 1
      raise "#{matches.size} users match #{name_or_email.inspect}: " +
        matches.map { |u| "#{u.name} (email #{u.email.inspect}, " +
          "neopass #{u.neopass_email.inspect})" }.join(", ") +
        ". Use a more specific value!"
    end
    matches.first
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
    export = AuthUser::DataExport.new(auth_user)
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
    puts "Once you've sent it to them, delete it!"
  end

  desc "Export, then permanently delete, a user's account and data"
  task :delete, [:name_or_email] => :environment do |_, args|
    auth_user = find_auth_user!(args[:name_or_email])
    describe_auth_user(auth_user)
    AuthUser::Deletion.new(auth_user).check_allowed!

    puts "Wrote export to #{write_export(auth_user)}"

    print "\nTo permanently delete this account, type its name again: "
    confirmation = $stdin.gets&.strip
    if !confirmation&.casecmp?(auth_user.name)
      puts "Name didn't match, so we won't delete anything. Goodbye!"
      next
    end

    result = AuthUser::Deletion.new(auth_user).call
    puts "Deleted #{result.name.inspect}:"
    result.counts.each { |kind, count| puts "  - #{kind}: #{count}" }
    puts "\nOnce you've sent the export to them, delete it from tmp/account-exports!"
  end
end
