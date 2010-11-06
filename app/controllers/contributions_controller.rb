class ContributionsController < ApplicationController
  def index
    @contributions = Contribution.recent.paginate :page => params[:page],
      :include => :user
    Contribution.preload_contributeds_and_parents @contributions
  end
end
