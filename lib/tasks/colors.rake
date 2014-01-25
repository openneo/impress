namespace :colors do
  desc 'Create a color'
  task :create, [:id, :name, :standard, :basic, :prank] => :environment do |t, args|
    args.with_defaults(standard: true, basic: false, prank: false)
    # TIL: ActiveRecord will convert strings to booleans automatically. Cool.
    color = Color.new
    color.id = args[:id]
    color.name = args[:name]
    color.standard = args[:standard]
    color.basic = args[:basic]
    color.prank = args[:prank]
    color.save!
    puts "Color #{color.inspect} created"
  end
end
