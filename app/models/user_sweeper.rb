class UserSweeper < ActionController::Caching::Sweeper
  observe User
  def after_update(user)
    # Delegate null-list sweeping to the ClosetListObserver.
    null_lists = [true, false].map { |owned| user.null_closet_list(owned) }
    null_lists.each { |list| ClosetListObserver.instance.after_update(list) }
  end
end
