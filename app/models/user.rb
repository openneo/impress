class User < ActiveRecord::Base
  DefaultAuthServerId = 1
  PreviewTopContributorsCount = 3
  
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
      self.contributions += new_contributions
      save!
    end
    new_points
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
