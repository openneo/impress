class SwfAsset < ActiveRecord::Base
  set_inheritance_column 'inheritance_type'
  
  belongs_to :zone
  
  delegate :depth, :to => :zone
  
  scope :for_json, includes(:zone)
  scope :fitting_body_id, lambda { |body_ids|
    body_ids = [body_ids] unless body_ids.is_a?(Array)
    body_ids << 0
    where(arel_table[:body_id].in(body_ids))
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
      :body_id => body_id
    }
  end
end
