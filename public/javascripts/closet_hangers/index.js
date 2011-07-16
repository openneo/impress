(function () {
  var hangersEl = $('#closet-hangers.current-user');
  hangersEl.addClass('js');

  $.fn.disableForms = function () {
    return this.data("formsDisabled", true).find("input").attr("disabled", "disabled").end();
  }

  $.fn.enableForms = function () {
    return this.data("formsDisabled", false).find("input").removeAttr("disabled").end();
  }

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

  function submitUpdateForm(form) {
    if(form.data('loading')) return false;
    var input = form.children("input[type=number]");
    if(input.hasChanged()) {
      var objectWrapper = form.closest(".object").addClass("loading");
      var span = objectWrapper.find("span").text(input.val());
      var data = form.serialize(); // get data before disabling inputs
      objectWrapper.disableForms();
      form.data('loading', true);
      $.ajax({
        url: form.attr("action") + ".json",
        type: "post",
        data: data,
        dataType: "json",
        complete: function (data) {
          objectWrapper.removeClass("loading").enableForms();
          form.data('loading', false);
        },
        success: function () {
          input.storeValue();
        },
        error: function (xhr) {
          try {
            var data = $.parseJSON(xhr.responseText);
          } catch(e) {
            var data = {};
          }
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

  hangersEl.find('form.closet-hanger-update').submit(function (e) {
    e.preventDefault();
    submitUpdateForm($(this));
  });

  hangersEl.find('input[type=number]').change(function () {
    submitUpdateForm($(this).parent());
  }).storeValue();

  hangersEl.find('div.object').mouseleave(function () {
    submitUpdateForm($(this).find('form.closet-hanger-update'));
  });

  hangersEl.find("form.closet-hanger-destroy").submit(function (e) {
    e.preventDefault();
    var form = $(this);
    var button = form.children("input").val("Removing…");
    var objectWrapper = form.closest(".object").addClass("loading");
    var data = form.serialize(); // get data before disabling inputs
    objectWrapper.addClass("loading").disableForms();
    $.ajax({
      url: form.attr("action") + ".json",
      type: "post",
      data: data,
      dataType: "json",
      complete: function () {
        button.val("Remove");
      },
      success: function () {
        objectWrapper.hide(500);
      },
      error: function () {
        objectWrapper.removeClass("loading").enableForms();
        $.jGrowl("Error removing item. Try again?");
      }
    });
  });
})();

