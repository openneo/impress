class User < ActiveRecord::Base
  DefaultAuthServerId = 1
  PreviewTopContributorsCount = 3

  has_many :closet_hangers
  has_many :closeted_items, :through => :closet_hangers, :source => :item
  has_many :contributions
  has_many :outfits

  scope :top_contributors, order('points DESC').where(arel_table[:points].gt(0))

  devise :rememberable

  def contribute!(pet)
    new_contributions = []
    new_points = 0
    pet.contributables.each do |contributable|
      if contributable.new_record?
        contribution = Contribution.new(:contributed => contributable,
          :user => self)
        new_contributions << contribution
        new_points += contribution.point_value
      end
    end
    self.points += new_points
    Pet.transaction do
      pet.save!
      new_contributions.each do |contribution|
        begin
          contribution.save!
        rescue ActiveRecord::RecordNotSaved => e
          raise ActiveRecord::RecordNotSaved, "#{e.message}, #{contribution.inspect}, #{contribution.valid?.inspect}, #{contribution.errors.inspect}"
        end
      end
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
    items.each { |item| items_by_id[item.id] = item }
    closeted_item_ids = closeted_items.where(:id => items_by_id.keys).map(&:id)
    closeted_item_ids.each { |id| items_by_id[id].closeted = true }
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

