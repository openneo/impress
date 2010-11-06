class User < ActiveRecord::Base
  DefaultAuthServerId = 1
  
  has_many :contributions
  
  scope :top_contributors, order('points DESC').where(arel_table[:points].gt(0))
  
  def contribute!(contributables)
    new_contributions = []
    contributables.each do |contributable|
      if contributable.new_record?
        contribution = Contribution.new(:contributed => contributable,
          :user => self)
        new_contributions << contribution
        self.points += contribution.point_value
      end
    end
    self.contributions += new_contributions
    save!
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
end
