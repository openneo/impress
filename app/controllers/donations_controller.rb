class DonationsController < ApplicationController
  def create
    @donation = Donation.create_from_charge(current_user, params[:donation])
    redirect_to @donation
  end

  def show
    @donation = Donation.from_param(params[:id])
  end

  def update
    @donation = Donation.from_param(params[:id])
    @donation.update_attributes params[:donation]
    @donation.save!

    flash[:success] = 'Donation details saved! ' +
      'Also, have we thanked you yet today? Thank you!'
    redirect_to @donation
  end
end
