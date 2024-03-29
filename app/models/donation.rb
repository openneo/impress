class Donation < ApplicationRecord
  FEATURE_COST = 500  # in cents = $5.00

  belongs_to :campaign
  belongs_to :user, optional: true
  has_many :features, class_name: 'DonationFeature'

  def to_param
    "#{id}-#{secret}"
  end

  def self.create_from_charge(campaign, user, params)
    amount = (BigDecimal.new(params[:amount]) * 100).floor

    campaign.progress += amount

    charge_params = {
      amount: amount,
      description: 'Donation (thank you!)',
      currency: 'usd'
    }

    if params[:stripe_token_type] == 'card'
      customer = Stripe::Customer.create(
        card: params[:stripe_token]
      )
      charge_params[:customer] = customer.id
    elsif params[:stripe_token_type] == 'bitcoin_receiver'
      charge_params[:card] = params[:stripe_token]
    else
      raise ArgumentError, "unexpected stripe token type #{params[:stripe_token_type]}"
    end

    charge = Stripe::Charge.create(charge_params)

    donation = campaign.donations.build
    donation.amount = amount
    donation.charge_id = charge.id
    donation.user = user
    donation.donor_name = user.try(:name)
    donation.donor_email = params[:donor_email]
    donation.secret = new_secret

    num_features = amount / FEATURE_COST
    features = []
    num_features.times do
      features << donation.features.new
    end

    Donation.transaction do
      campaign.save!
      donation.save!
      features.each(&:save!)
    end

    DonationMailer.thank_you_email(donation, donation.donor_email).deliver

    donation
  end

  def self.new_secret
    SecureRandom.urlsafe_base64 8
  end

  def self.from_param(param)
    id, secret = param.split('-', 2)
    self.where(secret: secret).find(id)
  end
end
