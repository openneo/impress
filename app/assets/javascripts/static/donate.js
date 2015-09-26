(function() {
  var donationForm = document.getElementById('donation-form');

  function field(name) {
    return donationForm.querySelector(
      'input[name=donation\\[' + name + '\\]]');
  }

  var checkout = StripeCheckout.configure({
    key: donationForm.getAttribute('data-checkout-publishable-key'),
    image: donationForm.getAttribute('data-checkout-image'),
    token: function(token) {
      field('stripe_token').value = token.id;
      field('stripe_token_type').value = token.type;
      field('donor_email').value = token.email;
      donationForm.submit();
    },
    bitcoin: true
  });

  donationForm.addEventListener('submit', function(e) {
    if (!field('stripe_token').value) {
      e.preventDefault();

      var amount = Math.floor(parseFloat(field('amount').value) * 100);

      if (!isNaN(amount)) {
        checkout.open({
          name: 'Dress to Impress',
          description: 'Donation (thank you!)',
          amount: amount
        });
      }
    }
  });

  var toggle = document.getElementById('success-thanks-toggle-description');
  toggle.addEventListener('click', function() {
    var desc = document.getElementById('description');
    var attr = 'data-show';
    if (desc.hasAttribute(attr)) {
      desc.removeAttribute(attr);
    } else {
      desc.setAttribute(attr, true);
    }
  });
})();
