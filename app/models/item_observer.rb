class ItemObserver < ActionController::Caching::Sweeper
  def after_create(item)
    Resque.enqueue(Item::CreateTask, item.id)
  end
  
  def after_update(item)
    # CONSIDER: can pass item.changes.keys in to choose which caches to expire
    Resque.enqueue(Item::UpdateTask, item.id)
  end

  def after_destroy(item)
    Resque.enqueue(Item::DestroyTask, item.id)
  end
end
