(function () {
  var body = $(document.body).addClass("js");
  if(!body.hasClass("current-user")) return false;

  var hangersElQuery = '#closet-hangers';
  var hangersEl = $(hangersElQuery);

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
    return this.each(function () {
      var el = $(this);
      el.val(el.data('previousValue'));
    });
  }

  $.fn.storeValue = function () {
    return this.each(function () {
      var el = $(this);
      el.data('previousValue', el.val());
    });
  }

  function handleSaveError(xhr, action) {
    try {
      var data = $.parseJSON(xhr.responseText);
    } catch(e) {
      var data = {};
    }

    if(typeof data.errors != 'undefined') {
      $.jGrowl("Error " + action + ": " + data.errors.join(", "));
    } else {
      $.jGrowl("We had trouble " + action + " just now. Try again?");
    }
  }

  function objectRemoved(objectWrapper) {
    objectWrapper.hide(250);
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
          if(input.val() == 0) {
            objectRemoved(objectWrapper);
          } else {
            objectWrapper.removeClass("loading").enableForms();
          }
          form.data('loading', false);
        },
        success: function () {
          input.storeValue();
        },
        error: function (xhr) {
          input.revertValue();
          span.text(input.val());

          handleSaveError(xhr, "updating the quantity");
        }
      });
    }
  }

  $(hangersElQuery + ' form.closet-hanger-update').live('submit', function (e) {
    e.preventDefault();
    submitUpdateForm($(this));
  });

  function quantityInputs() { return $(hangersElQuery + ' input[type=number]') }

  quantityInputs().live('change', function () {
    submitUpdateForm($(this).parent());
  }).storeValue();

  $(hangersElQuery + ' div.object').live('mouseleave', function () {
    submitUpdateForm($(this).find('form.closet-hanger-update'));
  });

  $(hangersElQuery + " form.closet-hanger-destroy").live("submit", function (e) {
    e.preventDefault();
    var form = $(this);
    var button = form.children("input[type=submit]").val("Removing…");
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
        objectRemoved(objectWrapper);
      },
      error: function () {
        objectWrapper.removeClass("loading").enableForms();
        $.jGrowl("Error removing item. Try again?");
      }
    });
  });

  $('input, textarea').placeholder();

  var itemsSearchForm = $("#closet-hangers-items-search[data-current-user-id]");
  var itemsSearchField = itemsSearchForm.children("input[type=search]");

  itemsSearchField.autocomplete({
    select: function (e, ui) {
      var item = ui.item;
      itemsSearchField.addClass("loading");

      $.ajax({
        url: "/user/" + itemsSearchForm.data("current-user-id") + "/items/" + item.id + "/closet_hanger",
        type: "post",
        data: {closet_hanger: {quantity: 1}, return_to: window.location.pathname + window.location.search},
        complete: function () {
          itemsSearchField.removeClass("loading");
        },
        success: function (html) {
          var doc = $(html);
          hangersEl.html( doc.find('#closet-hangers').html() );
          quantityInputs().storeValue(); // since all the quantity inputs are new, gotta store initial value again
          doc.find('.flash').hide().insertBefore(hangersEl).show(500).delay(5000).hide(250);
          itemsSearchField.val("");
        },
        error: function (xhr) {
          handleSaveError(xhr, "adding the item");
        }
      });
    },
    source: function (input, callback) {
      $.getJSON("/items.json?q=" + input.term, function (data) {
        var output = [];
        var items = data.items;
        for(var i in items) {
          items[i].label = items[i].name;
          output[output.length] = items[i];
        }
        callback(output);
      })
    }
  }).data( "autocomplete" )._renderItem = function( ul, item ) {
		return $( "<li></li>" )
			.data( "item.autocomplete", item )
			.append( "<a>Add <strong>" + item.label + "</strong>" )
			.appendTo( ul );
	}

	var contactEl = $('#closet-hangers-contact');
	var editContactLink = $('#edit-contact-link');
	var contactForm = contactEl.children('form');
	var cancelContactLink = $('#cancel-contact-link');
	var contactFormUsername = contactForm.children('input[type=text]');
	var editContactLinkUsername = $('#contact-link-has-value span');

	function closeContactForm() {
	  contactEl.removeClass('editing');
	}

	editContactLink.click(function () {
	  contactEl.addClass('editing');
	  contactFormUsername.focus();
	});

	cancelContactLink.click(closeContactForm);

	contactForm.submit(function (e) {
	  var data = contactForm.serialize();
	  contactForm.disableForms();
	  $.ajax({
	    url: contactForm.attr('action') + '.json',
	    type: 'post',
	    data: data,
	    dataType: 'json',
	    complete: function () {
	      contactForm.enableForms();
	    },
	    success: function () {
	      var newName = contactFormUsername.val();
	      if(newName.length > 0) {
	        editContactLink.addClass('has-value');
	        editContactLinkUsername.text(newName);
	      } else {
	        editContactLink.removeClass('has-value');
	      }
	      closeContactForm();
      },
	    error: function (xhr) {
	      handleSaveError(xhr, 'saving Neopets username');
	    }
	  });
	  e.preventDefault();
	});


	$('div.closet-hangers-group header').click(function () {
	  $(this).parent().toggleClass('hidden');
	});
})();

