namespace :mall do
  desc 'Spider NC Mall for new items'
  task :spider_items => :environment do
    Item.spider_mall!
  end
  
  desc 'Spider NC Mall for item assets'
  task :spider_assets => :environment do
    item_limit = ENV['ITEM_LIMIT'] || 20
    Item.spider_mall_assets!(item_limit)
  end
end
