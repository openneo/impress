require 'rake'
require_relative '../../rails_helper'

RSpec.describe "itemdb:import:styles" do
	fixtures :colors, :species, :zones

	before(:all) do
		Rails.application.load_tasks unless Rake::Task.task_defined?("itemdb:import:styles")
	end

	around do |example|
		old_env = ENV.to_h.slice("DRY_RUN", "FORCE")
		example.run
	ensure
		ENV.delete("DRY_RUN")
		ENV.delete("FORCE")
		ENV.update(old_env)
	end

	def token(id, name, description: nil, image: name.parameterize(separator: "_"))
		Itemdb::Item.new(id:, name:, description:, slug: name.parameterize,
			thumbnail_url: "https://images.neopets.com/items/#{image}.gif")
	end

	def stub_itemdb(*tokens)
		allow(Itemdb).to receive(:load_style_tokens).
			and_return(tokens.index_by(&:id))
		allow(Itemdb).to receive(:load_items).and_return({})
	end

	# Skip the prerequisites (i.e. the environment), and return what it printed.
	def run_task
		old_stdout = $stdout
		$stdout = StringIO.new
		Rake::Task["itemdb:import:styles"].execute
		$stdout.string
	ensure
		$stdout = old_stdout
	end

	def create_style(id, **attributes)
		AltStyle.create!(id:, color: colors(:blue), species: species(:acara),
			body_id: 607, **attributes)
	end

	describe "for an unlabeled style" do
		let!(:style) do
			create_style(87966,
				thumbnail_url: "https://images.neopets.com/items/mall_bg_circle.gif")
		end

		it "takes its name, series, thumbnail, and description from itemdb" do
			stub_itemdb(token(87966, "Nostalgic Blue Acara",
				description: "So nostalgic!"))

			run_task

			style.reload
			expect(style.real_full_name).to eq "Nostalgic Blue Acara"
			expect(style.real_series_name).to eq "Nostalgic"
			expect(style.thumbnail_url).
				to eq "https://images.neopets.com/items/nostalgic_blue_acara.gif"
			expect(style.token_item.name).to eq "Nostalgic Blue Acara"
			expect(style.token_item.description).to eq "So nostalgic!"
		end

		it "skips names that don't end in the species name" do
			stub_itemdb(token(87966, "Some Other Item"))

			output = run_task

			expect(output).to include "Name doesn't end in \"Acara\""
			expect(style.reload).not_to be_labeled
		end
	end

	describe "for a style Neopets has renamed" do
		let!(:style) do
			create_style(89455, real_full_name: "Nostalgic Blue Acara",
				real_series_name: "Nostalgic",
				thumbnail_url: "https://images.neopets.com/items/nostalgic_blue_acara.gif")
		end

		it "takes the new name, series, and thumbnail, and then the description" do
			stub_itemdb(token(89455, "Fluttering Blue Acara",
				description: "Prepare to take flight!", image: "8nnc95lg5h"))

			output = run_task

			style.reload
			expect(style.real_full_name).to eq "Fluttering Blue Acara"
			expect(style.real_series_name).to eq "Fluttering"
			expect(style.thumbnail_url).
				to eq "https://images.neopets.com/items/8nnc95lg5h.gif"

			item = style.token_item
			expect(item.name).to eq "Fluttering Blue Acara"
			expect(item.thumbnail_url).
				to eq "https://images.neopets.com/items/8nnc95lg5h.gif"
			expect(item.description).to eq "Prepare to take flight!"

			expect(output).to include "1 renamed"
			expect(output).to include "1 descriptions added"
		end

		it "names styles that only had a series name" do
			style.update!(real_full_name: nil)
			stub_itemdb(token(89455, "Fluttering Blue Acara"))

			run_task

			style.reload
			expect(style.real_full_name).to eq "Fluttering Blue Acara"
			expect(style.real_series_name).to eq "Fluttering"
		end

		it "skips new names with a different color or species" do
			stub_itemdb(token(89455, "Fluttering Faerie Gnorbu",
				description: "Prepare to take flight!"))

			output = run_task

			expect(output).to include "handle manually?"
			expect(output).to include "1 renames to check by hand"
			style.reload
			expect(style.real_full_name).to eq "Nostalgic Blue Acara"
			expect(style.real_series_name).to eq "Nostalgic"
			expect(style.token_item.name).to eq "Nostalgic Blue Acara"
			expect(style.token_item.description).to eq ""
		end

		it "keeps our series name when it can't tell the new one" do
			style.update!(real_full_name: "Prismatic Cocoa: Nostalgic Blue Acara",
				real_series_name: "Prismatic Cocoa: Nostalgic")
			stub_itemdb(token(89455, "Prismatic Cocoa: Blue Acara",
				description: "So jolly!", image: "cocoa"))

			output = run_task

			expect(output).to include "keeping series \"Prismatic Cocoa: Nostalgic\""
			style.reload
			expect(style.real_full_name).to eq "Prismatic Cocoa: Blue Acara"
			expect(style.real_series_name).to eq "Prismatic Cocoa: Nostalgic"
			expect(style.thumbnail_url).
				to eq "https://images.neopets.com/items/cocoa.gif"
			expect(style.token_item.name).to eq "Prismatic Cocoa: Blue Acara"
			expect(style.token_item.description).to eq "So jolly!"
		end

		it "accepts new names that only differ in capitalization" do
			# Like "Celebratory Anniversary JubJub", whose color is "25th
			# Anniversary", so its name doesn't end in its color and species.
			style.update!(real_full_name: "Mini Yellow AcAra",
				real_series_name: "Mini")
			stub_itemdb(token(89455, "Mini Yellow Acara"))

			run_task

			style.reload
			expect(style.real_full_name).to eq "Mini Yellow Acara"
			expect(style.real_series_name).to eq "Mini"
		end

		it "skips new names in a character series the style isn't in" do
			stub_itemdb(token(89455, "Treasured Roberta"))

			output = run_task

			expect(output).to include "handle manually?"
			expect(style.reload.real_full_name).to eq "Nostalgic Blue Acara"
		end

		it "accepts new names in the character series the style is already in" do
			style.update!(real_full_name: "Treasured Roberta",
				real_series_name: "Treasured")
			stub_itemdb(token(89455, "Treasured Roberta of Meridell"))

			run_task

			style.reload
			expect(style.real_full_name).to eq "Treasured Roberta of Meridell"
			expect(style.real_series_name).to eq "Treasured"
		end

		it "skips new names we can't check, even with FORCE=1" do
			ENV["FORCE"] = "1"
			stub_itemdb(token(89455, "Fluttering Faerie Gnorbu"))

			run_task

			expect(style.reload.real_full_name).to eq "Nostalgic Blue Acara"
		end

		it "only reports what it would do, in a dry run" do
			ENV["DRY_RUN"] = "1"
			stub_itemdb(token(89455, "Fluttering Blue Acara",
				description: "Prepare to take flight!"))

			output = run_task

			expect(output).to include "Renamed to \"Fluttering Blue Acara\""
			expect(output).to include "Description is now \"Prepare to take flight!\""
			style.reload
			expect(style.real_full_name).to eq "Nostalgic Blue Acara"
			expect(style.token_item.name).to eq "Nostalgic Blue Acara"
			expect(style.token_item.description).to eq ""
		end
	end

	describe "for a style whose name agrees with itemdb" do
		let!(:style) do
			create_style(87966, real_full_name: "Nostalgic Blue Acara",
				real_series_name: "Nostalgic",
				thumbnail_url: "https://images.neopets.com/items/ours.gif")
		end

		it "leaves the style alone, but adds the token's description" do
			stub_itemdb(token(87966, "Nostalgic Blue Acara", image: "theirs",
				description: "So nostalgic!"))

			output = run_task

			expect(output).to include "0 renamed"
			expect(style.reload.thumbnail_url).
				to eq "https://images.neopets.com/items/ours.gif"
			expect(style.token_item.description).to eq "So nostalgic!"
		end

		it "also matches when we only know the series name" do
			style.update!(real_full_name: nil)
			stub_itemdb(token(87966, "Nostalgic Blue Acara",
				description: "So nostalgic!"))

			output = run_task

			expect(output).to include "0 renamed"
			expect(style.reload.real_full_name).to be_nil
			expect(style.token_item.description).to eq "So nostalgic!"
		end

		it "doesn't describe a token item that isn't really this token" do
			style.token_item.update!(name: "Some Wearable")
			stub_itemdb(token(87966, "Nostalgic Blue Acara",
				description: "So nostalgic!"))

			output = run_task

			expect(output).not_to include "Description is now"
			expect(style.token_item.reload.description).to eq ""
		end

		it "doesn't report that description in a dry run, either" do
			ENV["DRY_RUN"] = "1"
			style.token_item.update!(name: "Some Wearable")
			stub_itemdb(token(87966, "Nostalgic Blue Acara",
				description: "So nostalgic!"))

			output = run_task

			expect(output).not_to include "Description is now"
		end
	end
end
