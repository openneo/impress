class AuthRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: {reading: :openneo_id, writing: :openneo_id}
end