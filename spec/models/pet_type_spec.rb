require 'spec_helper'

describe PetType do
  context "object" do
    specify "should return id, body_id in JSON" do
      pet_type = PetType.create :color_id => 2, :species_id => 3, :body_id => 4
      pet_type.as_json.should == {:id => 1, :body_id => 4}
    end
    
    specify "should allow setting species object" do
      pet_type = PetType.new
      pet_type.species = Species.find(1)
      pet_type.species_id.should == 1
      pet_type.species.id.should == 1
      pet_type.species.name.should == 'acara'
    end
    
    specify "should allow setting color object" do
      pet_type = PetType.new
      pet_type.color = Color.find(1)
      pet_type.color_id.should == 1
      pet_type.color.id.should == 1
      pet_type.color.name.should == 'alien'
    end
    
    specify "should return image hash if a basic color" do
      blue = Color.find_by_name('blue')
      acara = Species.find_by_name('acara')
      pet_type = PetType.new :color => blue, :species => acara
      pet_type.image_hash.should == 'mnbztxxn'
    end
    
    specify "should return nil if not a basic color" do
      asparagus = Color.find_by_name('asparagus')
      acara = Species.find_by_name('acara')
      pet_type = PetType.new :color => asparagus, :species => acara
      pet_type.image_hash.should be nil
    end
  end
end
