class CampaignsController < ApplicationController
  def show
    @campaign = Campaign.find(params[:id])
    redirect_to(action: :current) if @campaign.active?
    @donations = find_donations
  end

  def current
    @campaign = Campaign.current
    @donations = find_donations
    render action: :show
  end

  private

  def find_donations
    @donations = @campaign.donations.includes(features: :outfit).
      order('created_at DESC')
  end
end
