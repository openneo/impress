class CampaignsController < ApplicationController
  def show
    @campaign = Campaign.find(params[:id])
    redirect_to(action: :current) if @campaign.active?
    @donations = find_donations
    @all_campaigns = find_all_campaigns
  end

  def current
    @campaign = Campaign.current
    @donations = find_donations
    @all_campaigns = find_all_campaigns
    render action: :show
  end

  private

  def find_all_campaigns
    @all_campaigns = Campaign.order('created_at DESC').all
  end

  def find_donations
    @campaign.donations.includes(features: :outfit).order('created_at DESC')
  end
end
