class PetType < ActiveRecord::Base
  def as_json(options={})
    {:id => id, :body_id => body_id}
  end
end
