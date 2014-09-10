class DonationsController < ApplicationController
  def create
    @donation = Donation.create_from_charge(current_user, params[:donation])
    render text: @donation.inspect
  end
end
