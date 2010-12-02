# Learn more: http://github.com/javan/whenever

job_type :runner,  "cd :path && rails runner -e :environment ':task' :output"

env :MAILTO, 'webmaster@openneo.net'

every :day do
  runner "Item.spider_mall!"
end

ItemsLimit = 20
every :hour do
  runner "Item.spider_mall_assets! #{ItemsLimit}"
end
