(function() {
  var donationForm = document.getElementById('donation-form');
  var amountField = donationForm.querySelector(
    '[name=donation\\[amount\\]]');
  var tokenField = donationForm.querySelector(
    '[name=donation\\[stripe_token\\]]');

  var checkout = StripeCheckout.configure({
    key: donationForm.getAttribute('data-checkout-publishable-key'),
    image: donationForm.getAttribute('data-checkout-image'),
    token: function(token) {
      tokenField.value = token.id;
      donationForm.submit();
    }
  });

  donationForm.addEventListener('submit', function(e) {
    if (!tokenField.value) {
      e.preventDefault();

      var amount = Math.floor(parseFloat(amountField.value) * 100);

      if (!isNaN(amount)) {
        checkout.open({
          name: 'Dress to Impress',
          description: 'Donation (thank you!)',
          amount: amount
        });
      }
    }
  });
})();
