# Permanently deletes a user's account and all of their personal data.
#
# This is the one code path for account deletion: the self-serve button on the
# Settings page uses it, and so does `rake users:delete` for support requests.
# If you add a new table that stores user data, add it here, and also to
# `AuthUser::DataExport`!
#
# What we delete: the login account (in the `openneo_id` database), the user
# record, item lists and the items in them, outfits, Neopets connections, and
# contributions. The *data* people contributed through modeling (items, pet
# appearances, etc) stays, because it belongs to everyone now; we just forget
# who contributed it.
#
# What we keep, but detach from the user: donation records (we need those for
# our financial records, but we clear the donor's name and email), and
# NeoLogin cookies that support staff added.
#
# The two databases can't share a transaction, so we nest them, and do all the
# work in the innermost block: if anything raises, both roll back. The
# remaining gap is if the main database commits and then the auth database
# commit itself fails, which would leave a login with no user data; running
# this again cleans that up.
class AuthUser::Deletion
  class NotAllowed < StandardError; end

  Result = Struct.new(:name, :counts, keyword_init: true)

  def initialize(auth_user)
    @auth_user = auth_user
    @user = auth_user.user
  end

  # Raises `NotAllowed` if this account shouldn't be deleted this way.
  def check_allowed!
    if @user&.support_staff?
      raise NotAllowed, "Support staff accounts can't be deleted until " +
        "their support staff access is removed."
    end
  end

  def call
    check_allowed!

    counts = {}
    AuthRecord.transaction do
      ApplicationRecord.transaction do
        counts = delete_user_data! if @user.present?
        @auth_user.destroy!
      end
    end

    Rails.logger.info "Deleted account #{@auth_user.name.inspect} " +
      "(auth_user_id=#{@auth_user.id}, user_id=#{@user&.id}): #{counts.inspect}"

    Result.new(name: @auth_user.name, counts:)
  end

  private

  def delete_user_data!
    user_id = @user.id
    # A subquery rather than a list of IDs, so we can't miss an outfit that
    # gets saved partway through.
    outfit_ids = Outfit.where(user_id:).select(:id)

    counts = {}

    # Detach records we keep from the data we're about to delete.
    counts[:donations_detached] = Fundraising::Donation.where(user_id:).
      update_all(user_id: nil, donor_name: nil, donor_email: nil)
    counts[:donation_features_detached] = Fundraising::DonationFeature.
      where(outfit_id: outfit_ids).update_all(outfit_id: nil)
    counts[:neologin_cookies_detached] = NeologinCookie.
      where(created_by_id: user_id).update_all(created_by_id: nil)

    # Delete the user's own data. We use `delete_all` rather than `destroy` to
    # keep this fast for users with many thousands of items, so we handle the
    # dependent records ourselves.
    counts[:item_outfit_relationships] = ItemOutfitRelationship.
      where(outfit_id: outfit_ids).delete_all
    counts[:outfits] = Outfit.where(user_id:).delete_all
    counts[:closet_hangers] = ClosetHanger.where(user_id:).delete_all
    counts[:closet_lists] = ClosetList.where(user_id:).delete_all
    counts[:contributions] = Contribution.where(user_id:).delete_all
    counts[:neopets_connections] = NeopetsConnection.where(user_id:).delete_all
    counts[:login_cookies] = ApplicationRecord.connection.delete(
      ApplicationRecord.sanitize_sql(
        ["DELETE FROM login_cookies WHERE user_id = ?", user_id]))
    counts[:users] = User.where(id: user_id).delete_all

    counts
  end
end
