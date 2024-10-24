require 'rails_helper'
require_relative '../support/mocks/custom_pets'
require_relative '../support/matchers/a_record_matching'

RSpec.describe Pet, type: :model do
  fixtures :colors, :species, :zones

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
        expect(subject.pet_type.image_hash).to eq "m:thyass"
      end

      it "has a new unlabeled Purple Chia pet state" do
        expect(subject.pet_state.new_record?).to be true
        expect(subject.pet_state.color).to eq Color.find_by_name!("purple")
        expect(subject.pet_state.species).to eq Species.find_by_name!("chia")
        expect(subject.pet_state.pose).to eq "UNKNOWN"
      end

      it "has new assets for the biology layers" do
        subject.save! # TODO: I wish this were set up before saving.

        expect(subject.pet_state.swf_assets).to contain_exactly(
          a_record_matching(
            type: "biology",
            remote_id: 10083,
            zone_id: 37,
            url: "https://images.neopets.com/cp/bio/swf/000/000/010/10083_8a1111a13f.swf",
            manifest_url: "https://images.neopets.com/cp/bio/data/000/000/010/10083_8a1111a13f/manifest.json",
            zones_restrict: "0000000000000000000000000000000000000000000000000000",
          ),
          a_record_matching(
            type: "biology",
            remote_id: 11613,
            zone_id: 15,
            url: "https://images.neopets.com/cp/bio/swf/000/000/011/11613_f7d8d377ab.swf",
            manifest_url: "https://images.neopets.com/cp/bio/data/000/000/011/11613_f7d8d377ab/manifest.json",
            zones_restrict: "0000000000000000000000000000000000000000000000000000",
          ),
          a_record_matching(
            type: "biology",
            remote_id: 14187,
            zone_id: 34,
            url: "https://images.neopets.com/cp/bio/swf/000/000/014/14187_0e65c2082f.swf",
            manifest_url: "https://images.neopets.com/cp/bio/data/000/000/014/14187_0e65c2082f/manifest.json",
            zones_restrict: "0000000000000000000000000000000000000000000000000000",
          ),
          a_record_matching(
            type: "biology",
            remote_id: 14189,
            zone_id: 33,
            url: "https://images.neopets.com/cp/bio/swf/000/000/014/14189_102e4991e9.swf",
            manifest_url: "https://images.neopets.com/cp/bio/data/000/000/014/14189_102e4991e9/manifest.json",
            zones_restrict: "0000000000000000000000000000000000000000000000000000",
          )
        )
      end
    end
  end
end
