# Permanently deletes a user's account and all of their personal data.
#
# This is the one code path for account deletion: the self-serve button on the
# Settings page uses it, and so does `rake users:delete` for support requests.
# If you add a new table that stores user data, add it here, and also to
# `AuthUser::DataExport`! (spec/models/auth_user/user_data_coverage_spec.rb
# lists every user-data column we know about, and fails on new ones.)
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

    # Lock the user's outfits (`SELECT ... FOR UPDATE`), so an outfit they save
    # partway through can't slip past us: InnoDB also locks the gap in the
    # `user_id` index, which blocks new outfits for this user until we commit.
    #
    # NOTE: We use a list of IDs, rather than an `IN (SELECT ...)` subquery!
    #       MariaDB (before 11.1) can't optimize a subquery in a single-table
    #       UPDATE or DELETE, so it scans the *entire* table instead, locking
    #       every row as it goes. For `item_outfit_relationships`, that took
    #       minutes in production, and blocked other people's outfit saves.
    outfit_ids = Outfit.where(user_id:).lock.pluck(:id)

    counts = {}

    # Detach records we keep from the data we're about to delete.
    counts[:donations_detached] = Fundraising::Donation.where(user_id:).
      update_all(user_id: nil, donor_name: nil, donor_email: nil)
    counts[:donation_features_detached] = in_batches_of_ids(outfit_ids) do |ids|
      Fundraising::DonationFeature.where(outfit_id: ids).
        update_all(outfit_id: nil)
    end
    counts[:neologin_cookies_detached] = NeologinCookie.
      where(created_by_id: user_id).update_all(created_by_id: nil)

    # Delete the user's own data. We use `delete_all` rather than `destroy` to
    # keep this fast for users with many thousands of items, so we handle the
    # dependent records ourselves.
    counts[:item_outfit_relationships] = in_batches_of_ids(outfit_ids) do |ids|
      ItemOutfitRelationship.where(outfit_id: ids).delete_all
    end
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

  # Runs the block on slices of the given IDs, so a user with many thousands
  # of outfits doesn't produce one enormous `IN (...)` list. Returns the sum of
  # the block's results (affected row counts).
  def in_batches_of_ids(ids, batch_size: 1000)
    ids.each_slice(batch_size).sum { |batch| yield batch }
  end
end
