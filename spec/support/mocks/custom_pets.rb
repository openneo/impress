# We replace Neopets::CustomPets methods with a mocked implementation.
module Neopets::CustomPets
  DATA_DIR = Pathname.new(__dir__) / "custom_pets"

  def self.fetch_viewer_data(pet_name, ...)
    File.open(DATA_DIR / "#{pet_name}.json") do |file|
      HashWithIndifferentAccess.new JSON.load(file)
    end
  end

  def self.fetch_metadata(...)
    raise NotImplementedError
  end

  def self.fetch_image_hash(pet_name, ...)
    "m:#{pet_name}"[0, 8] # A mock hash, like `m:thyass` for "thyassa".
  end
end
