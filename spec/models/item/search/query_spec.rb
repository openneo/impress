require_relative '../../../rails_helper'

RSpec.describe Item::Search::Query do
	fixtures :items, :colors, :species

	describe ".from_params" do
		describe "fits filter with an alt style" do
			let(:alt_style) do
				AltStyle.create!(id: 87305, color: colors(:blue), species: species(:acara),
					body_id: 1234, created_at: Time.new(2024, 1, 15))
			end

			# One item that fits the style's body, and one that fits only some
			# other body.
			let(:fitting_item) { items(:straw_hat) }
			let(:other_item) { items(:birthday_bg) }

			before do
				fitting_item.update_columns(cached_compatible_body_ids: [alt_style.body_id])
				other_item.update_columns(cached_compatible_body_ids: [5678])
			end

			def results_for(is_positive:)
				params = {
					"0" => {
						key: "fits",
						value: {alt_style_id: alt_style.id.to_s},
						is_positive: is_positive,
					},
				}
				Item::Search::Query.from_params(params).results
			end

			it "includes only items that fit the style, when positive" do
				results = results_for(is_positive: "true")

				expect(results).to include(fitting_item)
				expect(results).not_to include(other_item)
			end

			it "excludes items that fit the style, when negative" do
				results = results_for(is_positive: "false")

				expect(results).to include(other_item)
				expect(results).not_to include(fitting_item)
			end
		end
	end
end
