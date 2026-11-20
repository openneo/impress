require_relative '../rails_helper'

RSpec.describe AltStyle do
	fixtures :colors, :species

	describe "series name" do
		subject(:alt_style) { AltStyle.new }

		describe "for a new alt style" do
			it("returns a placeholder value by default") do
				expect(alt_style.series_name).to eq "<New?>"
			end

			it("has no real_series_name by default") do
				expect(alt_style.real_series_name?).to be false
				expect(alt_style.real_series_name).to be nil
			end
		end

		describe "with a real series name" do
			before { alt_style.real_series_name = "Nostalgic" }

			it("returns the real series name") do
				expect(alt_style.series_name).to eq "Nostalgic"
			end

			it("has a real_series_name field too") do
				expect(alt_style.real_series_name?).to be true
				expect(alt_style.real_series_name).to eq "Nostalgic"
			end
		end
	end

	describe "labeled?" do
		subject(:alt_style) do
			AltStyle.new(color: colors(:blue), species: species(:acara))
		end

		it("is false for a new alt style") do
			expect(alt_style.labeled?).to be false
		end

		it("is true once it has a series name") do
			alt_style.real_series_name = "Nostalgic"
			expect(alt_style.labeled?).to be true
		end

		it("is true once it has a full name, even without a series name") do
			alt_style.real_full_name = "Nostalgic Blue Acara"
			expect(alt_style.labeled?).to be true
		end
	end

	describe "full name" do
		subject(:alt_style) do
			AltStyle.new(color: colors(:blue), species: species(:acara))
		end

		describe "for a new alt style" do
			it("returns a placeholder value by default") do
				expect(alt_style.full_name).to eq "Unnamed Blue Acara style"
			end

			it("has no real_full_name by default") do
				expect(alt_style.real_full_name?).to be false
				expect(alt_style.real_full_name).to be nil
			end
		end

		describe "with a real series name, but no full name" do
			before { alt_style.real_series_name = "Nostalgic" }

			it("returns a placeholder value including the real series name") do
				expect(alt_style.full_name).to eq "Nostalgic Blue Acara"
			end

			it("still has no real_full_name") do
				expect(alt_style.real_full_name?).to be false
				expect(alt_style.real_full_name).to eq nil
			end
		end

		describe "with a real full name" do
			before { alt_style.real_full_name = "Cute Lil Guy" }

			it("returns the real full name") do
				expect(alt_style.full_name).to eq "Cute Lil Guy"
			end

			it("has a real_full_name field too") do
				expect(alt_style.real_full_name?).to be true
				expect(alt_style.real_full_name).to eq "Cute Lil Guy"
			end
		end
	end

	describe "adjective name" do
		subject(:alt_style) do
			AltStyle.new(color: colors(:blue), species: species(:acara))
		end

		describe "for a new alt style" do
			it("returns a stand-in name with the color name") do
				expect(alt_style.adjective_name).to eq "Unnamed Blue style"
			end
		end

		describe "with a real series name, but no full name" do
			before { alt_style.series_name = "Nostalgic" }

			it("returns the series name and color name") do
				expect(alt_style.adjective_name).to eq "Nostalgic Blue"
			end
		end

		describe "with a real full name that ends with the species name" do
			before { alt_style.real_full_name = "Cute Lil Acara" }

			it("returns the real full name minus the species") do
				expect(alt_style.adjective_name).to eq "Cute Lil"
			end
		end

		describe "with a real full name that does not end with the species name" do
			before { alt_style.real_full_name = "Cute Lil Guy" }

			it("returns the real full name") do
				expect(alt_style.adjective_name).to eq "Cute Lil Guy"
			end
		end
	end

	describe "#infer_series_name" do
		subject(:alt_style) do
			AltStyle.new(color: colors(:blue), species: species(:acara))
		end

		it "returns what comes before the color and species" do
			expect(alt_style.infer_series_name("Nostalgic Blue Acara")).
				to eq "Nostalgic"
		end

		it "keeps variant names, like Prismatic ones" do
			expect(alt_style.infer_series_name("Prismatic Ice: Nostalgic Blue Acara")).
				to eq "Prismatic Ice: Nostalgic"
		end

		it "ignores case" do
			expect(alt_style.infer_series_name("Nostalgic BLUE ACARA")).
				to eq "Nostalgic"
		end

		it "recognizes series named after characters" do
			expect(alt_style.infer_series_name("Treasured Roberta")).
				to eq "Treasured"
		end

		it "returns nil when the name has a different color or species" do
			expect(alt_style.infer_series_name("Nostalgic Red Acara")).to be_nil
			expect(alt_style.infer_series_name("Nostalgic Blue Blumaroo")).to be_nil
		end

		it "returns nil when there's nothing before the color and species" do
			expect(alt_style.infer_series_name("Blue Acara")).to be_nil
		end

		it "returns nil when only a Prismatic variant name is left" do
			expect(alt_style.infer_series_name("Prismatic Cocoa: Blue Acara")).
				to be_nil
		end
	end

	describe "token item" do
		fixtures :items, :zones

		def build_alt_style(**attrs)
			AltStyle.new(id: 87305, color: colors(:blue), species: species(:acara),
				body_id: 1234, created_at: Time.new(2024, 1, 15), **attrs)
		end

		it("is not created for an unlabeled style") do
			alt_style = build_alt_style
			alt_style.save!
			expect(alt_style.token_item).to be nil
			expect(Item.exists?(87305)).to be false
		end

		it("is created once the style is labeled") do
			alt_style = build_alt_style
			alt_style.save!
			alt_style.update!(
				real_series_name: "Nostalgic",
				real_full_name: "Nostalgic Blue Acara",
				thumbnail_url: "https://images.neopets.com/items/nostalgic_blue_acara.gif",
			)

			item = Item.find(87305)
			expect(item.name).to eq "Nostalgic Blue Acara"
			expect(item.thumbnail_url).to eq(
				"https://images.neopets.com/items/nostalgic_blue_acara.gif")
			expect(item.description).to eq ""
			expect(item.created_at).to eq Time.new(2024, 1, 15)
			expect(item).to be_nc
			expect(item).to be_style_token
			expect(item.alt_style).to eq alt_style
			expect(alt_style.reload.token_item).to eq item
		end

		it("falls back to the inferred full name, if only the series is known") do
			build_alt_style(real_series_name: "Nostalgic").save!
			expect(Item.find(87305).name).to eq "Nostalgic Blue Acara"
		end

		it("counts as fully modeled, with no compatible bodies") do
			build_alt_style(real_series_name: "Nostalgic").save!

			item = Item.find(87305)
			expect(item.compatible_body_ids).to be_empty
			expect(item.predicted_missing_body_ids).to be_empty
			expect(item).to be_predicted_fully_modeled
			expect(Item.is_modeled).to include(item)
		end

		it("follows changes to the style's name and thumbnail") do
			alt_style = build_alt_style(real_series_name: "Nostalgic")
			alt_style.save!
			alt_style.update!(real_full_name: "Nostalgic Blue Acara Deluxe",
				thumbnail_url: "https://images.neopets.com/items/new.gif")

			item = Item.find(87305)
			expect(item.name).to eq "Nostalgic Blue Acara Deluxe"
			expect(item.thumbnail_url).to eq "https://images.neopets.com/items/new.gif"
		end

		it("leaves other item fields alone when re-syncing") do
			alt_style = build_alt_style(real_series_name: "Nostalgic")
			alt_style.save!
			Item.find(87305).update!(description: "A real description!")
			alt_style.save!

			expect(Item.find(87305).description).to eq "A real description!"
		end

		it("refuses to overwrite a wearable item with the same ID") do
			item = items(:straw_hat)
			swf_asset = SwfAsset.new(type: "object", remote_id: 1, url: "https://images.neopets.example/hat.swf",
				zones_restrict: "", zone: zones(:background), body_id: 0)
			swf_asset.save!
			ParentSwfAssetRelationship.create!(parent: item, swf_asset:)

			alt_style = build_alt_style(real_series_name: "Nostalgic")
			alt_style.id = item.id
			alt_style.save!

			expect(item.reload.name).to eq "Straw Hat"
		end

		it("can be searched for with is:style") do
			build_alt_style(real_series_name: "Nostalgic").save!

			tokens = Item::Search::Query.from_text("is:style").results
			expect(tokens.map(&:id)).to eq [87305]

			others = Item::Search::Query.from_text("-is:style").results
			expect(others.map(&:id)).not_to include(87305)
			expect(others).to include(items(:straw_hat))
		end

		it("doesn't appear in searches that fit a specific pet") do
			build_alt_style(real_series_name: "Nostalgic").save!
			expect(Item.fits(1234)).to be_empty
		end
	end

	describe "canonical_pet_type" do
		let(:acara) { species(:acara) }

		# Other specs load pet type fixtures, which stick around in the database
		# between spec files. Clear them out so they can't collide with the pet
		# types we create here. (This runs in a transaction, so it's rolled back.)
		before { PetType.destroy_all }

		def create_pet_type(color, body_id)
			PetType.create!(color:, species: acara, body_id:)
		end

		def build_alt_style_for(color)
			AltStyle.new(color:, species: acara, body_id: 1234)
		end

		it "is the matching pet type when there is one" do
			create_pet_type(colors(:blue), 101)
			maraquan = create_pet_type(colors(:maraquan), 102)

			expect(build_alt_style_for(colors(:maraquan)).canonical_pet_type).
				to eq maraquan
		end

		it "falls back to a basic pet type of the same species" do
			blue = create_pet_type(colors(:blue), 101)

			# There's no maraquan acara pet type, so we get the basic one.
			expect(build_alt_style_for(colors(:maraquan)).canonical_pet_type).
				to eq blue
		end

		it "ignores pet types of other species and non-basic colors" do
			create_pet_type(colors(:purple), 103)
			PetType.create!(color: colors(:blue), species: species(:chia),
											body_id: 104)

			expect(build_alt_style_for(colors(:maraquan)).canonical_pet_type).
				to be_nil
		end

		it "is nil when the species has no pet types at all" do
			expect(build_alt_style_for(colors(:maraquan)).canonical_pet_type).
				to be_nil
		end
	end
end
