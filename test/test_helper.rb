ENV["RAILS_ENV"] = "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...
end

# We replace Neopets::CustomPets methods with a mocked implementation.
module Neopets::CustomPets
  def self.fetch_viewer_data(pet_name, ...)
    File.open(Rails.root / "test/mocks/custom_pets/#{pet_name}.json") do |file|
      HashWithIndifferentAccess.new JSON.load(file)
    end
  end

  def self.fetch_metadata(...)
    raise NotImplementedError
  end

  def self.fetch_image_hash(pet_name, ...)
    "mock-image-hash:#{pet_name}"
  end
end
