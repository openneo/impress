class User < ApplicationRecord
  include PrettyParam

  PreviewTopContributorsCount = 3

  has_many :closet_hangers
  has_many :closet_lists
  has_many :closeted_items, through: :closet_hangers, source: :item
  has_many :contributions
  has_many :neopets_connections
  has_many :outfits

  # TODO: When `owned_items` and `wanted_items` are merged, they override one
  # another instead of correctly returning an empty set. Is this a Rails bug
  # that gets fixed down the line once we finish upgrading, or...?
  has_many :owned_items, -> { where(ClosetHanger.arel_table[:owned].eq(true)) },
    through: :closet_hangers, source: :item
  has_many :wanted_items, -> { where(ClosetHanger.arel_table[:owned].eq(false)) },
    through: :closet_hangers, source: :item

  belongs_to :contact_neopets_connection, class_name: 'NeopetsConnection', optional: true

  scope :top_contributors, -> { order('points DESC').where('points > 0') }

  def admin?
    name == 'matchu' # you know that's right.
  end

  def unowned_items
    # Join all items against our owned closet hangers, group by item ID, then
    # only return those with zero matching hangers.
    #
    # TODO: It'd be nice to replace this with a `left_outer_joins` call in
    # Rails 5+, but these conditions really do need to be part of the join:
    # if we do them as a `where`, they prevent unmatching items from being
    # returned in the first place.
    #
    # TODO: This crashes the query when combined with `unwanted_items`.
    ch = ClosetHanger.arel_table.alias("owned_hangers")
    Item.
      joins(
        "LEFT JOIN closet_hangers owned_hangers ON owned_hangers.item_id = items.id " + 
        "AND #{ch[:user_id].eq(self.id).to_sql} AND owned_hangers.owned = true"
      ).
      group("items.id").having("COUNT(owned_hangers.id) = 0")
  end

  def unwanted_items
    # See `unowned_items` above! We just change the `true` to `false`.
    # TODO: This crashes the query when combined with `unowned_items`.
    ch = ClosetHanger.arel_table.alias("wanted_hangers")
    Item.
      joins(
        "LEFT JOIN closet_hangers wanted_hangers ON wanted_hangers.item_id = items.id " + 
        "AND #{ch[:user_id].eq(self.id).to_sql} AND wanted_hangers.owned = false"
      ).
      group("items.id").having("COUNT(wanted_hangers.id) = 0")
  end

  def contribute!(pet)
    new_contributions = []
    pet.contributables.each do |contributable|
      if contributable.new_record?
        contribution = Contribution.new
        contribution.contributed = contributable
        contribution.user = self
        new_contributions << contribution
      end
    end
    new_points = 0 # temp assignment for scoping
    Pet.transaction do
      pet.save!
      new_contributions.each do |contribution|
        Rails.logger.debug("Saving contribution of #{contribution.contributed.inspect}: #{contribution.contributed_type.inspect}, #{contribution.contributed_id.inspect}")
        begin
          contribution.save!
        rescue ActiveRecord::RecordNotSaved => e
          raise ActiveRecord::RecordNotSaved, "#{e.message}, #{contribution.inspect}, #{contribution.valid?.inspect}, #{contribution.errors.inspect}"
        end
      end
      new_points = new_contributions.map(&:point_value).inject(0, &:+)
      self.points += new_points
      begin
        save!
      rescue ActiveRecord::RecordNotSaved => e
        raise ActiveRecord::RecordNotSaved, "#{e.message}, #{self.inspect}, #{self.valid?.inspect}, #{self.errors.inspect}"
      end
    end
    new_points
  end

  def assign_closeted_to_items!(items)
    # Assigning these items to a hash by ID means that we don't have to go
    # N^2 searching the items list for items that match the given IDs or vice
    # versa, and everything stays a lovely O(n)
    items_by_id = items.group_by(&:id)
    closet_hangers.where(:item_id => items_by_id.keys).each do |hanger|
      items = items_by_id[hanger.item_id]
      items.each do |item|
        if hanger.owned?
          item.owned = true
        else
          item.wanted = true
        end
      end
    end
  end

  def closet_hangers_groups_visible_to(user)
    if user == self
      [true, false]
    else
      public_closet_hangers_groups
    end
  end
  
  def public_closet_hangers_groups
    [].tap do |groups|
      groups << true if owned_closet_hangers_visibility >= ClosetVisibility[:public].id
      groups << false if wanted_closet_hangers_visibility >= ClosetVisibility[:public].id
    end
  end

  def null_closet_list(owned)
    owned ? null_owned_list : null_wanted_list
  end

  def null_owned_list
    ClosetList::NullOwned.new(self)
  end

  def null_wanted_list
    ClosetList::NullWanted.new(self)
  end

  def find_closet_list_by_id_or_null_owned(id_or_owned)
    id_or_owned_str = id_or_owned.to_s
    if id_or_owned_str == 'true'
      null_owned_list
    elsif id_or_owned_str == 'false'
      null_wanted_list
    else
      self.closet_lists.find id_or_owned
    end
  end

  def neopets_usernames
    neopets_connections.map(&:neopets_username)
  end

  def contact_neopets_username?
    contact_neopets_connection.present?
  end

  def contact_neopets_username
    contact_neopets_connection.try(:neopets_username)
  end

  def self.points_required_to_pass_top_contributor(offset)
    user = User.top_contributors.select(:points).limit(1).offset(offset).first
    user ? user.points : 0
  end
end

