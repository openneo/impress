(function () {
  var CSRFProtection;
  var token = $('meta[name="csrf-token"]').attr('content');
  if (token) {
    CSRFProtection = function(xhr, settings) {
      var sendToken = (
        (typeof settings.useCSRFProtection === 'undefined') // default to true
        || settings.useCSRFProtection);
      if (sendToken) {
        xhr.setRequestHeader('X-CSRF-Token', token);
      }
    }
  } else {
    CSRFProtection = $.noop;
  }

  $.ajaxSetup({
    beforeSend: CSRFProtection
  });
})();
