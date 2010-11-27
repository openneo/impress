namespace :items do
  desc "Spider NC Mall for wearable items, and store them for later asset spidering"
  task :spider_mall => :environment do
    Item.spider_mall!
  end
  
  desc "Spider NC Mall for assets for NC Mall items we've already collected"
  task :spider_mall_assets => :environment do
    Item.spider_mall_assets!(ENV['LIMIT'] || 100)
  end
end
