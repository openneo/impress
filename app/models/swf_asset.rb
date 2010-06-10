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
end
