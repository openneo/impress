require 'rails_helper'
require_relative '../support/mocks/custom_pets'
require_relative '../support/matchers/a_record_matching'

RSpec.describe Pet, type: :model do
  fixtures :colors, :species, :zones

  context ".load" do
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
        it("is saved when saving the pet") { pet.save!; should be_persisted }
      end

      describe "its pet state" do
        subject(:pet_state) { pet.pet_state }

        it("is new and unsaved") { should be_new_record }
        it("belongs to the pet's pet type") { expect(pet_state.pet_type).to eq pet.pet_type }
        it("isn't labeled yet") { expect(pet_state.pose).to eq "UNKNOWN" }
        it("is saved when saving the pet") { pet.save!; should be_persisted }

        describe "its biology assets" do
          subject(:biology_assets) { pet_state.swf_assets }
          let(:asset_ids) { biology_assets.map(&:remote_id) }

          they("are all new") { should all be_new_record }
          they("match the expected IDs") do
            expect(asset_ids).to contain_exactly(10083, 11613, 14187, 14189)
          end
          they("are saved when saving the pet") { pet.save!; should all be_persisted }
          they("have the expected asset metadata") do
            should contain_exactly(
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

      context "when modeled a second time" do
        before { pet.save! }
        subject!(:new_pet) { Pet.load("thyassa") }

        describe "its pet type" do
          subject(:pet_type) { new_pet.pet_type }

          it("already exists") { should be_persisted }
          it("is the same as before") { should eq pet.pet_type }
          it "is not changed when saving the pet" do
            new_pet.save!; expect(pet_type.previous_changes).to be_empty
          end
        end

        describe "its pet state" do
          subject(:pet_state) { new_pet.pet_state }

          it("already exists") { should be_persisted }
          it("is the same as before") { should eq pet.pet_state }
          it "is not changed when saving the pet" do
            new_pet.save!; expect(pet_state.previous_changes).to be_empty
          end
        end

        describe "its biology assets" do
          subject(:biology_assets) { new_pet.pet_state.swf_assets }

          they("already exist") { should all be_persisted }
          they("are the same as before") { should eq pet.pet_state.swf_assets }
          they("are not changed when saving the pet") do
            new_pet.save!; expect(biology_assets.map(&:previous_changes)).to all be_empty
          end
        end
      end

      context "when modeled again, but happy" do
        before { pet.save! }
        subject(:new_pet) { Pet.load("thyassa:happy") }

        describe "its pet type" do
          subject(:pet_type) { new_pet.pet_type }

          it("already exists") { should be_persisted }
          it("is the same as before") { should eq pet.pet_type }
          it "is not changed when saving the pet" do
            new_pet.save!; expect(pet_type.previous_changes).to be_empty
          end
        end

        describe "its pet state" do
          subject(:pet_state) { new_pet.pet_state }

          it("is new and unsaved") { should be_new_record }
          it("belongs to the same pet type") { expect(pet_state.pet_type).to eq pet.pet_type }
          it("isn't labeled yet") { expect(pet_state.pose).to eq "UNKNOWN" }
          it("is saved when saving the pet") { new_pet.save!; should be_persisted }

          describe "its biology assets" do
            subject(:biology_assets) { pet_state.swf_assets }
            let(:asset_ids) { biology_assets.map(&:remote_id) }
            let(:persisted_asset_ids) {
              biology_assets.select(&:persisted?).map(&:remote_id)
            }
            let(:new_asset_ids) {
              biology_assets.select(&:new_record?).map(&:remote_id)
            }

            they("are partially new, partially existing") do
              expect(persisted_asset_ids).to contain_exactly(10083, 11613)
              expect(new_asset_ids).to contain_exactly(10448, 10451)
            end
            they("match the expected IDs") do
              expect(asset_ids).to contain_exactly(10083, 11613, 10448, 10451)
            end
            they("are saved when saving the pet") { new_pet.save!; should all be_persisted }
            they("have the expected asset metadata") do
              should contain_exactly(
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
                  remote_id: 10448,
                  zone_id: 34,
                  url: "https://images.neopets.com/cp/bio/swf/000/000/010/10448_0b238e79e2.swf",
                  manifest_url: "https://images.neopets.com/cp/bio/data/000/000/010/10448_0b238e79e2/manifest.json",
                  zones_restrict: "0000000000000000000000000000000000000000000000000000",
                ),
                a_record_matching(
                  type: "biology",
                  remote_id: 10451,
                  zone_id: 33,
                  url: "https://images.neopets.com/cp/bio/swf/000/000/010/10451_cd4a8a8e47.swf",
                  manifest_url: "https://images.neopets.com/cp/bio/data/000/000/010/10451_cd4a8a8e47/manifest.json",
                  zones_restrict: "0000000000000000000000000000000000000000000000000000",
                )
              )
            end
          end
        end
      end
    end

    context "for matts_bat, a pet with basic items" do
      subject(:pet) { Pet.load("matts_bat") }

      # We do simpler checks for biology, and trust the Thyassa case to cover it.
      it("is named matts_bat") { expect(pet.name).to eq "matts_bat" }
      it("is a Striped Blumaroo") { expect(pet.pet_type.human_name).to eq "Striped Blumaroo" }

      describe "its biology assets" do
        subject(:biology_assets) { pet.pet_state.swf_assets }
        let(:asset_ids) { biology_assets.map(&:remote_id) }

        they("are all new") { should all be_new_record }
        they("match the expected IDs") do
          expect(asset_ids).to contain_exactly(331, 332, 333, 23760, 23411)
        end
        they("are saved when saving the pet") { pet.save!; should all be_persisted }
      end

      describe "its items" do
        subject(:items) { pet.items }
        let(:item_ids) { items.map(&:id) }
        let(:compatible_body_ids) { items.to_h { |i| [i.id, i.compatible_body_ids] } }

        they("are all new") { should all be_new_record }
        they("match the expected IDs") do
          expect(item_ids).to contain_exactly(39552, 53874, 71706)
        end
        they("are saved when saving the pet") { pet.save! ; should all be_persisted }
        they("have the expected item metadata") do
          should contain_exactly(
            a_record_matching(
              id: 39552,
              name: "Springy Eye Glasses",
              description: "Hey, keep your eyes in your head!",
              thumbnail_url: "https://images.neopets.com/items/mall_springyeyeglasses.gif",
              category: "Clothes",
              type: "Clothes",
              rarity: "Artifact",
              rarity_index: 500,
              price: 0,
              weight_lbs: 1,
              species_support_ids: "3",
              zones_restrict: "0000000000000000000000000000000000000000000000000000",
            ),
            a_record_matching(
              id: 53874,
              name: "404 Shirt",
              description: "When Neopets is down, the shirt comes on!",
              thumbnail_url: "https://images.neopets.com/items/clo_404_shirt.gif",
              category: "Clothes",
              type: "Clothes",
              rarity: "Rare",
              rarity_index: 88,
              price: 1701,
              weight_lbs: 1,
              species_support_ids: "3",
              zones_restrict: "0000000000000000000000000000000000000000000000000000",
            ),
            a_record_matching(
              id: 71706,
              name: "On the Roof Background",
              description: "Who is that on the roof?! Could it be...?",
              thumbnail_url: "https://images.neopets.com/items/gif_roof_onthe_fg.gif",
              category: "Special",
              type: "Mystical Surroundings",
              rarity: "Special",
              rarity_index: 101,
              price: 0,
              weight_lbs: 1,
              species_support_ids: "",
              zones_restrict: "0000000000000000000000000000000000000000000000000000",
            ),
          )
        end
        they("should be marked compatible with this pet's body ID") do
          pet.save!
          expect(compatible_body_ids).to eq(
            39552 => [47],
            53874 => [47],
            71706 => [0],
          )
        end
      end

      context "its item assets" do
        let(:assets_by_item) { pet.items.to_h { |item| [item.id, item.swf_assets.to_a] } }
        subject(:item_assets) { assets_by_item.values.flatten(1) }
        let(:asset_ids) { item_assets.map(&:remote_id) }

        they("are all new") { should all be_new_record }
        they("match the expected IDs") do
          expect(asset_ids).to contain_exactly(16933, 108567, 410722)
        end
        they("are saved when saving the pet") { pet.save! ; should all be_persisted }
        they("match the expected metadata") do
          expect(assets_by_item).to match(
            39552 => a_collection_containing_exactly(
              a_record_matching(
                type: "object",
                remote_id: 16933,
                zone_id: 35,
                url: "https://images.neopets.com/cp/items/swf/000/000/016/16933_0833353c4f.swf",
                manifest_url: "https://images.neopets.com/cp/items/data/000/000/016/16933_0833353c4f/manifest.json?v=1706",
                zones_restrict: "",
              )
            ),
            53874 => a_collection_containing_exactly(
              a_record_matching(
                type: "object",
                remote_id: 108567,
                zone_id: 23,
                url: "https://images.neopets.com/cp/items/swf/000/000/108/108567_ee88141325.swf",
                manifest_url: "https://images.neopets.com/cp/items/data/000/000/108/108567_ee88141325/manifest.json?v=1706",
                zones_restrict: "",
              )
            ),
            71706 => a_collection_containing_exactly(
              a_record_matching(
                type: "object",
                remote_id: 410722,
                zone_id: 3,
                url: "https://images.neopets.com/cp/items/swf/000/000/410/410722_3bcd2f5e11.swf",
                manifest_url: "https://images.neopets.com/cp/items/data/000/000/410/410722_3bcd2f5e11/manifest.json?v=1706",
                zones_restrict: "",
              )
            ),
          )
        end
      end

      context "when modeled a second time" do
        before { pet.save! }
        subject!(:new_pet) { Pet.load("matts_bat") }

        describe "its pet type" do
          subject(:pet_type) { new_pet.pet_type }

          it("already exists") { should be_persisted }
          it("is the same as before") { should eq pet.pet_type }
          it "is not changed when saving the pet" do
            new_pet.save!; expect(pet_type.previous_changes).to be_empty
          end
        end

        describe "its pet state" do
          subject(:pet_state) { new_pet.pet_state }

          it("already exists") { should be_persisted }
          it("is the same as before") { should eq pet.pet_state }
          it "is not changed when saving the pet" do
            new_pet.save!; expect(pet_state.previous_changes).to be_empty
          end
        end

        describe "its biology assets" do
          subject(:biology_assets) { new_pet.pet_state.swf_assets }

          they("already exist") { should all be_persisted }
          they("are the same as before") { should eq pet.pet_state.swf_assets }
          they("are not changed when saving the pet") do
            new_pet.save!; expect(biology_assets.map(&:previous_changes)).to all be_empty
          end
        end

        describe "its items" do
          subject(:items) { new_pet.items }

          they("already exist") { should all be_persisted }
          they("are the same as before") { should eq pet.items }
          they("are not changed when saving the pet") do
            new_pet.save!; expect(items.map(&:previous_changes)).to all be_empty
          end
        end

        describe "its item assets" do
          subject(:item_assets) { new_pet.items.map(&:swf_assets).flatten(1) }

          they("already exist") { should all be_persisted }
          they("are the same as before") { should eq pet.items.map(&:swf_assets).flatten(1) }
          they("are not changed when saving the pet") do
            new_pet.save!; expect(item_assets.map(&:previous_changes)).to all be_empty
          end
        end
      end

      context "when modeled a second time, but as a Blue Acara" do
        before { pet.save! }
        subject(:new_pet) { Pet.load("matts_bat:acara") }

        describe "its items" do
          subject(:items) { new_pet.items }
          let(:compatible_body_ids) { items.to_h { |i| [i.id, i.compatible_body_ids] } }

          they("should be marked compatible with both pets' body IDs") do
            pending("Whuh oh, we're currently replacing the assets altogether!")
            new_pet.save!
            expect(compatible_body_ids).to eq(
              39552 => [47, 93],
              53874 => [47, 93],
              71706 => [0],
            )
          end
        end
      end
    end

    context "for Majal_Kita, the Nostalgic Robot Jetsam (modded to be Blue as its base)" do
      it("fails to load without an existing Blue Jetsam, " +
         "because the biology data is incomplete") do
        expect { Pet.load("Majal_Kita") }.to raise_error(Pet::UnexpectedDataFormat)
      end

      context "with a Blue Jetsam already modeled" do
        before { Pet.load("Blue_Jetsam").save! }
        subject(:pet) { Pet.load("Majal_Kita") }

        it("loads without raising an error") do
          expect { Pet.load("Majal_Kita") }.not_to raise_error
        end

        describe "its alt style" do
          subject(:alt_style) { pet.alt_style }

          it("is new and unsaved") { should be_new_record }
          it("has the unique ID 87458") { expect(alt_style.id).to eq 87458 }
          it("is Robot") { expect(alt_style.color).to eq Color.find_by_name!("Robot") }
          it("is a Jetsam") { expect(alt_style.species).to eq Species.find_by_name!("Jetsam") }
          it("has unique body ID 378") { expect(alt_style.body_id).to eq 378 }
          it("has no series name yet") { expect(alt_style.real_series_name?).to be false }
          it("has no thumbnail yet") { expect(alt_style.thumbnail_url?).to be false }
          it("is saved when saving the pet") { pet.save!; should be_persisted }

          describe "its assets" do
            subject(:assets) { alt_style.swf_assets }
            let(:asset_ids) { assets.map(&:remote_id) }

            they("are all new") { should all be_new_record }
            they("match the expected IDs") do
              expect(asset_ids).to contain_exactly(56223)
            end
            they("are saved when saving the pet") { pet.save!; should all be_persisted }
            they("have the expected asset metadata") do
              should contain_exactly(
                a_record_matching(
                  type: "biology",
                  remote_id: 56223,
                  zone_id: 15,
                  url: "https://images.neopets.com/cp/bio/swf/000/000/056/56223_dc26edc764.swf",
                  manifest_url: "https://images.neopets.com/cp/bio/data/000/000/056/56223_dc26edc764/manifest.json",
                  zones_restrict: "0000000000000000000000000000000000000000000000000000",
                )
              )
            end
          end
        end

        context "when modeled a second time" do
          before { pet.save! }
          subject(:new_pet) { Pet.load("Majal_Kita") }

          describe "its alt style" do
            subject(:alt_style) { new_pet.alt_style }

            it("already exists") { should be_persisted }
            it("is the same as before") { should eq pet.alt_style }
            it "is not changed when saving the pet" do
              new_pet.save!; expect(alt_style.previous_changes).to be_empty
            end

            describe "its assets" do
              subject(:assets) { alt_style.swf_assets }

              they("already exist") { should all be_persisted }
              they("are the same as before") { should eq pet.alt_style.swf_assets }
              they("are not changed when saving the pet") do
                new_pet.save!; expect(assets.map(&:previous_changes)).to all be_empty
              end
            end
          end
        end
      end
    end

    context "when modeling is disabled" do
      before { allow(Rails.configuration).to receive(:modeling_enabled) { false } }

      it("raises an error") do
        expect { Pet.load("matts_bat") }.to raise_error(Pet::ModelingDisabled)
      end
    end
  end
end
