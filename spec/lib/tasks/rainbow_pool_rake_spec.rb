require 'webmock/rspec'
require 'rake'
require_relative '../../rails_helper'
require_relative '../../support/mocks/custom_pets'

RSpec.describe "neopets:import:rainbow_pool" do
  fixtures :colors, :species, :zones

  let(:fixtures_dir) { Rails.root / "spec" / "fixtures" / "rainbow_pool" }
  let(:pool_url) { Neopets::RainbowPool::URL }

  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("neopets:import:rainbow_pool")
  end

  before do
    NeologinCookie.create!(cookie: "STUB_NEOLOGIN")
    allow(DiscordNotifier).to receive(:notify_new_colors)
    allow(DiscordNotifier).to receive(:notify_neologin_failure)
    allow(Sentry).to receive(:capture_exception)
    allow(Sentry).to receive(:capture_message)
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)

    stub_request(:post, pool_url).with(body: "mode=AllPets").
      to_return(body: (fixtures_dir / "all_pets.json").read)
    stub_request(:post, pool_url).with(body: "mode=Brushes").
      to_return(body: (fixtures_dir / "brushes.json").read)
    stub_request(:post, pool_url).with(body: "f_species_id=1&mode=getAllPetColors").
      to_return(body: (fixtures_dir / "colors_acara.json").read)
  end

  # Skip the prerequisites (the Neologin check and the environment).
  def run_task
    expect { Rake::Task["neopets:import:rainbow_pool"].execute }.
      to output.to_stdout
  end

  def stub_other_species(**response)
    stub_request(:post, pool_url).with(body: /\Af_species_id=(?!1&)/).
      to_return(**response)
  end

  let(:blue_acara) do
    PetType.find_or_create_by!(species_id: 1, color_id: 8) { |pt| pt.body_id = 93 }.
      tap { |pt| pt.update!(basic_image_hash: nil) }
  end

  it "imports colors and image hashes" do
    blue_acara
    stub_other_species(body: '{"success":true,"items":[{"id":8,"name":"Blue",' +
      '"image":"//pets.neopets.com/cp/aaaaaaaa/1/7.png"}]}')

    run_task

    expect(Color.find(121).name).to eq "birthday"
    expect(Color.find(121).pb_item_name).to eq "Birthday Paint Brush"
    expect(blue_acara.reload.basic_image_hash).to eq "mnbztxxn"
    expect(DiscordNotifier).to have_received(:notify_new_colors).once
  end

  it "reports failed species to Sentry as one event, and carries on" do
    blue_acara
    stub_other_species(body: "<html>Redesigned!</html>")

    run_task

    expect(Sentry).to have_received(:capture_exception).once.
      with(Neopets::RainbowPool::UnexpectedResponseFormat, hash_including(
        contexts: hash_including(rainbow_pool: hash_including(
          failed_species_count: Species.count - 1)),
      ))
    expect(blue_acara.reload.basic_image_hash).to eq "mnbztxxn"
  end

  it "doesn't raise if the import itself fails" do
    stub_other_species(body: '{"success":true,"items":[]}')
    allow_any_instance_of(PetType::RainbowPoolImport).to receive(:run!).
      and_raise("oh no")

    run_task

    expect(Sentry).to have_received(:capture_exception).
      with(an_object_having_attributes(message: "oh no"), anything)
  end
end
