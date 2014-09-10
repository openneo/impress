(function() {
  $('span.choose-outfit select').change(function(e) {
    var select = $(this);
    select.closest('li').find('input[type=text]').val(select.val());
  });
})();
