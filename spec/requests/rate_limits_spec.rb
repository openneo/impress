require_relative '../rails_helper'
require_relative '../support/account_data_helpers'

# Checks our Rack::Attack config, in config/initializers/attack.rb.
RSpec.describe "Rate limits", :account_data, type: :request do
  # Rack::Attack uses `Rails.cache`, which is a null store in tests, so swap in
  # a real store for these tests.
  around do |example|
    original_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rack::Attack.cache.store = original_store
  end

  # In tests, Rails loads routes lazily, on the first request (or path helper
  # call). But Devise sets up its login strategies when the routes load, so if
  # the first request of the test run is a login, it fails! Load them first.
  before { Rails.application.reload_routes_unless_loaded }

  def log_in(name, password: "wrong-password", ip: "1.2.3.4", path: "/users/sign_in")
    post path, params: {auth_user: {name: name, password: password}},
      env: {"REMOTE_ADDR" => ip}
  end

  def expect_login_throttled
    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to("/users/sign_in")
    follow_redirect!
    expect(flash[:alert]).to include("a lot of login attempts")
  end

  def expect_login_not_throttled
    # Devise re-renders the login form for a bad password, with this status.
    expect(response).to have_http_status(:unprocessable_entity)
  end

  describe "logging in" do
    before { create_account("Victim") }

    it "allows a few failed attempts" do
      10.times { log_in("Victim") }
      expect_login_not_throttled
    end

    it "limits attempts against one account, even from different IPs" do
      10.times { |n| log_in("Victim", ip: "10.0.0.#{n}") }
      log_in("Victim", ip: "10.0.1.1")
      expect_login_throttled
    end

    it "treats different spellings of the same username as the same account" do
      # Our database collation treats these all as matching "Victim"!
      spellings = ["victim", "VICTIM", " Victim ", "Víctim", "VÍCTIM"]
      10.times do |n|
        log_in(spellings[n % spellings.size], ip: "10.0.0.#{n}")
      end
      log_in("vIcTiM", ip: "10.0.1.1")
      expect_login_throttled
    end

    it "limits attempts that send the username as a non-string" do
      # Devise converts JSON numbers etc. to strings, so this logs into the
      # account named "12345". It should count against that account!
      create_account("12345")
      10.times do |n|
        post "/users/sign_in.json",
          params: {auth_user: {name: 12345, password: "nope"}}.to_json,
          headers: {"CONTENT_TYPE" => "application/json"},
          env: {"REMOTE_ADDR" => "10.0.0.#{n}"}
      end
      log_in("12345", ip: "10.0.1.1")
      expect_login_throttled
    end

    it "limits attempts against a nonexistent account, too" do
      10.times { |n| log_in("nobody", ip: "10.0.0.#{n}") }
      log_in("NOBODY", ip: "10.0.1.1")
      expect_login_throttled
    end

    it "keeps each account's limit separate" do
      create_account("Bystander")
      10.times { |n| log_in("Victim", ip: "10.0.0.#{n}") }
      log_in("Bystander", password: "password123", ip: "10.0.1.1")
      expect(response).to redirect_to(root_path)
    end

    it "limits attempts from one IP, even against different accounts" do
      30.times { |n| log_in("user#{n}") }
      log_in("Victim", password: "password123")
      expect_login_throttled
    end

    it "groups IPv6 addresses by /64" do
      30.times { |n| log_in("user#{n}", ip: "2001:db8:1:2::#{n + 1}") }
      log_in("someone", ip: "2001:db8:1:2:ffff::1")
      expect_login_throttled

      log_in("someone", ip: "2001:db8:1:3::1")
      expect_login_not_throttled
    end

    it "limits attempts made via alternate paths and JSON bodies" do
      paths = ["/users/sign_in.json", "//users//sign_in/", "/users/sign_in.html"]
      9.times do |n|
        post paths[n % paths.size],
          params: {auth_user: {name: "victim", password: "nope"}}.to_json,
          headers: {"CONTENT_TYPE" => "application/json"},
          env: {"REMOTE_ADDR" => "10.0.0.#{n}"}
      end
      log_in("Victim", ip: "10.0.1.1")
      log_in("Victim", ip: "10.0.1.2")
      expect_login_throttled
    end

    it "exempts browsers that have logged into this account before" do
      # Our victim logs in on their usual device, then logs out.
      log_in("Victim", password: "password123", ip: "10.0.9.9")
      expect(response).to redirect_to(root_path)
      delete "/users/sign_out"

      # Meanwhile, an attacker (with their own cookies) uses up the account's
      # limit.
      open_session do |attacker|
        10.times do |n|
          attacker.post "/users/sign_in",
            params: {auth_user: {name: "victim", password: "nope"}},
            env: {"REMOTE_ADDR" => "10.0.0.#{n}"}
        end
        # NOTE: The `redirect_to` matcher only checks the main session, so we
        #       check the attacker's response by hand.
        expect(attacker.response).to have_http_status(:see_other)
        expect(attacker.response.location).to eq("/users/sign_in")
      end

      # Our victim can still log in from their usual device.
      log_in("Victim", password: "password123", ip: "10.0.9.9")
      expect(response).to redirect_to(root_path)
    end

    it "doesn't exempt browsers that only logged into other accounts" do
      create_account("Attacker")
      log_in("Attacker", password: "password123", ip: "10.0.9.9")
      expect(response).to redirect_to(root_path)
      delete "/users/sign_out"

      10.times { |n| log_in("Victim", ip: "10.0.0.#{n}") }
      log_in("Victim", ip: "10.0.1.1")
      expect_login_throttled
    end

    it "responds with a 429 to JSON requests" do
      10.times { |n| log_in("Victim", ip: "10.0.0.#{n}") }
      log_in("Victim", ip: "10.0.1.1", path: "/users/sign_in.json")
      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["retry-after"].to_i).to be_between(1, 600)
    end

    it "doesn't count other requests" do
      40.times { get "/users/sign_in", env: {"REMOTE_ADDR" => "1.2.3.4"} }
      log_in("Victim", password: "password123")
      expect(response).to redirect_to(root_path)
    end
  end

  describe "sending password reset emails" do
    before { create_account("Victim") }

    def request_reset(email, ip: "1.2.3.4")
      post "/users/password", params: {auth_user: {email: email}},
        env: {"REMOTE_ADDR" => ip}
    end

    it "limits how many we send to one account, even from different IPs" do
      3.times { |n| request_reset("victim@example.com", ip: "10.0.0.#{n}") }
      expect(response).not_to redirect_to("/users/password/new")

      # Our database collation treats this as matching, too!
      request_reset("VÍCTIM@example.com", ip: "10.0.1.1")
      expect(response).to redirect_to("/users/password/new")
      follow_redirect!
      expect(flash[:alert]).to include("a lot of password reset emails")
    end

    it "limits how many we send from one IP" do
      10.times { |n| request_reset("someone#{n}@example.com") }
      request_reset("victim@example.com")
      expect(response).to redirect_to("/users/password/new")
    end
  end

  describe "loading pets" do
    before do
      allow(Pet).to receive(:load).
        and_raise(Neopets::CustomPets::PetNotFound)
    end

    it "redirects home with a message, once limited" do
      3.times { get "/pets/load", params: {name: "x"} }
      expect(response).not_to redirect_to("/")

      get "/pets/load", params: {name: "x"}
      expect(response).to redirect_to("/")
      expect(flash[:warning]).to include("a lot of pet names")
    end

    it "responds with a plain error to JSON requests, once limited" do
      4.times { get "/pets/load.json", params: {name: "x"} }
      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).to include("a lot of pet names")
    end
  end
end
