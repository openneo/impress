class DonationFeature < ActiveRecord::Base
  belongs_to :donation
  belongs_to :outfit

  validates :outfit, presence: true, if: :outfit_id?

  delegate :donor_name, to: :donation

  def as_json(options={})
    {donor_name: donor_name, outfit_image_url: outfit.image.medium.url}
  end

  def outfit_url=(outfit_url)
    self.outfit_id = outfit_url.split('/').last rescue nil
  end
end
