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

	describe "full name" do
		subject(:alt_style) do
			AltStyle.new(color: colors(:blue), species: species(:acara))
		end

		describe "for a new alt style" do
			it("returns a placeholder value by default") do
				expect(alt_style.full_name).to eq "<New?> Blue Acara"
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
			it("returns the placeholder series name and color name") do
				expect(alt_style.adjective_name).to eq "<New?> Blue"
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
end
