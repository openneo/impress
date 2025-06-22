class NeopetsConnection < ApplicationRecord
  belongs_to :user

  validates :neopets_username, uniqueness: {scope: :user_id},
    format: { without: /@/, message: 'must not be an email address, for user safety' }
end
