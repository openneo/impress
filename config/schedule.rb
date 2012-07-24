# Learn more: http://github.com/javan/whenever

env :MAILTO, 'webmaster@openneo.net'

every :day do
  rake 'mall:spider_items'
end

every :hour do
  rake 'mall:spider_assets'
end
