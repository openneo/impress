class ContributionObserver < ActiveRecord::Observer
  include FragmentExpiration
  
  def after_create(contribution)
    expire_fragment_in_all_locales('outfits#new latest_contribution')
    
    if contribution.contributed_type == 'SwfAsset'
      item = contribution.contributed.item
      expire_fragment_in_all_locales("items/#{item.id} contributors")
    end
  end
end
