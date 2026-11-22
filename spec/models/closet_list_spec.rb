require_relative '../rails_helper'

RSpec.describe ClosetList do
  let(:user) { create_user('Alice') }

  describe 'name' do
    it 'accepts a name that fits in the column' do
      list = user.closet_lists.build(name: 'a' * 255, hangers_owned: true)
      expect(list).to be_valid
      expect { list.save! }.not_to raise_error
    end

    it 'rejects a name too long for the column, instead of erroring on save' do
      list = user.closet_lists.build(name: 'a' * 256, hangers_owned: true)
      expect(list).not_to be_valid
      expect(list.errors[:name]).to be_present
      expect(list.save).to be false
    end
  end

  def create_user(name)
    auth_user = AuthUser.create!(
      name: name,
      email: "#{name.downcase}@example.com",
      password: 'password123',
      password_confirmation: 'password123'
    )
    User.create!(name: name, remote_id: auth_user.id, auth_server_id: 1)
  end
end
