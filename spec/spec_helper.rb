# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
ENV["RAILS_ENV"] ||= 'test'
require File.dirname(__FILE__) + "/../config/environment" unless defined?(Rails)
require 'rspec/rails'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

Rspec.configure do |config|
  # == Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
  config.mock_with :rspec

  # If you'd prefer not to run each of your examples within a transaction,
  # uncomment the following line.
  # config.use_transactional_examples = false
  
  def query_should(query, sets)
    sets.each { |k,v| sets[k] = v.map { |x| x.is_a?(Array) ? x : [x, ''] } }
    all_sets = sets[:return] + sets[:not_return]
    all_sets.each { |s| Factory.create :item, :name => s[0], :description => s[1]}
    returned_sets = Item.search(query).all.map { |i| [i.name, i.description] }.sort
    returned_sets.should == sets[:return].sort
  end
end
