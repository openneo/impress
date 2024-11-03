class Pet < ApplicationRecord
  belongs_to :pet_type

  attr_reader :items, :pet_state, :alt_style

  def load!(timeout: nil)
    viewer_data_hash = Neopets::CustomPets.fetch_viewer_data(name, timeout:)
    use_modeling_snapshot(ModelingSnapshot.new(viewer_data_hash))
  end

  def use_modeling_snapshot(snapshot)
    self.pet_type = snapshot.pet_type
    @pet_state = snapshot.pet_state
    @alt_style = snapshot.alt_style
    @items = snapshot.items
  end

  def wardrobe_query
    {
      name: self.name,
      color: self.pet_type.color_id,
      species: self.pet_type.species_id,
      pose: self.pet_state.pose,
      state: self.pet_state.id,
      objects: self.items.map(&:id),
      style: self.alt_style ? self.alt_style.id : nil,
    }.to_query
  end

  def contributables
    contributables = [pet_type, @pet_state, @alt_style].filter(&:present?)
    items.each do |item|
      contributables << item
      contributables += item.pending_swf_assets
    end
    contributables
  end

  before_validation do
    pet_type.save!
    @pet_state.save! if @pet_state
    @alt_style.save! if @alt_style
    (@items || []).each(&:save!)
  end

  def self.load(name, **options)
    pet = Pet.find_or_initialize_by(name: name)
    pet.load!(**options)
    pet
  end

  class UnexpectedDataFormat < RuntimeError;end
end

