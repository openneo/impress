class DonationFeature < ActiveRecord::Base
  belongs_to :donation
  belongs_to :outfit

  validates :outfit, presence: true, if: :outfit_id?

  def outfit_url=(outfit_url)
    self.outfit_id = outfit_url.split('/').last rescue nil
  end
end
