# We replace Neopets::CustomPets methods with a mocked implementation.
module Neopets::CustomPets
  DATA_DIR = Pathname.new(__dir__) / "custom_pets"

  def self.fetch_viewer_data(pet_name, ...)
    # NOTE: Windows doesn't support `@` in filenames, so we use a `scis` directory instead.
    path = if pet_name.start_with?('@')
      DATA_DIR / "scis" / "#{pet_name[1..]}.json"
    else
      DATA_DIR / "#{pet_name}.json"
    end

    File.open(path) { |f| HashWithIndifferentAccess.new JSON.load(f) }
  end

  def self.fetch_metadata(...)
    raise NotImplementedError
  end

  def self.fetch_image_hash(pet_name, ...)
    "m:#{pet_name}"[0, 8] # A mock hash, like `m:thyass` for "thyassa".
  end
end
