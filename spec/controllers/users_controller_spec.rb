require_relative '../rails_helper'

RSpec.describe UsersController, type: :controller do
  include Devise::Test::ControllerHelpers

  describe 'GET #top_contributors' do
    let!(:user1) { create_user('Alice', 100) }
    let!(:user2) { create_user('Bob', 50) }
    let!(:user3) { create_user('Charlie', 0) }

    context 'without timeframe parameter' do
      it 'defaults to all_time timeframe' do
        get :top_contributors
        expect(assigns(:timeframe)).to eq('all_time')
      end

      it 'returns users ordered by points' do
        get :top_contributors
        users = assigns(:users)
        expect(users.to_a.map(&:id)).to eq([user1.id, user2.id])
      end

      it 'paginates results' do
        get :top_contributors, params: { page: 1 }
        users = assigns(:users)
        expect(users).to respond_to(:total_pages)
        expect(users).to respond_to(:current_page)
      end
    end

    context 'with valid timeframe parameter' do
      it 'accepts all_time' do
        get :top_contributors, params: { timeframe: 'all_time' }
        expect(assigns(:timeframe)).to eq('all_time')
      end

      it 'accepts this_year' do
        get :top_contributors, params: { timeframe: 'this_year' }
        expect(assigns(:timeframe)).to eq('this_year')
      end

      it 'accepts this_month' do
        get :top_contributors, params: { timeframe: 'this_month' }
        expect(assigns(:timeframe)).to eq('this_month')
      end

      it 'accepts this_week' do
        get :top_contributors, params: { timeframe: 'this_week' }
        expect(assigns(:timeframe)).to eq('this_week')
      end

      it 'calls User.top_contributors_for with the timeframe' do
        expect(User).to receive(:top_contributors_for).with(:this_week).and_call_original
        get :top_contributors, params: { timeframe: 'this_week' }
      end
    end

    context 'with invalid timeframe parameter' do
      it 'defaults to all_time' do
        get :top_contributors, params: { timeframe: 'invalid' }
        expect(assigns(:timeframe)).to eq('all_time')
      end

      it 'does not raise an error' do
        expect {
          get :top_contributors, params: { timeframe: 'invalid' }
        }.not_to raise_error
      end
    end

    context 'with pagination' do
      before do
        # Create 25 users to test pagination (per_page is 20)
        25.times do |i|
          create_user("User#{i}", 100 - i)
        end
      end

      it 'paginates with 20 users per page' do
        get :top_contributors
        expect(assigns(:users).size).to eq(20)
      end

      it 'supports page parameter' do
        get :top_contributors, params: { page: 2 }
        expect(assigns(:users).current_page).to eq(2)
      end

      it 'works with timeframe and pagination together' do
        get :top_contributors, params: { timeframe: 'all_time', page: 2 }
        expect(assigns(:timeframe)).to eq('all_time')
        expect(assigns(:users).current_page).to eq(2)
      end
    end

    context 'renders the correct template' do
      it 'renders the top_contributors template' do
        get :top_contributors
        expect(response).to render_template('top_contributors')
      end

      it 'returns HTTP success' do
        get :top_contributors
        expect(response).to have_http_status(:success)
      end
    end
  end

  # Helper methods
  def create_user(name, points = 0)
    auth_user = AuthUser.create!(
      name: name,
      email: "#{name.downcase}@example.com",
      password: 'password123',
      password_confirmation: 'password123'
    )
    User.create!(name: name, remote_id: auth_user.id, auth_server_id: 1, points: points)
  end
end
