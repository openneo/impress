class DonationFeaturesController < ApplicationController
  def index
    # TODO: scope by campaign?
    @features = DonationFeature.includes(:donation).includes(:outfit).
      where('outfit_id IS NOT NULL')
    render json: @features
  end
end
