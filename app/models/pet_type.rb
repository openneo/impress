class PetType < ActiveRecord::Base
  IMAGE_CPN_FORMAT = 'http://pets.neopets.com/cpn/%s/1/1.png';
  IMAGE_CP_LOCATION_REGEX = %r{^/cp/(.+?)/1/1\.png$};
  
  has_many :pet_states
  
  attr_writer :origin_pet
  
  BasicHashes = YAML::load_file(Rails.root.join('config', 'basic_type_hashes.yml'))
  
  StandardBodyIds = PetType.select(arel_table[:body_id]).
    where(arel_table[:color_id].in(Color::BasicIds)).
    group(arel_table[:species_id]).map(&:body_id)
  
  scope :random_basic_per_species, lambda { |species_ids|
    conditions = nil
    species_ids.each do |species_id|
      color_id = Color::Basic[rand(Color::Basic.size)].id
      condition = arel_table[:species_id].eq(species_id).and(
        arel_table[:color_id].eq(color_id)
      )
      conditions = conditions ? conditions.or(condition) : condition
    end
    where(conditions).order(:species_id)
  }
  
  def as_json(options={})
    {:id => id, :body_id => body_id}
  end
  
  def color_id=(new_color_id)
    @color = nil
    write_attribute('color_id', new_color_id)
  end
  
  def color=(new_color)
    @color = new_color
    write_attribute('color_id', @color.id)
  end
  
  def color
    @color ||= Color.find(color_id)
  end
  
  def species_id=(new_species_id)
    @species = nil
    write_attribute('species_id', new_species_id)
  end
  
  def species=(new_species)
    @species = new_species
    write_attribute('species_id', @species.id)
  end
  
  def species
    @species ||= Species.find(species_id)
  end
  
  def image_hash
    BasicHashes[species.name][color.name]
  end
  
  def add_pet_state_from_biology!(biology)
    pet_state = PetState.from_pet_type_and_biology_info(self, biology)
    self.pet_states << pet_state
    pet_state
  end
  
  before_save do
    if @origin_pet
      cpn_uri = URI.parse sprintf(IMAGE_CPN_FORMAT, @origin_pet.name);
      res = Net::HTTP.get_response(cpn_uri)
      unless res.is_a? Net::HTTPFound
        begin
          res.error!
        rescue Exception => e
          raise "Error loading CPN image at #{cpn_uri}: #{e.message}"
        else
          raise "Error loading CPN image at #{cpn_uri}. Response: #{res.inspect}"
        end
      end
      new_url = res['location']
      match = new_url.match(IMAGE_CP_LOCATION_REGEX)
      if match
        self.image_hash = match[1]
      else
        raise "CPN image pointed to #{new_url}, which does not match CP image format"
      end
    end
  end
end
