require 'rails_helper'
require_relative '../mocks/custom_pets'

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

        s = subject.pet_state.swf_assets.sort_by(&:id)

        expect(s.size).to eq 4
        expect(s[0].type).to eq "biology"
        expect(s[0].remote_id).to eq 10083
        expect(s[0].zone_id).to eq 37
        expect(s[0].url).to eq "https://images.neopets.com/cp/bio/swf/000/000/010/10083_8a1111a13f.swf"
        expect(s[0].manifest_url).to eq "https://images.neopets.com/cp/bio/data/000/000/010/10083_8a1111a13f/manifest.json"
        expect(s[0].zones_restrict).to eq "0000000000000000000000000000000000000000000000000000"
        expect(s[1].type).to eq "biology"
        expect(s[1].remote_id).to eq 11613
        expect(s[1].zone_id).to eq 15
        expect(s[1].url).to eq "https://images.neopets.com/cp/bio/swf/000/000/011/11613_f7d8d377ab.swf"
        expect(s[1].manifest_url).to eq "https://images.neopets.com/cp/bio/data/000/000/011/11613_f7d8d377ab/manifest.json"
        expect(s[1].zones_restrict).to eq "0000000000000000000000000000000000000000000000000000"
        expect(s[2].type).to eq "biology"
        expect(s[2].remote_id).to eq 14187
        expect(s[2].zone_id).to eq 34
        expect(s[2].url).to eq "https://images.neopets.com/cp/bio/swf/000/000/014/14187_0e65c2082f.swf"
        expect(s[2].manifest_url).to eq "https://images.neopets.com/cp/bio/data/000/000/014/14187_0e65c2082f/manifest.json"
        expect(s[2].zones_restrict).to eq "0000000000000000000000000000000000000000000000000000"
        expect(s[3].type).to eq "biology"
        expect(s[3].remote_id).to eq 14189
        expect(s[3].zone_id).to eq 33
        expect(s[3].url).to eq "https://images.neopets.com/cp/bio/swf/000/000/014/14189_102e4991e9.swf"
        expect(s[3].manifest_url).to eq "https://images.neopets.com/cp/bio/data/000/000/014/14189_102e4991e9/manifest.json"
        expect(s[3].zones_restrict).to eq "0000000000000000000000000000000000000000000000000000"        
      end
    end
  end
end
