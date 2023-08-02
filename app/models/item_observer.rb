class ItemObserver < ActionController::Caching::Sweeper
  def after_create(item)
    Resque.enqueue(Item::CreateTask, item.id)
  end

  def after_destroy(item)
    Resque.enqueue(Item::DestroyTask, item.id)
  end
end
