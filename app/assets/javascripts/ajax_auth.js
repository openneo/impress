(function () {
  var csrf_param = $('meta[name=csrf-param]').attr('content'),
    csrf_token = $('meta[name=csrf-token]').attr('content'),
    data = {};

  data[csrf_param] = csrf_token;

  $.ajaxSetup({data: data});
})();
