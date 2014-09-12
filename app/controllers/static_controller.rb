class StaticController < ApplicationController
  def donate
    @campaign = Campaign.current
    @donations = @campaign.donations.includes(features: :outfit).
      order('created_at DESC')
  end
end
