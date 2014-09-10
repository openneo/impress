class Donation < ActiveRecord::Base
  belongs_to :user

  def self.create_from_charge(user, params)
    amount = (BigDecimal.new(params[:amount]) * 100).floor

    customer = Stripe::Customer.create(
      card: params[:stripe_token]
    )

    charge = Stripe::Charge.create(
      :customer    => customer.id,
      :amount      => amount,
      :description => 'Donation (thank you!)',
      :currency    => 'usd'
    )

    donation = Donation.new
    donation.amount = amount
    donation.charge_id = charge.id
    donation.user_id = user.try(:id)
    donation.save!

    donation
  end
end
