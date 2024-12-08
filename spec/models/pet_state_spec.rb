require_relative '../rails_helper'

RSpec.describe PetState do
	fixtures :colors, :species, :zones

	let(:blue) { colors(:blue) }
	let(:green) { colors(:green) }
	let(:red) { colors(:red) }
	let(:acara) { species(:acara) }

	describe ".next_unlabeled_appearance" do
		before { PetType.destroy_all }

		def create_sa
			swf_asset = SwfAsset.create!(
				type: "biology", remote_id: (SwfAsset.maximum(:remote_id) || 0) + 1,
				url: "https://images.neopets.example/hello.swf",
				zone: zones(:body), zones_restrict: [], body_id: 0)
		end

		def create_pt(color, species, created_at = nil)
			PetType.create! color:, species:, created_at:,
				body_id: (PetType.maximum(:body_id) || 0) + 1
		end

		def create_ps(pet_type, pose, created_at = nil, **options)
			# HACK: PetStates without any assets don't save correctly.
			# https://github.com/rails/rails/issues/52340
			swf_assets = [create_sa]
			PetState.create! pet_type:, pose:, created_at:, swf_assets:,
				swf_asset_ids: swf_assets.map(&:id), **options
		end

		it "returns nil where there are no pet states" do
			expect(PetState.next_unlabeled_appearance).to be_nil
		end

		it "returns nil where there are only labeled pet states" do
			pt = PetType.create! color: blue, species: acara, body_id: 1
			ps = create_ps(pt, "HAPPY_MASC").tap(&:save!)
			expect(PetState.next_unlabeled_appearance).to be_nil
		end

		it "returns the only pet state when it is unlabeled" do
			pt = PetType.create! color: blue, species: acara, body_id: 1
			ps = create_ps(pt, "UNKNOWN").tap(&:save!)
			expect(PetState.next_unlabeled_appearance).to eq ps
		end

		describe "with multiple unlabeled pet states" do
			before do
				# Create three pet types, with ascending order of creation date.
				@pt1 = create_pt blue,  acara, Date.new(2000)
				@pt2 = create_pt green, acara, Date.new(2005)
				@pt3 = create_pt red,   acara, Date.new(2010)

				# Give each a pet state, but created in a different order.
				@ps1 = create_ps @pt1, "UNKNOWN", Date.new(2020)
				@ps2 = create_ps @pt2, "UNKNOWN", Date.new(2025)
				@ps3 = create_ps @pt3, "UNKNOWN", Date.new(2015)
			end

			it "returns the latest pet type's pet state" do
				expect(PetState.next_unlabeled_appearance).to eq @ps3
			end

			it "excludes fully-labeled pet types" do
				# Label the latest pet state, then see it move to the next.
				@ps3.update!(pose: "HAPPY_FEM")
				expect(PetState.next_unlabeled_appearance).to eq @ps2
			end

			it "excludes labeled pet states" do
				# Create an older pet state on the latest pet type, than label the
				# latest pet state, and see it move back to the older one.
				ps3_a = create_ps @pt3, "UNKNOWN", Date.new(2014)
				@ps3.update!(pose: "HAPPY_FEM")
				expect(PetState.next_unlabeled_appearance).to eq ps3_a
			end

			it "sorts pet states within the latest pet type by newest" do
				# Create a few pet types on the latest pet type, and see that we get
				# the latest back.
				ps3_a = create_ps @pt3, "UNKNOWN", Date.new(2016)
				ps3_b = create_ps @pt3, "UNKNOWN", Date.new(2017)
				ps3_c = create_ps @pt3, "UNKNOWN", Date.new(2018)
				ps3_d = create_ps @pt3, "UNKNOWN", Date.new(2019)
				expect(PetState.next_unlabeled_appearance).to eq ps3_d
			end

			it "can find the next after the latest pet state" do
				expect(PetState.next_unlabeled_appearance(after_id: @ps3.id)).to eq @ps2
			end

			it "can find the next after any given pet state" do
				expect(PetState.next_unlabeled_appearance(after_id: @ps2.id)).to eq @ps1
			end

			it "can find the next after the latest pet state, even within the same pet type" do
				ps3_a = create_ps @pt3, "UNKNOWN", Date.new(2014)
				expect(PetState.next_unlabeled_appearance(after_id: @ps3.id)).to eq ps3_a
			end
		end
	end
end
