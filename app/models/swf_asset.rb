class SwfAsset < ActiveRecord::Base
  set_inheritance_column 'inheritance_type'
  
  delegate :depth, :to => :zone
  
  scope :fitting_body_id, lambda { |body_id|
    where(arel_table[:body_id].in([body_id, 0]))
  }
  
  BodyIdsFittingStandard = PetType::StandardBodyIds + [0]
  scope :fitting_standard_body_ids, lambda {
    where(arel_table[:body_id].in(BodyIdsFittingStandard))
  }
  
  def local_url
    uri = URI.parse(url)
    uri.host = RemoteImpressHost
    pieces = uri.path.split('/')
    uri.path = "/assets/swf/outfit/#{pieces[2]}/#{pieces[4..7].join('/')}"
    uri.to_s
  end
  
  def as_json(options={})
    {
      :id => id,
      :depth => depth,
      :local_url => local_url,
      :body_id => body_id,
      :zone_id => zone_id
    }
  end
  
  def zone
    @zone ||= Zone.find(zone_id)
  end
  
  def origin_pet_type=(pet_type)
    self.body_id = pet_type.body_id
  end
  
  def origin_biology_data=(data)
    self.type = 'biology'
    self.zone_id = data[:zone_id].to_i
    self.url = data[:asset_url]
    self.zones_restrict = data[:zones_restrict]
  end
  
  def origin_object_data=(data)
    self.type = 'object'
    self.zone_id = data[:zone_id].to_i
    self.url = data[:asset_url]
  end
end
