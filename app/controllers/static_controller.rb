class StaticController < ApplicationController
  def donate
    # TODO: scope by campaign?
    @donations = Donation.includes(features: :outfit).order('created_at DESC')
  end
end
