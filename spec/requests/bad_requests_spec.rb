require_relative '../rails_helper'

# Scanners send SQL injection probes in params. Where that input is malformed,
# we should answer 400, not 500 (which also reports an error to GlitchTip).
RSpec.describe "Malformed requests", type: :request do
  it "answers 400 for a page number that isn't a number" do
    get "/contributions", params: {page: "2' AND EXTRACTVALUE(1,CONCAT(0x7e,1))-- -"}
    expect(response).to have_http_status(:bad_request)
  end

  it "answers 400 for a page number that's out of range" do
    get "/contributions", params: {page: "0"}
    expect(response).to have_http_status(:bad_request)
  end

  it "still serves a valid page number" do
    get "/contributions", params: {page: "2"}
    expect(response).to have_http_status(:ok)
  end

  it "answers 400 for a locale return_to that isn't a safe path" do
    post "/locales/choose", params: {locale: "en", return_to: "' ORDER BY 1-- -"}
    expect(response).to have_http_status(:bad_request)
  end

  it "answers 400 for a locale return_to on another host" do
    post "/locales/choose", params: {locale: "en", return_to: "https://evil.example/"}
    expect(response).to have_http_status(:bad_request)
  end

  it "still follows a locale return_to that's a local path" do
    post "/locales/choose", params: {locale: "en", return_to: "/items"}
    expect(response).to redirect_to("/items")
  end

  it "sends a pet-load error home when the origin is on another host" do
    allow(Pet).to receive(:load).and_raise(Neopets::CustomPets::PetNotFound)
    get "/pets/load", params: {name: "thyassa", origin: "https://evil.example/"}
    expect(response).to redirect_to("/?name=thyassa")
  end

  it "sends a pet-load error home when the origin isn't a path" do
    allow(Pet).to receive(:load).and_raise(Neopets::CustomPets::PetNotFound)
    get "/pets/load", params: {name: "thyassa", origin: "') AND ('a'='a"}
    expect(response).to redirect_to("/?name=thyassa")
  end

  it "sends a pet-load error home when the origin has a probe appended" do
    allow(Pet).to receive(:load).and_raise(Neopets::CustomPets::PetNotFound)
    get "/pets/load", params: {name: "thyassa", origin: "/modeling' AND 1=1-- -"}
    expect(response).to redirect_to("/?name=thyassa")
  end

  it "sends a locale change back to the referrer without a return_to" do
    post "/locales/choose", params: {locale: "en"},
      headers: {"Referer" => "http://www.example.com/items"}
    expect(response).to redirect_to("http://www.example.com/items")
  end

  it "sends a locale change home without a return_to or referrer" do
    post "/locales/choose", params: {locale: "en"}
    expect(response).to redirect_to("/")
  end

  it "still sends a pet-load error back to a local origin" do
    allow(Pet).to receive(:load).and_raise(Neopets::CustomPets::PetNotFound)
    get "/pets/load", params: {name: "thyassa", origin: "/modeling"}
    expect(response).to redirect_to("/modeling?name=thyassa")
  end

  it "answers 400 for item search filters that aren't hashes" do
    get "/items.json", params: {q: {name: "frost"}}
    expect(response).to have_http_status(:bad_request)
  end

  it "still searches items with hash filters" do
    get "/items.json", params: {q: {"0" => {key: "name", value: "frost"}}}
    expect(response).to have_http_status(:ok)
  end
end
