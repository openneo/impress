class ContributionObserver < ActiveRecord::Observer
  def after_create(contribution)
    controller.expire_fragment('outfits#new latest_contribution')
  end

  private
  
  def controller
    @controller ||= ActionController::Base.new
  end
end
