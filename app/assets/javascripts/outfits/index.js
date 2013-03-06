$('form.button_to input[type=submit]').click(function (e) {
  if(!confirm(this.getAttribute('data-confirm'))) e.preventDefault();
});

