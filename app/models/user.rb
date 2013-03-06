class User < ActiveRecord::Base
  include PrettyParam

  DefaultAuthServerId = 1
  PreviewTopContributorsCount = 3

  has_many :closet_hangers
  has_many :closet_lists
  has_many :closeted_items, :through => :closet_hangers, :source => :item
  has_many :contributions
  has_many :outfits

  scope :top_contributors, order('points DESC').where('points > 0')

  devise :rememberable

  attr_accessible :neopets_username, :owned_closet_hangers_visibility,
    :wanted_closet_hangers_visibility

  def admin?
    name == 'matchu' # you know that's right.
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
    items_by_id = {}
    items.each do |item|
      items_by_id[item.id] ||= []
      items_by_id[item.id] << item
    end
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

  def self.find_or_create_from_remote_auth_data(user_data)
    user = find_or_initialize_by_remote_id_and_auth_server_id(
      user_data['id'],
      DefaultAuthServerId
    )
    if user.new_record?
      user.name = user_data['name']
      user.save
    end
    user
  end

  def self.points_required_to_pass_top_contributor(offset)
    user = User.top_contributors.select(:points).limit(1).offset(offset).first
    user ? user.points : 0
  end
end

