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

      var amountChoice =
        donationForm.querySelector('input[name=amount]:checked');
      if (amountChoice.value === "custom") {
        amountChoice = document.getElementById('amount-custom-value');
      }

      // Start parsing at the first digit in the string, to trim leading dollar
      // signs and what have you.
      var amountNumberString = (amountChoice.value.match(/[0-9].+/) || [""])[0];
      var amount = Math.floor(parseFloat(amountNumberString) * 100);

      if (!isNaN(amount)) {
        field('amount').value = amountNumberString;
        checkout.open({
          name: 'Dress to Impress',
          description: 'Donation (thank you!)',
          amount: amount,
          panelLabel: "Donate"
        });
      }
    }
  });

  var toggle = document.getElementById('success-thanks-toggle-description');
  if (toggle) {
    toggle.addEventListener('click', function() {
      var desc = document.getElementById('description');
      var attr = 'data-show';
      if (desc.hasAttribute(attr)) {
        desc.removeAttribute(attr);
      } else {
        desc.setAttribute(attr, true);
      }
    });
  }

  document.getElementById('amount-custom').addEventListener('change', function(e) {
    if (e.target.checked) {
      document.getElementById('amount-custom-value').focus();
    }
  });
})();
