class UserSweeper < ActionController::Caching::Sweeper
  observe User
  
  def before_save(user)
    if user.points_changed?
      points_to_beat = User.points_required_to_pass_top_contributor(User::PreviewTopContributorsCount - 1)
      if user.points >= points_to_beat
        expire_fragment(:controller => 'outfits', :action => 'new', :action_suffix => 'top_contributors')
      end
    end
    true
  end
end
