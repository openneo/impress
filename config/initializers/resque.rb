# Sometimes the Resque workers have trouble maintaining their connections to
# Redis and to the database. It's not entirely clear when and why (though the
# internet suggests that it has to do with lying dormant for too long), but
# this fix ensures that Redis and the database are available at the start of
# every job.
Resque.after_fork do
  Resque.redis.client.reconnect
  ActiveRecord::Base.connection_handler.verify_active_connections!
end
