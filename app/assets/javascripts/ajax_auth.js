(function () {
  var CSRFProtection = function (xhr) {
    var token = $('meta[name="csrf-token"]').attr('content');
    if(token) xhr.setRequestHeader('X-CSRF-Token', token);
  };

  $.ajaxSetup({
    beforeSend: CSRFProtection
  });
})();
