class ContributionsController < ApplicationController
  def index
    if params[:user_id]
      @user = User.find params[:user_id]
      @contributions = @user.contributions
    else
      @contributions = Contribution.includes(:user)
    end
    @contributions = @contributions.recent.paginate :page => params[:page]
    Contribution.preload_contributeds_and_parents(
      @contributions,
      :scopes => {
        'Item' => Item.includes(:translations),
        'PetType' => PetType.includes({:species => :translations,
                                       :color => :translations})
      }
    )
  end
end
