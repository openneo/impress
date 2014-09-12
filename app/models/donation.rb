class Donation < ActiveRecord::Base
  FEATURE_COST = 500  # in cents = $5.00

  attr_accessible :donor_name

  belongs_to :campaign
  belongs_to :user
  has_many :features, class_name: 'DonationFeature'

  def to_param
    "#{id}-#{secret}"
  end

  def self.create_from_charge(campaign, user, params)
    amount = (BigDecimal.new(params[:amount]) * 100).floor

    campaign.progress += amount

    customer = Stripe::Customer.create(
      card: params[:stripe_token]
    )

    charge = Stripe::Charge.create(
      :customer    => customer.id,
      :amount      => amount,
      :description => 'Donation (thank you!)',
      :currency    => 'usd'
    )

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
