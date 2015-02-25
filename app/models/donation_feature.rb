class DonationFeature < ActiveRecord::Base
  belongs_to :donation
  belongs_to :outfit

  validates :outfit, presence: true, if: :outfit_id_present?

  delegate :donor_name, to: :donation

  def as_json(options={})
    {donor_name: donor_name, outfit_image_url: outfit_image_url}
  end

  def outfit_url=(outfit_url)
    self.outfit_id = outfit_url.split('/').last rescue nil
  end

  def outfit_id_present?
    outfit_id.present?
  end

  def outfit_image_url
    outfit && outfit.image ? outfit.image.medium.url : nil
  end
end
