class DonationsController < ApplicationController
  def create
    @campaign = Campaign.current
    begin
      @donation = Donation.create_from_charge(
        @campaign, current_user, params[:donation])
    rescue Stripe::CardError => e
      flash[:alert] = "We couldn't process your donation: #{e.message}"
      redirect_to :donate
    rescue => e
      flash[:alert] =
        "We couldn't process your donation: #{e.message} " +
        "Please try again later!"
      redirect_to :donate
    else
      redirect_to @donation
    end
  end

  def show
    @donation = Donation.from_param(params[:id])
    @features = @donation.features
    @outfits = current_user.outfits.wardrobe_order if user_signed_in?
  end

  def update
    @donation = Donation.from_param(params[:id])
    @donation.attributes = donation_params

    feature_params = params[:feature] || {}
    @features = @donation.features.find(feature_params.keys)
    @features.each do |feature|
      feature.outfit_url = feature_params[feature.id.to_s][:outfit_url]
    end

    begin
      Donation.transaction do
        @donation.save!
        @features.each(&:save!)
      end
    rescue ActiveRecord::RecordInvalid
      flash[:alert] = "Couldn't save donation details. Do those outfits exist?"
      redirect_to @donation
    else
      flash[:success] = 'Donation details saved! ' +
        'Also, have we thanked you yet today? Thank you!'
      redirect_to @donation
    end
  end

  private

  def donation_params
    params.require(:donation).permit(:donor_name)
  end
end
