class ContributionObserver < ActiveRecord::Observer
  def after_create(contribution)
    controller.expire_fragment('outfits#new latest_contribution')
    
    if contribution.contributed_type == 'SwfAsset'
      item = contribution.contributed.item
      controller.expire_fragment("items/#{item.id} contributors")
    end
  end

  private
  
  def controller
    @controller ||= ActionController::Base.new
  end
end
