(function () {
  var hangersInitCallbacks = [];

  function onHangersInit(callback) {
    hangersInitCallbacks[hangersInitCallbacks.length] = callback;
  }

  function hangersInit() {
    for(var i = 0; i < hangersInitCallbacks.length; i++) {
      hangersInitCallbacks[i]();
    }
  }

  /*

    Hanger groups

  */

  var hangerGroups = [];

	$('div.closet-hangers-group').each(function () {
	  var el = $(this);
	  var lists = [];

	  el.find('div.closet-list').each(function () {
	    var el = $(this);
	    var id = el.attr('data-id');
	    if(id) {
	      lists[lists.length] = {
	        id: parseInt(id, 10),
	        label: el.find('h4').text()
	      }
	    }
	  });

	  hangerGroups[hangerGroups.length] = {
	    label: el.find('h3').text(),
	    lists: lists,
	    owned: (el.attr('data-owned') == 'true')
	  };
	});

	$('div.closet-hangers-group span.toggle').live('click', function () {
	  $(this).closest('.closet-hangers-group').toggleClass('hidden');
	});

  /*

    Hanger forms

  */

  $.fn.liveDraggable = function (opts) {
    this.live("mouseover", function() {
      if (!$(this).data("init")) {
        $(this).data("init", true).draggable(opts);
      }
    });
  };

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
    return this.attr('data-previous-value') != this.val();
  }

  $.fn.revertValue = function () {
    return this.each(function () {
      var el = $(this);
      el.val(el.attr('data-previous-value'));
    });
  }

  $.fn.storeValue = function () {
    return this.each(function () {
      var el = $(this);
      el.attr('data-previous-value', el.val());
    });
  }

  $.fn.insertIntoSortedList = function (list, compare) {
    var newChild = this, inserted = false;
    list.children().each(function () {
      if(compare(newChild, $(this)) < 1) {
        newChild.insertBefore(this);
        inserted = true;
        return false;
      }
    });
    if(!inserted) newChild.appendTo(list);
    return this;
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

  function compareItemsByName(a, b) {
    return a.find('span.name').text().localeCompare(b.find('span.name').text());
  }

  function findList(id, item) {
    if(id) {
      return $('#closet-list-' + id);
    } else {
      return item.closest('.closet-hangers-group').find('div.closet-list.unlisted');
    }
  }

  function updateListHangersCount(el) {
    el.attr('data-hangers-count', el.find('div.object').length);
  }

  function moveItemToList(item, listId) {
    var newList = findList(listId, item);
    var oldList = item.closest('div.closet-list');
    var hangersWrapper = newList.find('div.closet-list-hangers');
    item.insertIntoSortedList(hangersWrapper, compareItemsByName);
    updateListHangersCount(oldList);
    updateListHangersCount(newList);
  }

  function submitUpdateForm(form) {
    if(form.data('loading')) return false;
    var quantityEl = form.children("input[name=closet_hanger\[quantity\]]");
    var listEl = form.children("input[name=closet_hanger\[list_id\]]");
    var listChanged = listEl.hasChanged();
    if(listChanged || quantityEl.hasChanged()) {
      var objectWrapper = form.closest(".object").addClass("loading");
      var newQuantity = quantityEl.val();
      var quantitySpan = objectWrapper.find(".quantity span").text(newQuantity);
      quantitySpan.parent().attr('class', 'quantity quantity-' + newQuantity);
      var data = form.serialize(); // get data before disabling inputs
      objectWrapper.disableForms();
      form.data('loading', true);
      if(listChanged) moveItemToList(objectWrapper, listEl.val());
      $.ajax({
        url: form.attr("action") + ".json",
        type: "post",
        data: data,
        dataType: "json",
        complete: function (data) {
          if(quantityEl.val() == 0) {
            objectRemoved(objectWrapper);
          } else {
            objectWrapper.removeClass("loading").enableForms();
          }
          form.data('loading', false);
        },
        success: function () {
          quantityEl.storeValue();
          listEl.storeValue();
        },
        error: function (xhr) {
          quantityEl.revertValue();
          listEl.revertValue();
          if(listChanged) moveItemToList(objectWrapper, listEl.val());
          quantitySpan.text(quantityEl.val());

          handleSaveError(xhr, "updating the quantity");
        }
      });
    }
  }

  $(hangersElQuery + ' form.closet-hanger-update').live('submit', function (e) {
    e.preventDefault();
    submitUpdateForm($(this));
  });

  function editableInputs() { return $(hangersElQuery).find('input[name=closet_hanger\[quantity\]], input[name=closet_hanger\[list_id\]]') }

  $(hangersElQuery + 'input[name=closet_hanger\[quantity\]]').live('change', function () {
    submitUpdateForm($(this).parent());
  }).storeValue();

  onHangersInit(function () {
    editableInputs().storeValue();
  });

  $(hangersElQuery + ' div.object').live('mouseleave', function () {
    submitUpdateForm($(this).find('form.closet-hanger-update'));
  }).liveDraggable({
    appendTo: '#closet-hangers',
    distance: 20,
    helper: "clone",
    revert: "invalid"
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

  /*

    Search, autocomplete

  */

  $('input, textarea').placeholder();

  var itemsSearchForm = $("#closet-hangers-items-search[data-current-user-id]");
  var itemsSearchField = itemsSearchForm.children("input[name=q]");

  itemsSearchField.autocomplete({
    select: function (e, ui) {
      if(ui.item.is_item) {
        // Let the autocompleter finish up this search before starting a new one
        setTimeout(function () { itemsSearchField.autocomplete("search", ui.item) }, 0);
      } else {
        var item = ui.item.item;
        var group = ui.item.group;

        itemsSearchField.addClass("loading");

        var closetHanger = {
          owned: group.owned,
          list_id: ui.item.list ? ui.item.list.id : ''
        };

        if(!item.hangerInGroup) closetHanger.quantity = 1;

        $.ajax({
          url: "/user/" + itemsSearchForm.data("current-user-id") + "/items/" + item.id + "/closet_hanger",
          type: "post",
          data: {closet_hanger: closetHanger, return_to: window.location.pathname + window.location.search},
          complete: function () {
            itemsSearchField.removeClass("loading");
          },
          success: function (html) {
            var doc = $(html);
            hangersEl.html( doc.find('#closet-hangers').html() );
            hangersInit();
            doc.find('.flash').hide().insertBefore(hangersEl).show(500).delay(5000).hide(250);
            itemsSearchField.val("");
          },
          error: function (xhr) {
            handleSaveError(xhr, "adding the item");
          }
        });
      }
    },
    source: function (input, callback) {
      if(typeof input.term == 'string') { // user-typed query
        $.getJSON("/items.json?q=" + input.term, function (data) {
          var output = [];
          var items = data.items;
          for(var i in items) {
            items[i].label = items[i].name;
            items[i].is_item = true;
            output[output.length] = items[i];
          }
          callback(output);
        });
      } else { // item was chosen, now choose a group to insert
        var groupInserts = [], group;
        var item = input.term, itemEl, hangerInGroup, currentListId;
        for(var i in hangerGroups) {
          group = hangerGroups[i];
          itemEl = $('div.closet-hangers-group[data-owned=' + group.owned + '] div.object[data-item-id=' + item.id + ']');
          hangerInGroup = itemEl.length > 0;
          currentListId = itemEl.closest('.closet-list').attr('data-id');

          groupInserts[groupInserts.length] = {
            group: group,
            item: item,
            label: item.label,
            hangerInGroup: hangerInGroup,
            hangerInList: !!currentListId
          }

          for(var i = 0; i < group.lists.length; i++) {
            groupInserts[groupInserts.length] = {
              group: group,
              item: item,
              label: item.label,
              list: group.lists[i],
              hangerInGroup: hangerInGroup,
              currentListId: currentListId
            }
          }
        }
        callback(groupInserts);
      }
    }
  });

  var autocompleter = itemsSearchField.data("autocomplete");

  autocompleter._renderItem = function( ul, item ) {
    var li = $("<li></li>").data("item.autocomplete", item);
    if(item.is_item) { // these are items from the server
      li.append("<a>Add <strong>" + item.label + "</strong>");
    } else if(item.list) { // these are list inserts
      if(item.hangerInGroup) {
        if(item.currentListId == item.list.id) {
          li.append("<span>It's in <strong>" + item.list.label + "</strong> now");
        } else {
          li.append("<a>Move to <strong>" + item.list.label + "</strong>");
        }
      } else {
        li.append("<a>Add to <strong>" + item.list.label + "</strong>");
      }
      li.addClass("closet-list-autocomplete-item");
    } else { // these are group inserts
      if(item.hangerInGroup) {
        var groupName = item.group.label;
        if(item.hangerInList) {
          li.append("<a>Move to <strong>" + groupName.replace(/\s+$/, '') + "</strong>, no list");
        } else {
          li.append("<span>It's in <strong>" + groupName + "</strong> now");
        }
      } else {
  		  li.append("<a>Add to <strong>" + item.group.label + "</strong>");
		  }
		  li.addClass('closet-hangers-group-autocomplete-item');
		}
		return li.appendTo(ul);
	}

	/*

	  Contact Neopets username form

	*/

	var contactEl = $('#closet-hangers-contact');
	var editContactLink = $('.edit-contact-link');
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

	/*

	  Hanger list controls

	*/

	$('input[type=submit][data-confirm]').live('click', function (e) {
    if(!confirm(this.getAttribute('data-confirm'))) e.preventDefault();
  });

  /*
    Closet list droppable
  */

  onHangersInit(function () {
    $('.closet-hangers-group').each(function () {
      var group = $(this);
      group.find('div.closet-list').droppable({
        accept: '#' + group.attr('id') + ' div.object',
        activate: function () {
          $(this).find('.closet-list-content').animate({opacity: 0, height: 100}, 250);
        },
        activeClass: 'droppable-active',
        deactivate: function () {
          $(this).find('.closet-list-content').css('height', 'auto').animate({opacity: 1}, 250);
        },
        drop: function (e, ui) {
          var form = ui.draggable.find('form.closet-hanger-update');
          form.find('input[name=closet_hanger\[list_id\]]').val(this.getAttribute('data-id'));
          submitUpdateForm(form);
        }
      });
    });
  });

  /*
    Initialize
  */

  hangersInit();
})();

