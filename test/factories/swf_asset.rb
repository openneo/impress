Factory.define :swf_asset do |s|
  s.url 'http://images.neopets.com/cp/bio/swf/000/000/000/0000_a1b2c3d4e5.swf'
  s.zone_id 0
  s.zones_restrict ''
  s.body_id 0
  s.add_attribute :type, 'object'
  s.sequence(:id) { |n| n }
end
