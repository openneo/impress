require_relative '../rails_helper'

RSpec.describe Roulette do
	fixtures :colors, :species, :zones

	let(:shirt) { zones(:shirtdress) } # zone 23
	let(:hat) { zones(:hat1) }          # zone 40

	before do
		PetType.destroy_all # Make sure no leftovers from e.g. PetType's spec.
		PetState.destroy_all
	end

	def build_pet_type(color:, species:, body_id:)
		PetType.create!(color:, species:, body_id:, created_at: Time.new(2010))
	end

	def build_pet_state(pet_type, labeled: true, glitched: false, mood_id: 1)
		# Like the rest of our specs, we use [0] for "no assets": Rails treats
		# an empty array as the default value of a serialized column and would
		# save NULL, which this NOT NULL column rejects.
		PetState.create!(pet_type:, mood_id:, female: true, swf_asset_ids: [0],
		                 labeled:, glitched:)
	end

	# Create an item that fits the given bodies and occupies the given zones,
	# restricting the given ones. We set the cached fields directly, since that's
	# all roulette reads. (No need for a whole asset graph in these tests.)
	def build_item(name:, body_ids:, zones:, restricts: [], restricts_raw: nil)
		Item.create!(
			name:, description: "A test item",
			thumbnail_url: "https://images.neopets.example/test.gif",
			rarity: "NP", rarity_index: 0, price: 100, weight_lbs: 1,
			zones_restrict: restricts_raw || restrict_string(restricts),
			cached_compatible_body_ids: body_ids,
			cached_occupied_zone_ids: zones.map(&:id),
		)
	end

	def restrict_string(zone_ids)
		string = Array.new(52, "0")
		zone_ids.each { |zone_id| string[zone_id - 1] = "1" }
		string.join
	end

	describe ".spin" do
		before do
			blue = build_pet_type(color: colors(:blue), species: species(:acara),
			                      body_id: 1)
			maraquan = build_pet_type(color: colors(:maraquan),
			                          species: species(:acara), body_id: 10)
			build_pet_state(blue)
			build_pet_state(maraquan)

			# A shirt and a hat that fit both bodies, so every spin can be
			# dressed. (They don't conflict with each other.)
			@shirt_item = build_item(name: "Shirt", body_ids: [1, 10], zones: [shirt])
			@hat_item = build_item(name: "Hat", body_ids: [1, 10], zones: [hat])
		end

		it "returns a query for a real pet, wearing compatible items" do
			5.times do
				query = Roulette.spin

				pet_type = PetType.find_by!(color_id: query[:color],
				                            species_id: query[:species])

				# The state is one of this pet's states, and the pose matches.
				state = PetState.find(query[:state])
				expect(state.pet_type_id).to eq(pet_type.id)
				expect(query[:pose]).to eq(state.pose)

				# It wears both items, since they fit and don't conflict...
				expect(query[:objects]).to match_array(
					[@shirt_item.id, @hat_item.id])

				# ...and every item fits the pet's body.
				query[:objects].each do |item_id|
					expect(Item.fits(pet_type.body_id).exists?(id: item_id)).to be(true)
				end

				# And no two items conflict, by the editor's rule: an item
				# conflicts if it occupies a zone that's already occupied or
				# restricted, or restricts one that's occupied.
				items = Item.where(id: query[:objects]).to_a
				conflicts = []
				items.combination(2) do |a, b|
					a_blocks = (a.cached_occupied_zone_ids + a.restricted_zone_ids).uniq
					b_blocks = (b.cached_occupied_zone_ids + b.restricted_zone_ids).uniq
					conflicts << [a.id, b.id] if
						(a.cached_occupied_zone_ids & b_blocks).any? ||
						(b.cached_occupied_zone_ids & a_blocks).any?
				end
				expect(conflicts).to be_empty
			end
		end

		it "omits objects when no items fit the pet's body" do
			Item.delete_all

			query = Roulette.spin
			expect(query).not_to have_key(:objects)
		end

		it "spins only the requested species and color" do
			query = Roulette.spin(species_id: 1, color_id: 44) # The maraquan acara.
			expect(query[:species]).to eq(1)
			expect(query[:color]).to eq(44)

			expect { Roulette.spin(species_id: 99) }
				.to raise_error(ArgumentError, /Unknown species/)

			expect { Roulette.spin(color_id: 99) }
				.to raise_error(ArgumentError, /Unknown color/)
		end

		it "usually picks a standard color when only a species is asked for" do
			# The blue acara is basic; the maraquan one isn't.
			colors_picked = Array.new(40) { |seed| Roulette.spin(rng: Random.new(seed), species_id: 1)[:color] }

			expect(colors_picked).to include(colors(:blue).id, colors(:maraquan).id)
			expect(colors_picked.count(colors(:blue).id)).to be > colors_picked.count(colors(:maraquan).id)
		end

		it "falls back to the other color pool when the species has no standard color" do
			PetType.where(color: colors(:blue)).destroy_all

			10.times do |seed|
				expect(Roulette.spin(rng: Random.new(seed), species_id: 1)[:color])
					.to eq(colors(:maraquan).id)
			end
		end
	end

	describe "ITEM_COUNT_WEIGHTS" do
		it "is a bell curve centered on 6" do
			weights = Roulette::ITEM_COUNT_WEIGHTS

			expect(weights.max_by { |_, weight| weight }.first).to eq(6)
			expect(weights[5]).to eq(weights[7])
			expect(weights[4]).to be < weights[5]
			expect(weights[3]).to be < weights[4]
		end
	end

	describe ".pick_pet_type" do
		it "picks from the basic pool when asked for a basic pet" do
			basic = build_pet_type(color: colors(:blue), species: species(:acara),
			                       body_id: 1)
			build_pet_state(basic)
			special = build_pet_type(color: colors(:maraquan),
			                         species: species(:acara), body_id: 10)
			build_pet_state(special)

			expect(Roulette.pick_pet_type(basic: true)).to eq(basic)
		end

		it "picks from the special pool when asked for a non-basic pet" do
			basic = build_pet_type(color: colors(:blue), species: species(:acara),
			                       body_id: 1)
			build_pet_state(basic)
			special = build_pet_type(color: colors(:maraquan),
			                         species: species(:acara), body_id: 10)
			build_pet_state(special)

			# (maraquan's `basic` flag is NULL, but roulette treats that as
			# non-basic, like the rest of the site.)
			expect(Roulette.pick_pet_type(basic: false)).to eq(special)
		end

		it "never treats a NULL basic flag as basic" do
			expect(colors(:maraquan).basic).to be_nil # Sanity: the fixture.

			basic = build_pet_type(color: colors(:blue), species: species(:acara),
			                       body_id: 1)
			build_pet_state(basic)
			special = build_pet_type(color: colors(:maraquan),
			                         species: species(:acara), body_id: 10)
			build_pet_state(special)

			# The maraquan's `basic` flag is NULL, so the basic pool only has
			# the blue pet in it.
			10.times do
				expect(Roulette.pick_pet_type(basic: true)).to eq(basic)
			end
		end

		it "skips pet types that have no states" do
			build_pet_type(color: colors(:blue), species: species(:acara), body_id: 1)
			with_states = build_pet_type(color: colors(:red), species: species(:acara),
			                             body_id: 2)
			build_pet_state(with_states)

			# The blue Acara has no states, so roulette must pick the red one.
			expect(Roulette.pick_pet_type(basic: true)).to eq(with_states)
		end

		it "skips pet types whose color no longer exists" do
			dangling = PetType.create!(color_id: 999, species_id: 1, body_id: 1,
			                           created_at: Time.new(2010))
			build_pet_state(dangling)

			# The dangling color can't be shown, so roulette must raise rather
			# than emit a query the editor couldn't resolve.
			expect { Roulette.pick_pet_type(basic: true) }
				.to raise_error(RuntimeError, /couldn't find a pet type/)
		end

		it "falls back to the other pool if this one has nothing showable" do
			build_pet_type(color: colors(:maraquan), species: species(:acara),
			               body_id: 10) # No states.
			with_states = build_pet_type(color: colors(:blue), species: species(:acara),
			                             body_id: 1)
			build_pet_state(with_states)

			expect(Roulette.pick_pet_type(basic: false)).to eq(with_states)
		end

		it "raises if no pet type has any states" do
			build_pet_type(color: colors(:blue), species: species(:acara), body_id: 1)

			expect { Roulette.pick_pet_type(basic: true) }
				.to raise_error(RuntimeError, /couldn't find a pet type/)
		end

		it "picks only from the requested species" do
			basic = build_pet_type(color: colors(:blue), species: species(:acara),
			                       body_id: 1)
			build_pet_state(basic)
			other = build_pet_type(color: colors(:red), species: species(:blumaroo),
			                       body_id: 2)
			build_pet_state(other)

			# Both are basic, so without the filter either could be picked.
			10.times do
				expect(Roulette.pick_pet_type(basic: true, species_id: 1)).to eq(basic)
			end
		end

		it "picks only from the requested color" do
			wanted = build_pet_type(color: colors(:red), species: species(:acara),
			                        body_id: 2)
			build_pet_state(wanted)
			other = build_pet_type(color: colors(:blue), species: species(:acara),
			                       body_id: 1)
			build_pet_state(other)

			# Both are basic, so without the filter either could be picked.
			10.times do
				expect(Roulette.pick_pet_type(basic: true, color_id: 61)).to eq(wanted)
			end
		end

		it "narrows to the requested species and color at once" do
			wanted = build_pet_type(color: colors(:maraquan),
			                        species: species(:blumaroo), body_id: 10)
			build_pet_state(wanted)
			# Decoys that each match only one of the two. (Maraquan is a special
			# color, so this also proves no pool roll happens.)
			same_color = build_pet_type(color: colors(:maraquan),
			                            species: species(:acara), body_id: 10)
			build_pet_state(same_color)
			same_species = build_pet_type(color: colors(:blue),
			                              species: species(:blumaroo), body_id: 1)
			build_pet_state(same_species)

			10.times do
				expect(Roulette.pick_pet_type(basic: true, species_id: 3, color_id: 44))
					.to eq(wanted)
			end
		end

		it "raises on an unknown species or color" do
			expect { Roulette.pick_pet_type(basic: true, species_id: 99) }
				.to raise_error(ArgumentError, "Unknown species: 99")

			expect { Roulette.pick_pet_type(basic: true, color_id: 99) }
				.to raise_error(ArgumentError, "Unknown color: 99")
		end

		it "raises when the requested kind of pet can't be shown" do
			build_pet_type(color: colors(:blue), species: species(:acara), body_id: 1)
			# A red acara exists, but has no states to show.
			build_pet_type(color: colors(:red), species: species(:acara), body_id: 2)

			expect { Roulette.pick_pet_type(basic: true, species_id: 1, color_id: 61) }
				.to raise_error(ArgumentError, /No showable pet found/)
		end
	end

	describe ".pick_pet_state" do
		it "picks a happy state when there is one" do
			pet_type = build_pet_type(color: colors(:blue), species: species(:acara),
			                          body_id: 1)
			happy = build_pet_state(pet_type, mood_id: 1)
			build_pet_state(pet_type, mood_id: 2) # Sad
			build_pet_state(pet_type, mood_id: 4) # Sick

			10.times do
				expect(Roulette.pick_pet_state(pet_type.id)).to eq(happy)
			end
		end

		it "falls back to another mood when no state is happy" do
			pet_type = build_pet_type(color: colors(:blue), species: species(:acara),
			                          body_id: 1)
			sad = build_pet_state(pet_type, mood_id: 2)

			expect(Roulette.pick_pet_state(pet_type.id)).to eq(sad)
		end

		it "prefers a usable sad state over a glitched happy one" do
			pet_type = build_pet_type(color: colors(:blue), species: species(:acara),
			                          body_id: 1)
			sad = build_pet_state(pet_type, mood_id: 2)
			build_pet_state(pet_type, mood_id: 1, labeled: false, glitched: true)

			10.times do
				expect(Roulette.pick_pet_state(pet_type.id)).to eq(sad)
			end
		end

		it "prefers a happy state among unvalidated ones, too" do
			pet_type = build_pet_type(color: colors(:blue), species: species(:acara),
			                          body_id: 1)
			happy = build_pet_state(pet_type, mood_id: 1, labeled: false)
			build_pet_state(pet_type, mood_id: 4, labeled: false)

			10.times do
				expect(Roulette.pick_pet_state(pet_type.id)).to eq(happy)
			end
		end

		it "prefers usable states, but falls back to the rest" do
			pet_type = build_pet_type(color: colors(:blue), species: species(:acara),
			                          body_id: 1)
			usable = build_pet_state(pet_type)
			build_pet_state(pet_type, labeled: false, glitched: true)

			expect(Roulette.pick_pet_state(pet_type.id)).to eq(usable)
		end

		it "returns a non-usable state if that's all the pet has" do
			pet_type = build_pet_type(color: colors(:blue), species: species(:acara),
			                          body_id: 1)
			glitched = build_pet_state(pet_type, labeled: false, glitched: true)

			expect(Roulette.pick_pet_state(pet_type.id)).to eq(glitched)
		end

		it "skips states whose pose the editor can't display" do
			pet_type = build_pet_type(color: colors(:blue), species: species(:acara),
			                          body_id: 1)
			good = build_pet_state(pet_type, labeled: false)
			bad = build_pet_state(pet_type, labeled: false, mood_id: 3)
			expect { bad.pose }.to raise_error(/could not identify pose/)

			# Mood 3 is a legacy mood `PetState#pose` doesn't know, so the
			# roulette must skip that state.
			expect(Roulette.pick_pet_state(pet_type.id)).to eq(good)
		end

		it "skips even labeled states whose pose the editor can't display" do
			pet_type = build_pet_type(color: colors(:blue), species: species(:acara),
			                          body_id: 1)
			good = build_pet_state(pet_type, labeled: false)
			# Labeled (i.e. "usable") but with a legacy mood: the primary path
			# must skip it too, or `pose` would raise mid-spin.
			bad = build_pet_state(pet_type, mood_id: 3)

			expect { bad.pose }.to raise_error(/could not identify pose/)
			expect(Roulette.pick_pet_state(pet_type.id)).to eq(good)
		end

		it "returns nil if no state's pose can be displayed" do
			pet_type = build_pet_type(color: colors(:blue), species: species(:acara),
			                          body_id: 1)
			build_pet_state(pet_type, labeled: false, mood_id: 3)

			expect(Roulette.pick_pet_state(pet_type.id)).to be_nil
		end

		it "returns nil for a pet with no states" do
			pet_type = build_pet_type(color: colors(:blue), species: species(:acara),
			                          body_id: 1)

			expect(Roulette.pick_pet_state(pet_type.id)).to be_nil
		end
	end

	describe ".pick_item_count" do
		it "always picks a count in the 3..10 range" do
			rng = Random.new(2010)

			100.times do
				expect(Roulette.pick_item_count(rng)).to be_between(3, 10)
			end
		end

		it "picks six most often, since that's the mode we want" do
			rng = Random.new(2010)
			counts = Array.new(10_000) { Roulette.pick_item_count(rng) }

			expect(counts.tally.max_by(&:last).first).to eq(6)
		end
	end

	describe ".pick_item_ids" do
		it "picks every item when they don't conflict" do
			a = build_item(name: "Shirt", body_ids: [1], zones: [shirt])
			b = build_item(name: "Hat", body_ids: [1], zones: [hat])

			expect(Roulette.pick_item_ids(1, rng: Random.new(42)))
				.to contain_exactly(a.id, b.id)
		end

		it "stops at a target count instead of filling every zone" do
			# Twenty items in twenty different zones: there's always more the
			# pet could wear, so roulette must stop at its target count.
			Zone.where.not(id: Roulette::EXCLUDED_ZONE_IDS).order(:id).first(20).each_with_index do |zone, i|
				build_item(name: "Item #{i + 1}", body_ids: [1], zones: [zone])
			end

			20.times do
				chosen = Roulette.pick_item_ids(1, rng: Random.new)
				expect(chosen.size).to be_between(3, 10)
			end
		end

		it "fills every zone when asked for a full outfit" do
			# Twenty items in twenty different zones: a full outfit wears all of
			# them.
			Zone.where.not(id: Roulette::EXCLUDED_ZONE_IDS).order(:id).first(20).each_with_index do |zone, i|
				build_item(name: "Item #{i + 1}", body_ids: [1], zones: [zone])
			end

			chosen = Roulette.pick_item_ids(1, rng: Random.new(42), full_outfit: true)
			expect(chosen.size).to eq(20)
		end

		it "fills exactly as many random zones as asked for" do
			# Twenty items in twenty different zones: asking for four fills
			# exactly four, even though there's plenty more the pet could wear.
			Zone.where.not(id: Roulette::EXCLUDED_ZONE_IDS).order(:id).first(20).each_with_index do |zone, i|
				build_item(name: "Item #{i + 1}", body_ids: [1], zones: [zone])
			end

			5.times do
				chosen = Roulette.pick_item_ids(1, rng: Random.new, zone_count: 4)
				expect(chosen.size).to eq(4)
			end
		end

		it "fills only the zones asked for" do
			shirt_item = build_item(name: "Shirt", body_ids: [1], zones: [shirt])
			hat_item = build_item(name: "Hat", body_ids: [1], zones: [hat])

			chosen = Roulette.pick_item_ids(1, rng: Random.new(42), zones: [hat.id])
			expect(chosen).to eq([hat_item.id])

			# Several zones work too, and all of them get filled.
			chosen = Roulette.pick_item_ids(1, rng: Random.new(42), zones: [hat.id, shirt.id])
			expect(chosen).to contain_exactly(hat_item.id, shirt_item.id)
		end

		it "leaves the pet bare if no requested zone has items for the body" do
			build_item(name: "Shirt", body_ids: [1], zones: [shirt])
			build_item(name: "Hat for Body 2", body_ids: [2], zones: [hat])

			# The hat doesn't fit, and we don't swap in something unrelated.
			10.times do |seed|
				expect(Roulette.pick_item_ids(1, rng: Random.new(seed), zones: [hat.id]))
					.to be_nil
			end
		end

		it "never fills a zone nobody asked for" do
			wings_item = build_item(name: "Wings", body_ids: [1], zones: [zones(:wings)])
			dress = build_item(name: "Dress", body_ids: [1], zones: [shirt, hat])

			# The dress fills both requested zones, so there's nothing left to
			# request, and the wings in a third zone must not backfill.
			30.times do |seed|
				chosen = Roulette.pick_item_ids(1, rng: Random.new(seed), zones: [shirt.id, hat.id])
				expect(chosen).not_to include(wings_item.id)
				expect(chosen).to include(dress.id)
			end
		end

		it "refuses the music and sound effects zones" do
			expect { Roulette.pick_item_ids(1, zones: [zones(:music).id]) }
				.to raise_error(Roulette::InvalidRequest, /Zone 1 can't be requested/)

			expect { Roulette.pick_item_ids(1, zones: [hat.id, zones(:soundeffects).id]) }
				.to raise_error(Roulette::InvalidRequest, /Zone 2 can't be requested/)
		end

		it "accepts zones as a comma-separated string" do
			hat_item = build_item(name: "Hat", body_ids: [1], zones: [hat])

			expect(Roulette.pick_item_ids(1, rng: Random.new(42), zones: "#{hat.id}"))
				.to eq([hat_item.id])

			expect { Roulette.pick_item_ids(1, zones: "#{hat.id},") }
				.to raise_error(Roulette::InvalidRequest, /empty entry/)
			expect { Roulette.pick_item_ids(1, zones: "#{hat.id},,#{shirt.id}") }
				.to raise_error(Roulette::InvalidRequest, /empty entry/)

			# Spaces after the commas are fine, though.
			expect(Roulette.pick_item_ids(1, rng: Random.new(42), zones: "#{hat.id}, #{hat.id}"))
				.to eq([hat_item.id])

			expect { Roulette.pick_item_ids(1, zones: "1_0") }
				.to raise_error(Roulette::InvalidRequest, /Unknown zone: 1_0/)
		end

		it "raises on an unknown zone" do
			expect { Roulette.pick_item_ids(1, zones: [99]) }
				.to raise_error(ArgumentError, /Unknown zone/)

			expect { Roulette.pick_item_ids(1, zones: [0]) }
				.to raise_error(ArgumentError, /Unknown zone/)

			expect { Roulette.pick_item_ids(1, zones: ["nope"]) }
				.to raise_error(ArgumentError)

			# One bad ID fails the whole request, rather than filling some of
			# the zones.
			expect { Roulette.pick_item_ids(1, zones: [hat.id, 99]) }
				.to raise_error(ArgumentError, /Unknown zone: 99/)
		end

		it "treats duplicate zone IDs as one" do
			hat_item = build_item(name: "Hat", body_ids: [1], zones: [hat])

			chosen = Roulette.pick_item_ids(1, rng: Random.new(42), zones: [hat.id, hat.id])
			expect(chosen).to eq([hat_item.id]) # One hat, not two.
		end

		it "fills everything when the count exceeds the available zones" do
			Zone.where.not(id: Roulette::EXCLUDED_ZONE_IDS).order(:id).first(20).each_with_index do |zone, i|
				build_item(name: "Item #{i + 1}", body_ids: [1], zones: [zone])
			end

			# Only twenty zones have items, so a count of fifty fills them all.
			chosen = Roulette.pick_item_ids(1, rng: Random.new(42), zone_count: 50)
			expect(chosen.size).to eq(20)
		end

		it "fills everything for a full outfit" do
			hat_item = build_item(name: "Hat", body_ids: [1], zones: [hat])
			Zone.order(:id).where.not(id: [hat.id, *Roulette::EXCLUDED_ZONE_IDS]).limit(20).each do |zone|
				build_item(name: "Item #{zone.id}", body_ids: [1], zones: [zone])
			end

			chosen = Roulette.pick_item_ids(1, rng: Random.new(42), full_outfit: true)
			expect(chosen.size).to eq(21) # Every zone, hat included.
			expect(chosen).to include(hat_item.id)
		end

		it "refuses to mix a full outfit with count or zones" do
			expect { Roulette.pick_item_ids(1, full_outfit: true, zone_count: 3) }
				.to raise_error(Roulette::InvalidRequest, /full can't be combined/)

			expect { Roulette.pick_item_ids(1, full_outfit: true, zones: [hat.id]) }
				.to raise_error(Roulette::InvalidRequest, /full can't be combined/)

			# Even count=0 (a bare pet) contradicts a full outfit.
			expect { Roulette.pick_item_ids(1, full_outfit: true, zone_count: 0) }
				.to raise_error(Roulette::InvalidRequest)
		end

		it "refuses to mix count with zones" do
			expect { Roulette.pick_item_ids(1, zone_count: 3, zones: [hat.id]) }
				.to raise_error(Roulette::InvalidRequest, /count can't be combined with zones/)

			# Even count=0 (a bare pet) contradicts filling specific zones.
			expect { Roulette.pick_item_ids(1, zone_count: 0, zones: [hat.id]) }
				.to raise_error(Roulette::InvalidRequest)
		end

		it "favors zones with more items, but still visits the thin ones" do
			# One lone hat (like a "Be-Gone!" item alone in its zone), and a big
			# pool of shirts. With a single zone to fill, the hat zone's chance is
			# its weight's share of the total: 1 / (1 + 24^exponent).
			thin = build_item(name: "Lone Hat", body_ids: [1], zones: [hat])
			24.times { |i| build_item(name: "Shirt #{i}", body_ids: [1], zones: [shirt]) }

			spins = 600
			thin_picks = spins.times.count do |seed|
				Roulette.pick_item_ids(1, rng: Random.new(seed), zone_count: 1) == [thin.id]
			end

			expected = 1 / (1 + 24**Roulette::ZONE_WEIGHT_EXPONENT)
			expect(thin_picks.fdiv(spins)).to be_within(0.05).of(expected)
			expect(expected).to be < 0.5 # Sanity: it's less than an even split.
		end

		it "fills requested zones no matter how few items they have" do
			thin = build_item(name: "Lone Hat", body_ids: [1], zones: [hat])
			24.times { |i| build_item(name: "Shirt #{i}", body_ids: [1], zones: [shirt]) }

			10.times do |seed|
				expect(Roulette.pick_item_ids(1, rng: Random.new(seed), zones: [hat.id]))
					.to eq([thin.id])
			end
		end

		it "picks at most one item per zone" do
			a = build_item(name: "Shirt A", body_ids: [1], zones: [shirt])
			b = build_item(name: "Shirt B", body_ids: [1], zones: [shirt])

			10.times do
				chosen = Roulette.pick_item_ids(1, rng: Random.new)
				expect((chosen & [a.id, b.id]).size).to eq(1)
			end
		end

		it "never picks an item that conflicts with a chosen one" do
			# The shirt restricts the hat zone, so it can't be worn with the hat.
			a = build_item(name: "Restrictive Shirt", body_ids: [1], zones: [shirt],
			              restricts: [hat.id])
			b = build_item(name: "Hat", body_ids: [1], zones: [hat])

			10.times do
				chosen = Roulette.pick_item_ids(1, rng: Random.new)
				expect((chosen & [a.id, b.id]).size).to eq(1)
			end
		end

		it "understands the short zones_restrict strings old items have" do
			# Old items' bit strings are shorter than 52 characters, and the
			# missing characters are just "0"s. Here a 40-character string's
			# last character restricts zone 40, the hat's zone.
			a = build_item(name: "Short Restrict Shirt", body_ids: [1], zones: [shirt],
			              restricts_raw: "0" * 39 + "1")
			b = build_item(name: "Hat", body_ids: [1], zones: [hat])

			10.times do
				chosen = Roulette.pick_item_ids(1, rng: Random.new)
				expect((chosen & [a.id, b.id]).size).to eq(1)
			end
		end

		it "handles items that occupy multiple zones" do
			a = build_item(name: "Shirt", body_ids: [1], zones: [shirt])
			b = build_item(name: "Hat", body_ids: [1], zones: [hat])
			c = build_item(name: "Dress", body_ids: [1], zones: [shirt, hat])

			# The dress blocks both the shirt and the hat; without it, they
			# can be worn together.
			10.times do
				chosen = Roulette.pick_item_ids(1, rng: Random.new)
				if chosen.include?(c.id)
					expect(chosen).to contain_exactly(c.id)
				else
					expect(chosen).to contain_exactly(a.id, b.id)
				end
			end
		end

		it "never picks items that don't fit the body" do
			a = build_item(name: "Fits Body 2", body_ids: [2], zones: [shirt])

			expect(Roulette.pick_item_ids(1, rng: Random.new(42))).to be_nil
			expect(Roulette.pick_item_ids(2, rng: Random.new(42))).to contain_exactly(a.id)
		end

		it "skips items that occupy no zones, like style tokens" do
			build_item(name: "Style Token", body_ids: [1], zones: [])
			a = build_item(name: "Shirt", body_ids: [1], zones: [shirt])

			expect(Roulette.pick_item_ids(1, rng: Random.new(42)))
				.to contain_exactly(a.id)
		end

		it "never wears items in the music or sound effects zones" do
			build_item(name: "Song", body_ids: [1], zones: [zones(:music)])
			build_item(name: "Song and Hat", body_ids: [1], zones: [zones(:music), hat])
			build_item(name: "Sound", body_ids: [1], zones: [zones(:soundeffects)])
			a = build_item(name: "Shirt", body_ids: [1], zones: [shirt])

			20.times do |seed|
				expect(Roulette.pick_item_ids(1, rng: Random.new(seed), full_outfit: true))
					.to contain_exactly(a.id)
			end

			# Asking for the zones by ID doesn't get around it: that's a 400.
			expect { Roulette.pick_item_ids(1, zones: [zones(:music).id, zones(:soundeffects).id]) }
				.to raise_error(Roulette::InvalidRequest)
		end

		it "returns nil when no items fit" do
			expect(Roulette.pick_item_ids(99, rng: Random.new(42))).to be_nil
		end
	end
end
