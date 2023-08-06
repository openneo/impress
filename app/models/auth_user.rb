class AuthUser < AuthRecord
  self.table_name = 'users'

  devise :database_authenticatable, :encryptable
  # devise :database_authenticatable, :lockable, :registerable, :recoverable,
  #   :trackable, :validatable

  validates :name, presence: true, uniqueness: {case_sensitive: false},
    length: {maximum: 20}
end