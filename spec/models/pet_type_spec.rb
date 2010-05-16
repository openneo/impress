require 'spec_helper'

describe PetType do
  context "object" do
    specify "should return id, body_id in JSON" do
      pet_type = PetType.create :color_id => 2, :species_id => 3, :body_id => 4
      pet_type.as_json.should == {:id => 1, :body_id => 4}
    end
  end
end
