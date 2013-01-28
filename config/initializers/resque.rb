Resque.after_fork do
  Resque.redis.client.reconnect
end
