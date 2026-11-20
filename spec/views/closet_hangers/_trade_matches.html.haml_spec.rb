require_relative '../../rails_helper'

RSpec.describe "closet_hangers/_trade_matches", type: :view do
  def render_matches(trade_matches)
    render partial: "closet_hangers/trade_matches",
      locals: {trade_matches: trade_matches}
    Nokogiri::HTML.fragment(rendered).at_css("script#trade-matches")
  end

  it "renders the matches as JSON" do
    script = render_matches(owns: {1 => [{name: "UFT", trading: true}]},
      wants: {2 => [{name: nil, trading: false}]})

    expect(script["type"]).to eq "application/json"
    expect(JSON.parse(script.text)).to eq(
      "owns" => {"1" => [{"name" => "UFT", "trading" => true}]},
      "wants" => {"2" => [{"name" => nil, "trading" => false}]},
    )
  end

  it "can't be broken out of by a list name" do
    name = %{</script><img src=x onerror="alert(1)">}
    script = render_matches(owns: {1 => [{name: name, trading: false}]},
      wants: {})

    expect(rendered).not_to include("</script><img")
    expect(JSON.parse(script.text)["owns"]["1"].first["name"]).to eq name
  end
end
