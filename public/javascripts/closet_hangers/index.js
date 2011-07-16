(function () {
  var hangersEl = $('#closet-hangers.current-user');
  hangersEl.addClass('js');

  $.fn.hasChanged = function () {
    return this.data('previousValue') != this.val();
  }

  $.fn.revertValue = function () {
    this.each(function () {
      var el = $(this);
      el.val(el.data('previousValue'));
    });
  }

  $.fn.storeValue = function () {
    this.each(function () {
      var el = $(this);
      el.data('previousValue', el.val());
    });
  }

  function submitForm(form) {
    if(form.data('loading')) return false;
    var input = form.children("input[type=number]");
    if(input.hasChanged()) {
      var objectWrapper = form.closest(".object").addClass("loading");
      var span = objectWrapper.find("span").text(input.val());
      form.data('loading', true);

      $.ajax({
        url: form.attr("action") + ".json",
        type: "post",
        data: form.serialize(),
        dataType: "json",
        complete: function (data) {
          objectWrapper.removeClass("loading");
          form.data('loading', false);
        },
        success: function () {
          input.storeValue();
        },
        error: function (xhr) {
          var data = $.parseJSON(xhr.responseText);
          input.revertValue();
          span.text(input.val());
          if(typeof data.errors != 'undefined') {
            $.jGrowl("Error updating quantity: " + data.errors.join(", "));
          } else {
            $.jGrowl("We had trouble updating the quantity just now. Try again?");
          }
        }
      });
    }
  }

  hangersEl.find('form').submit(function (e) {
    e.preventDefault();
    submitForm($(this));
  });

  hangersEl.find('input[type=number]').change(function () {
    submitForm($(this).parent());
  }).storeValue();

  hangersEl.find('div.object').mouseleave(function () {
    submitForm($(this).find('form'));
  });
})();

