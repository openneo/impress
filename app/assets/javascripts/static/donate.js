(function() {
  var donationForm = document.getElementById('donation-form');
  var amountField = donationForm.amount;
  var tokenField = donationForm.stripe_token;

  var checkout = StripeCheckout.configure({
    key: 'pk_test_wEvgn4baD9W5ld5C9JCS9Ahf', // TODO
    //image: '/square-image.png', // TODO
    token: function(token) {
      stripe_token.value = token.id;
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
