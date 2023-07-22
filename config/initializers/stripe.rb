# TODO: Upgrade Stripe to be usable again, or remove references altogether

Rails.configuration.stripe = {
  :publishable_key => "REMOVED:STRIPE_PUBLISHABLE_KEY",
  :secret_key      => "REMOVED:STRIPE_SECRET_KEY"
}

# Stripe.api_key = Rails.configuration.stripe[:secret_key]

# Some stub methods for our Stripe calls, to give clearer error messages (but
# those code paths shouldn't be accessible by normal users rn anyway).
module Stripe
  class Customer
    def self.create(*args)
      raise NotImplementedError, "TODO: Reinstall Stripe"
    end
  end

  class Card
    def self.create(*args)
      raise NotImplementedError, "TODO: Reinstall Stripe"
    end
  end

  class CardError < Exception
  end
end
