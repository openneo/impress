require_relative '../rails_helper'

RSpec.describe AuthUser do
  describe '.build_unique_username' do
    # Devise downcases names when saving them (`case_insensitive_keys`), so
    # names are stored lowercase, even when the preferred name isn't.
    def create_auth_user(name)
      AuthUser.create!(
        name: name,
        email: "#{SecureRandom.hex(4)}@example.com",
        password: 'password123',
        password_confirmation: 'password123'
      )
    end

    it 'uses the preferred name when it is free' do
      expect(AuthUser.build_unique_username('Kougra')).to eq 'Kougra'
    end

    it 'adds a number when the preferred name is taken' do
      create_auth_user('kougra')
      expect(AuthUser.build_unique_username('kougra')).to match(/\Akougra-\d+\z/)
    end

    it 'treats a preferred name with capitals as taken by its lowercase twin' do
      create_auth_user('Kougra')

      name = AuthUser.build_unique_username('Kougra')

      expect(name).to match(/\AKougra-\d+\z/)
      expect(create_auth_user(name)).to be_persisted
    end

    it 'skips numbered names taken with different capitalization' do
      create_auth_user('Kougra')
      create_auth_user('Kougra-0')
      allow_any_instance_of(Array).to receive(:shuffle) { |names| names }

      expect(AuthUser.build_unique_username('Kougra')).to eq 'Kougra-1'
    end
  end
end
