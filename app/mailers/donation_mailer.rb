class DonationMailer < ActionMailer::Base
  default from: "matchu@openneo.net"

  def thank_you_email(donation, recipient)
    @donation = donation
    mail(to: recipient, subject: 'Thanks for donating to Dress to Impress!')
  end
end
