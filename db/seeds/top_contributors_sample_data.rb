# Sample contributions for testing Top Contributors feature
# Run with: rails runner db/seeds/top_contributors_sample_data.rb

puts "Creating sample contributions for Top Contributors testing..."

# Find or create test users
users = []
5.times do |i|
  name = "TestContributor#{i + 1}"
  user = User.find_or_create_by!(name: name) do |u|
    # Create a corresponding auth_user record
    auth_user = AuthUser.create!(
      name: name,
      email: "test#{i + 1}@example.com",
      password: 'password123',
    )
    u.remote_id = auth_user.id
    u.auth_server_id = 1
  end
  users << user
end

# Get some existing items/pet types to contribute
items = Item.limit(10).to_a
pet_types = PetType.limit(5).to_a
swf_assets = SwfAsset.limit(5).to_a

if items.empty? || pet_types.empty?
  puts "WARNING: No items or pet types found. Create some first or contributions will be limited."
end

# Create contributions with different time periods
# User 1: Heavy contributor this week
if items.any?
  3.times { Contribution.create!(user: users[0], contributed: items.sample, created_at: 2.days.ago) }
  5.times { Contribution.create!(user: users[0], contributed: items.sample, created_at: 5.days.ago) }
end

# User 2: Heavy contributor this month, but not this week
if items.any? && pet_types.any?
  2.times { Contribution.create!(user: users[1], contributed: items.sample, created_at: 15.days.ago) }
  1.times { Contribution.create!(user: users[1], contributed: pet_types.sample, created_at: 20.days.ago) }
end

# User 3: Heavy contributor this year, but not this month
if pet_types.any?
  3.times { Contribution.create!(user: users[2], contributed: pet_types.sample, created_at: 3.months.ago) }
end

# User 4: Old contributor (only in all-time)
if items.any?
  users[3].update!(points: 500) # Set points directly for all-time view
  2.times { Contribution.create!(user: users[3], contributed: items.sample, created_at: 2.years.ago) }
end

# User 5: Mixed contributions across all periods
if items.any? && pet_types.any?
  Contribution.create!(user: users[4], contributed: items.sample, created_at: 1.day.ago)
  Contribution.create!(user: users[4], contributed: pet_types.sample, created_at: 10.days.ago)
  Contribution.create!(user: users[4], contributed: items.sample, created_at: 2.months.ago)
end
if swf_assets.any?
  Contribution.create!(user: users[4], contributed: swf_assets.sample, created_at: 4.days.ago)
end

puts "Created sample contributions:"
puts "- #{users[0].name}: #{users[0].contributions.count} contributions (focus: this week)"
puts "- #{users[1].name}: #{users[1].contributions.count} contributions (focus: this month)"
puts "- #{users[2].name}: #{users[2].contributions.count} contributions (focus: this year)"
puts "- #{users[3].name}: #{users[3].contributions.count} contributions (focus: all-time, #{users[3].points} points)"
puts "- #{users[4].name}: #{users[4].contributions.count} contributions (mixed periods)"
puts "\nTest the feature at: http://localhost:3000/users/top-contributors"
