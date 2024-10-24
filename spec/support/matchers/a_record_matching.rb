RSpec::Matchers.define :a_record_matching do |expected|
  match do |actual|
    expected.all? do |attr_name, expected_value|
      actual.read_attribute(attr_name) == expected_value
    end
  end
end
