class NeopetsConnection < ApplicationRecord
  belongs_to :user

  validates :neopets_username, uniqueness: {scope: :user_id}
end
