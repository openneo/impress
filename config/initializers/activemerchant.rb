if defined? ActiveMerchant
  if Rails.env.development?
    ActiveMerchant::Billing::Base.mode = :test
    paypal_options = {
      :login => "dti00_1309660809_biz_api1.gmail.com",
      :password => "1309660841",
      :signature => "A8hoaApkuosyp0eSB5fO.FMMFsFPA2E9DtCZkbNkmIuVRqeOmTOzXqQQ"
    }
  elsif Rails.env.production?
    ActiveMerchant::Billing::Base.mode = :production
    paypal_options = {
      :login => "matchu1993_api1.gmail.com",
      :password => "JCJ2NK5DTBZ94QNP",
      :signature => "AFcWxV21C7fd0v3bYYYRCpSSRl31AFGfnit6OH.i894Lf4Bgc81N2lfc"
    }
  else
    raise RuntimeError, "ActiveMerchant is not configured for #{Rails.env}. See config/initializers/activemerchant.rb"
  end

  ::DONATION_GATEWAY = ActiveMerchant::Billing::PaypalExpressGateway.new(paypal_options)  
end
