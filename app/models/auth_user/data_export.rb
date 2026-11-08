# Builds a complete, machine-readable export of everything Dress to Impress
# stores about a user: their login info, item lists, outfits, contributions,
# and donations.
#
# This is offered from the Settings page (and before account deletion), and is
# also what support uses via `rake users:export`, so it's important that it be
# *complete*. If you add a new table that stores user data, add it here, and
# also to `AuthUser::Deletion`! (spec/models/auth_user/user_data_coverage_spec.rb
# lists every user-data column we know about, and fails on new ones.)
#
# Things we intentionally leave out: password hashes and salts, and the tokens
# Devise uses for "remember me" and password resets. Those are credentials, not
# data about you, and they're no use outside DTI anyway.
class AuthUser::DataExport
  FORMAT_VERSION = 1

  def initialize(auth_user)
    @auth_user = auth_user
    # This *should* always be present, but if a previous deletion only got
    # partway, it might not be! In that case, export what we have.
    @user = auth_user.user
  end

  def as_json(*)
    {
      format: "dress-to-impress-account-export",
      format_version: FORMAT_VERSION,
      exported_at: Time.now.utc.iso8601,
      account: account_data,
      profile: profile_data,
      neopets_connections: neopets_connections_data,
      item_lists: item_lists_data,
      items: items_data,
      outfits: outfits_data,
      contributions: contributions_data,
      donations: donations_data,
    }
  end

  def to_json(*args)
    JSON.pretty_generate(as_json)
  end

  def filename
    "dti-account-#{@auth_user.name.parameterize}-#{Date.today.iso8601}.json"
  end

  private

  def account_data
    {
      name: @auth_user.name,
      email: @auth_user.email,
      neopass_email: @auth_user.neopass_email,
      neopass_id: @auth_user.uses_neopass? ? @auth_user.uid : nil,
      uses_password: @auth_user.uses_password?,
      uses_neopass: @auth_user.uses_neopass?,
      created_at: @auth_user.created_at,
      sign_in_count: @auth_user.sign_in_count,
      current_sign_in_at: @auth_user.current_sign_in_at,
      current_sign_in_ip: @auth_user.current_sign_in_ip,
      last_sign_in_at: @auth_user.last_sign_in_at,
      last_sign_in_ip: @auth_user.last_sign_in_ip,
    }
  end

  def profile_data
    return nil if @user.nil?

    {
      id: @user.id,
      points: @user.points,
      owned_items_visibility:
        visibility_name(@user.owned_closet_hangers_visibility),
      wanted_items_visibility:
        visibility_name(@user.wanted_closet_hangers_visibility),
      contact_neopets_username: @user.contact_neopets_username,
      last_trade_activity_at: @user.last_trade_activity_at,
    }
  end

  def neopets_connections_data
    return [] if @user.nil?

    @user.neopets_connections.order(:id).map do |connection|
      {
        neopets_username: connection.neopets_username,
        created_at: connection.created_at,
      }
    end
  end

  def item_lists_data
    return [] if @user.nil?

    @user.closet_lists.order(:id).map do |list|
      {
        id: list.id,
        name: list.name,
        description: list.description,
        kind: list.hangers_owned? ? "owned" : "wanted",
        visibility: visibility_name(list.visibility),
        created_at: list.created_at,
        updated_at: list.updated_at,
      }
    end
  end

  def items_data
    return [] if @user.nil?

    @user.closet_hangers.includes(:item, :list).order(:id).map do |hanger|
      {
        item_id: hanger.item_id,
        item_name: hanger.item&.name,
        kind: hanger.owned? ? "owned" : "wanted",
        list_id: hanger.list_id,
        list_name: hanger.list&.name,
        quantity: hanger.quantity,
        created_at: hanger.created_at,
        updated_at: hanger.updated_at,
      }
    end
  end

  def outfits_data
    return [] if @user.nil?

    @user.outfits.
      includes(:alt_style, :worn_items, :closeted_items,
        pet_state: {pet_type: [:species, :color]}).
      order(:id).
      map do |outfit|
        pet_type = outfit.pet_state&.pet_type
        {
          id: outfit.id,
          name: outfit.name,
          url: "https://impress.openneo.net/outfits/#{outfit.id}",
          starred: outfit.starred?,
          species: pet_type&.species&.name,
          color: pet_type&.color&.name,
          pose: outfit.pet_state&.pose,
          alt_style_id: outfit.alt_style_id,
          worn_items: outfit.worn_items.map { |i| {id: i.id, name: i.name} },
          closeted_items:
            outfit.closeted_items.map { |i| {id: i.id, name: i.name} },
          created_at: outfit.created_at,
          updated_at: outfit.updated_at,
        }
      end
  end

  def contributions_data
    return [] if @user.nil?

    @user.contributions.order(:id).map do |contribution|
      {
        contributed_type: contribution.contributed_type,
        contributed_id: contribution.contributed_id,
        created_at: contribution.created_at,
      }
    end
  end

  def donations_data
    return [] if @user.nil?

    donations = Fundraising::Donation.where(user_id: @user.id).
      includes(:features).order(:id)
    donations.map do |donation|
      {
        amount_in_cents: donation.amount,
        donor_name: donation.donor_name,
        donor_email: donation.donor_email,
        featured_outfit_ids: donation.features.map(&:outfit_id).compact,
        created_at: donation.created_at,
      }
    end
  end

  def visibility_name(id)
    ClosetVisibility::LEVELS.find { |level| level.id == id }&.name
  end
end
