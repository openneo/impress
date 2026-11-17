require_relative '../../rails_helper'
require_relative '../../support/mocks/custom_pets'

RSpec.describe PetType::RainbowPoolImport do
  fixtures :colors, :species, :zones

  let(:chia) { Species.find_by_name!("chia") }
  let(:blue) { Color.find_by_name!("blue") }
  let(:purple) { Color.find_by_name!("purple") }
  let(:log) { [] }

  let(:birthday_brush) do
    {item_id: 100585, color_id: 999, name: "Birthday Paint Brush",
      image_url: "https://images.neopets.com/items/f4b5d6b0.gif"}
  end

  before do
    allow(DiscordNotifier).to receive(:notify_new_colors)
    allow(Sentry).to receive(:capture_exception)
    allow(Sentry).to receive(:capture_message)
    # The test env uses a null cache; use a real one, to remember failures.
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
  end

  def entry(color_id, name, image_hash)
    {color_id:, name:, image_hash:}
  end

  def import(entries, species: chia, **options)
    PetType::RainbowPoolImport.new({species.id => entries},
      log: ->(message) { log << message }, **options).run!
  end

  context "for a pet type we already have" do
    let!(:blue_chia) do
      PetType.create!(species: chia, color: blue, body_id: 212,
        basic_image_hash: "oldhash")
    end

    it "updates its image hash, without modeling" do
      expect(Pet).not_to receive(:load)
      result = import([entry(blue.id, "Blue", "newhash")])
      expect(blue_chia.reload.basic_image_hash).to eq "newhash"
      expect(result.updated_pet_types).to eq [blue_chia]
      expect(result.modeled_pet_types).to be_empty
    end

    it "leaves a matching image hash alone" do
      result = import([entry(blue.id, "Blue", "oldhash")])
      expect(result.updated_pet_types).to be_empty
    end

    it "matches by color ID, not name" do
      result = import([entry(blue.id, "Bleu", "newhash")])
      expect(blue_chia.reload.basic_image_hash).to eq "newhash"
      expect(result.new_colors).to be_empty
    end
  end

  context "for a pet type we don't have, of a color we know" do
    it "models it from its image hash" do
      result = import([entry(purple.id, "Purple", "rp-purple-chia")])

      pet_type = PetType.find_by!(species: chia, color: purple)
      expect(pet_type.basic_image_hash).to eq "rp-purple-chia"
      expect(pet_type.body_id).to eq 212
      expect(pet_type.pet_states.count).to eq 1
      expect(result.modeled_pet_types).to eq [pet_type]
      expect(result.new_colors).to be_empty
    end

    it "doesn't model it again next time" do
      import([entry(purple.id, "Purple", "rp-purple-chia")])
      expect(Pet).not_to receive(:load)
      import([entry(purple.id, "Purple", "rp-purple-chia")])
    end
  end

  context "for a color we've never seen" do
    let(:entries) { [entry(999, "Birthday", "rp-birthday-chia")] }

    context "with a paint brush" do
      subject(:result) { import(entries, brushes: [birthday_brush]) }

      it "creates the color, with paint brush info" do
        expect(result.new_colors).to eq [Color.find(999)]
        color = Color.find(999)
        expect(color.name).to eq "birthday"
        expect(color.basic).to be false
        expect(color.standard).to be false
        expect(color.pb_item_name).to eq "Birthday Paint Brush"
        expect(color.pb_item_thumbnail_url).to eq birthday_brush[:image_url]
      end

      it "uses the Rainbow Pool's name, not the brush's" do
        import([entry(999, "Bday", "rp-birthday-chia")],
          brushes: [birthday_brush])
        expect(Color.find(999).name).to eq "bday"
      end

      it "models the pet type, too" do
        result
        pet_type = PetType.find_by!(species: chia, color_id: 999)
        expect(pet_type.body_id).to eq 9999
        expect(pet_type.basic_image_hash).to eq "rp-birthday-chia"
      end

      it "notifies Discord, so a human can check the new color" do
        result
        expect(DiscordNotifier).to have_received(:notify_new_colors).
          with([Color.find(999)])
      end
    end

    context "without a paint brush" do
      it "creates the color, without paint brush info" do
        import(entries)
        expect(Color.find(999).name).to eq "birthday"
        expect(Color.find(999).pb_item_name).to be_nil
      end
    end

    it "prefers the name from the full color list" do
      import([entry(999, "Bday", "rp-birthday-chia")],
        colors: [{id: 999, name: "Birthday"}])
      expect(Color.find(999).name).to eq "birthday"
    end

    it "creates colors from the full list, even with no species listed" do
      PetType::RainbowPoolImport.new({}, colors: [{id: 999, name: "Birthday"}],
        log: ->(message) { log << message }).run!
      expect(Color.find(999).name).to eq "birthday"
    end

    it "keeps the color, even if its pet type fails to model" do
      allow_any_instance_of(Pet).to receive(:save!).and_raise("oh no")
      result = import(entries)
      expect(result.modeled_pet_types).to be_empty
      expect(Color.find(999).name).to eq "birthday"
    end

    it "doesn't create a second color with the same name" do
      result = import([entry(999, "Purple", "rp-birthday-chia")])
      expect(Color.exists?(999)).to be false
      expect(result.new_colors).to be_empty
      expect(Sentry).to have_received(:capture_message).
        with(/we already have a color by that name/, anything).once
      expect(DiscordNotifier).not_to have_received(:notify_new_colors)
    end

    it "only sends a name conflict to Sentry once a day" do
      import([entry(999, "Purple", "rp-birthday-chia")])
      import([entry(999, "Purple", "rp-birthday-chia")])
      expect(Sentry).to have_received(:capture_message).once
    end
  end

  context "for a color we have, without paint brush info" do
    let(:brush) do
      {item_id: 1, color_id: purple.id, name: "Purple Paint Brush",
        image_url: "https://images.neopets.com/items/purplepb.gif"}
    end

    it "fills it in" do
      result = import([entry(purple.id, "Purple", "rp-purple-chia")],
        brushes: [brush])
      expect(purple.reload.pb_item_name).to eq "Purple Paint Brush"
      expect(purple.pb_item_thumbnail_url).to eq brush[:image_url]
      expect(result.updated_colors).to eq [purple]
    end

    it "prefers the brush named after the color" do
      starter = brush.merge(item_id: 0, name: "Starter Purple Paint Brush")
      import([entry(purple.id, "Purple", "rp-purple-chia")],
        brushes: [starter, brush])
      expect(purple.reload.pb_item_name).to eq "Purple Paint Brush"
    end

    it "otherwise, picks the oldest brush" do
      fancy = brush.merge(item_id: 5, name: "Fancy Purple Paint Brush")
      plain = brush.merge(item_id: 2, name: "Plain Purple Paint Brush")
      import([entry(purple.id, "Purple", "rp-purple-chia")],
        brushes: [fancy, plain])
      expect(purple.reload.pb_item_name).to eq "Plain Purple Paint Brush"
    end

    it "prefers the brush we already know about, to fill in its thumbnail" do
      purple.update!(pb_item_name: "Starter Purple Paint Brush")
      starter = brush.merge(item_id: 0, name: "Starter Purple Paint Brush",
        image_url: "https://images.neopets.com/items/starterpurplepb.gif")
      import([entry(purple.id, "Purple", "rp-purple-chia")],
        brushes: [starter, brush])
      expect(purple.reload.pb_item_thumbnail_url).to eq starter[:image_url]
    end

    it "doesn't overwrite info we already have" do
      purple.update!(pb_item_name: "Our Purple Brush")
      import([entry(purple.id, "Purple", "rp-purple-chia")], brushes: [brush])
      expect(purple.reload.pb_item_name).to eq "Our Purple Brush"
      expect(purple.pb_item_thumbnail_url).to eq brush[:image_url]
    end
  end

  it "skips images that turn out to be a different color" do
    # The Rainbow Pool says this is Purple, but it's actually color #999.
    result = import([entry(purple.id, "Purple", "rp-birthday-chia")])
    expect(result.modeled_pet_types).to be_empty
    expect(PetType.where(species: chia).count).to eq 0
    expect(Sentry).to have_received(:capture_message).
      with("Rainbow Pool image doesn't match its listing", anything)
  end

  it "skips images that turn out to be a different species" do
    acara = Species.find_by_name!("acara")
    result = import([entry(purple.id, "Purple", "rp-purple-chia")],
      species: acara)
    expect(result.modeled_pet_types).to be_empty
    expect(log).to include(a_string_matching(/species ##{chia.id}/))
  end

  it "models at most `max_to_model` pet types per run" do
    entries = [entry(purple.id, "Purple", "rp-purple-chia"),
      entry(999, "Birthday", "rp-birthday-chia")]

    result = import(entries, max_to_model: 1)
    expect(result.modeled_pet_types.size).to eq 1
    expect(log).to include(a_string_matching(/which is our limit/))

    # The other one gets its turn next run.
    result = import(entries, max_to_model: 1)
    expect(result.modeled_pet_types.size).to eq 1
    expect(PetType.where(species: chia).count).to eq 2
  end

  it "sends Discord one message for all the new colors" do
    import([entry(999, "Birthday", "rp-birthday-chia")],
      colors: [{id: 998, name: "Unbirthday"}, {id: 999, name: "Birthday"}])
    expect(DiscordNotifier).to have_received(:notify_new_colors).once.
      with(contain_exactly(Color.find(998), Color.find(999)))
  end

  it "still tells Discord about new colors if something fails later" do
    allow(PetType).to receive(:all).and_raise("oh no")
    expect { import([entry(999, "Birthday", "rp-birthday-chia")]) }.
      to raise_error("oh no")
    expect(DiscordNotifier).to have_received(:notify_new_colors).
      with([Color.find(999)])
  end

  context "checking species" do
    def import_with_species(species)
      PetType::RainbowPoolImport.new({}, species:,
        log: ->(message) { log << message }).run!
    end

    let(:all_known_species) do
      Species.all.map { |s| {id: s.id, name: s.human_name} }
    end

    it "warns about species we don't have" do
      import_with_species(all_known_species + [{id: 999, name: "Newbie"}])
      expect(Sentry).to have_received(:capture_message).once.
        with(/lists a species we don't have: Newbie/, anything)
    end

    it "warns about species we have that aren't listed" do
      import_with_species(all_known_species.reject { |s| s[:id] == chia.id })
      expect(Sentry).to have_received(:capture_message).once.
        with(/doesn't list a species we have: Chia/, anything)
    end

    it "only warns once a day" do
      2.times { import_with_species(all_known_species + [{id: 999, name: "Newbie"}]) }
      expect(Sentry).to have_received(:capture_message).once
      expect(log.grep(/Newbie/).size).to eq 2
    end

    it "is quiet when everything matches" do
      import_with_species(all_known_species)
      expect(Sentry).not_to have_received(:capture_message)
    end

    it "skips the check when the species list didn't load" do
      import_with_species([])
      expect(Sentry).not_to have_received(:capture_message)
    end
  end

  it "logs error messages that aren't valid UTF-8" do
    allow(Pet).to receive(:load).and_raise(RuntimeError.new("caf\xC3\xA9 \xFF".b))
    expect { import([entry(purple.id, "Purple", "rp-purple-chia")]) }.
      not_to raise_error
    expect(log).to include(a_string_matching(/Failed to model .* café/))
  end

  it "skips pet types that fail to model, and carries on" do
    result = import([entry(888, "Mystery", "not-a-real-hash"),
      entry(purple.id, "Purple", "rp-purple-chia")])
    expect(result.modeled_pet_types.map(&:color)).to eq [purple]
    expect(Sentry).to have_received(:capture_exception).once
  end

  it "doesn't retry failures on the next run" do
    import([entry(purple.id, "Purple", "not-a-real-hash")])
    expect(Pet).not_to receive(:load)
    import([entry(purple.id, "Purple", "not-a-real-hash")])
    expect(Sentry).to have_received(:capture_exception).once
  end

  it "skips modeling when modeling is disabled" do
    allow(Rails.configuration).to receive(:modeling_enabled).and_return(false)
    result = import([entry(purple.id, "Purple", "rp-purple-chia")])
    expect(result.modeled_pet_types).to be_empty
    expect(Sentry).not_to have_received(:capture_exception)
  end
end
