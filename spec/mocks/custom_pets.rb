# We replace Neopets::CustomPets methods with a mocked implementation.
module Neopets::CustomPets
  def self.fetch_viewer_data(pet_name, ...)
    File.open(Rails.root / "spec/mocks/custom_pets/#{pet_name}.json") do |file|
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
