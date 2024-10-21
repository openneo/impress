require 'rails_helper'
require_relative '../mocks/custom_pets'

RSpec.describe Pet, type: :model do
  context "#load" do
    context "for thyassa, the Purple Chia" do
      subject { Pet.load "thyassa" }

      it "is named thyassa" do
        expect(subject.name).to eq("thyassa")
      end

      it "has a new Purple Chia pet type" do
        expect(subject.pet_type.new_record?).to be true
        expect(subject.pet_type.color).to eq Color.find_by_name!("purple")
        expect(subject.pet_type.species).to eq Species.find_by_name!("chia")
        expect(subject.pet_type.body_id).to eq 212
        expect(subject.pet_type.image_hash).to eq "mock-image-hash:thyassa"
      end

      it "has a new unlabeled Purple Chia pet state" do
        expect(subject.pet_state.new_record?).to be true
        expect(subject.pet_state.color).to eq Color.find_by_name!("purple")
        expect(subject.pet_state.species).to eq Species.find_by_name!("chia")
        expect(subject.pet_state.pose).to eq "UNKNOWN"
      end
    end
  end
end
