Factory.define :zone do |z|
  z.label 'foo'
  z.depth 1
  z.add_attribute :type, 'FOO'
  z.type_id 1
end
