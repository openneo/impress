require 'rails_helper'
require_relative '../support/mocks/custom_pets'
require_relative '../support/matchers/a_record_matching'

RSpec.describe Pet, type: :model do
  fixtures :colors, :species, :zones

  context "#load" do
    context "for thyassa, the Purple Chia" do
      subject(:pet) { Pet.load "thyassa" }

      it("is named thyassa") { expect(pet.name).to eq("thyassa") }
      it("has no items") { expect(pet.items).to be_empty }

      describe "its pet type" do
        subject(:pet_type) { pet.pet_type }

        it("is new and unsaved") { should be_new_record }
        it("is Purple") { expect(pet_type.color).to eq Color.find_by_name!("purple") }
        it("is a Chia") { expect(pet_type.species).to eq Species.find_by_name!("chia") }
        it("has the standard Chia body") { expect(pet_type.body_id).to eq 212 }
        it("uses the pet's image hash") { expect(pet_type.image_hash).to eq "m:thyass" }

        it("is saved when saving the pet") do
          expect { pet.save! }.to change { pet_type.persisted? }.from(false).to(true)
        end
      end

      describe "its pet state" do
        subject(:pet_state) { pet.pet_state }

        it("is new and unsaved") { should be_new_record }
        it("belongs to the pet's pet type") { expect(pet_state.pet_type).to eq pet.pet_type }
        it("isn't labeled yet") { expect(pet_state.pose).to eq "UNKNOWN" }

        it "is saved when saving the pet" do
          expect { pet.save! }.to change { pet_state.persisted? }.from(false).to(true)
        end

        it "has new biology assets" do
          pet.save! # TODO: I wish this were set up before saving.

          expect(pet_state.swf_assets).to contain_exactly(
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

      context "when modeled a second time" do
        before { pet.save! }
        subject!(:new_pet) { Pet.load("thyassa") }

        describe "its pet type" do
          subject(:pet_type) { new_pet.pet_type }

          it("already exists") { should be_persisted }
          it("is the same as before") { should eq pet.pet_type }
          it "is not changed when saving the pet" do
            expect { new_pet.save! }.not_to change { pet_type.attributes }
          end
        end

        describe "its pet state" do
          subject(:pet_state) { new_pet.pet_state }

          it("already exists") { should be_persisted }
          it("is the same as before") { should eq pet.pet_state }
          it "is not changed when saving the pet" do
            expect { new_pet.save! }.not_to change { pet_state.attributes }
          end
        end
      end
    end
  end
end
