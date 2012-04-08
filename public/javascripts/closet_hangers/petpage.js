(function () {
  function setChecked() {
    var el = $(this);
    el.closest('li').toggleClass('checked', el.is(':checked'));
  }

  $('#petpage-closet-lists input').click(setChecked).each(setChecked);
})();
