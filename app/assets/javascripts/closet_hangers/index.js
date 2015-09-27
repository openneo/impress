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

  var hangersElQuery = '#closet-hangers';
  var hangersEl = $(hangersElQuery);

  /*

    Compare with Your Items

  */

  $('#toggle-compare').click(function () {
    hangersEl.toggleClass('comparing');
  });

  /*

    Hanger forms

  */

  var body = $(document.body).addClass("js");
  if(!body.hasClass("current-user")) return false;

  // When we get hangers HTML, add the controls. We do this in JS rather than
  // in the HTML for caching, since otherwise the requests can take forever.
  // If there were another way to add hangers, then we'd have to worry about
  // that, but, right now, the only way to create a new hanger from this page
  // is through the autocompleter, which reinitializes anyway. Geez, this thing
  // is begging for a rewrite, but today we're here for performance.
  $("#closet-hanger-update-tmpl").template("updateFormTmpl");
  $("#closet-hanger-destroy-tmpl").template("destroyFormTmpl");
  onHangersInit(function () {
    // Super-lame hack to get the user ID from where it already is :/
    var currentUserId = itemsSearchForm.data("current-user-id");
    $("#closet-hangers div.closet-hangers-group").each(function () {
      var groupEl = $(this);
      var owned = groupEl.data("owned");
      
      groupEl.find("div.closet-list").each(function () {
        var listEl = $(this);
        var listId = listEl.data("id");
        
        listEl.find("div.object").each(function () {
          var hangerEl = $(this);
          var hangerId = hangerEl.data("id");
          var quantityEl = hangerEl.find("div.quantity");
          var quantity = hangerEl.data("quantity");

          // Ooh, this part is weird. We only want the name to be linked, so
          // lift everything else out.
          var checkboxId = 'hanger-selected-' + hangerId;
          var label = $('<label />', {'for': checkboxId});
          var link = hangerEl.children('a');
          link.children(':not(.name)').detach().appendTo(label);
          link.detach().appendTo(label);
          var checkbox = $('<input />', {
            type: 'checkbox',
            id: checkboxId
          }).appendTo(hangerEl);
          label.appendTo(hangerEl);

          // I don't usually like to _blank things, but it's too easy to click
          // the text when you didn't mean to and lose your selection work.
          link.attr('target', '_blank');

          $.tmpl("updateFormTmpl", {
            user_id: currentUserId,
            closet_hanger_id: hangerId,
            quantity: quantity,
            list_id: listId,
            owned: owned
          }).appendTo(quantityEl);
          
          $.tmpl("destroyFormTmpl", {
            user_id: currentUserId,
            closet_hanger_id: hangerId
          }).appendTo(hangerEl);
        });
      });
    });
  });

  $.fn.liveDraggable = function (opts) {
    this.live("mouseover", function() {
      if (!$(this).data("init")) {
        $(this).data("init", true).draggable(opts);
      }
    });
  };

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
    objectWrapper.hide(250, function() {
      objectWrapper.remove();
      updateBulkActions();
    });
  }

  function compareItemsByName(a, b) {
    return a.find('span.name').text().localeCompare(b.find('span.name').text());
  }

  function findList(owned, id, item) {
    if(id) {
      return $('#closet-list-' + id);
    } else {
      return $("div.closet-hangers-group[data-owned=" + owned + "] div.closet-list.unlisted");
    }
  }

  function updateListHangersCount(el) {
    el.attr('data-hangers-count', el.find('div.object').length);
  }

  function moveItemToList(item, owned, listId) {
    var newList = findList(owned, listId, item);
    var oldList = item.closest('div.closet-list');
    var hangersWrapper = newList.find('div.closet-list-hangers');
    item.insertIntoSortedList(hangersWrapper, compareItemsByName);
    updateListHangersCount(oldList);
    updateListHangersCount(newList);
  }

  function submitUpdateForm(form) {
    if(form.data('loading')) return false;
    var quantityEl = form.children("input[name=closet_hanger\[quantity\]]");
    var ownedEl = form.children("input[name=closet_hanger\[owned\]]");
    var listEl = form.children("input[name=closet_hanger\[list_id\]]");
    var listChanged = ownedEl.hasChanged() || listEl.hasChanged();
    if(listChanged || quantityEl.hasChanged()) {
      var objectWrapper = form.closest(".object").addClass("loading");
      var newQuantity = quantityEl.val();
      var quantitySpan = objectWrapper.find(".quantity span").text(newQuantity);
      objectWrapper.attr('data-quantity', newQuantity);
      var data = form.serialize(); // get data before disabling inputs
      objectWrapper.disableForms();
      form.data('loading', true);
      if(listChanged) moveItemToList(objectWrapper, ownedEl.val(), listEl.val());
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
          // Now that the move was successful, let's merge it with any
          // conflicting hangers
          var id = objectWrapper.attr("data-item-id");
          var conflictingHanger = findList(ownedEl.val(), listEl.val(), objectWrapper).
            find("div[data-item-id=" +  id + "]").not(objectWrapper);
          if(conflictingHanger.length) {
            var conflictingQuantity = parseInt(
              conflictingHanger.attr('data-quantity'),
              10
            );
            
            var currentQuantity = parseInt(newQuantity, 10);
            
            var mergedQuantity = conflictingQuantity + currentQuantity;
            
            quantitySpan.text(mergedQuantity);
            quantityEl.val(mergedQuantity);
            objectWrapper.attr('data-quantity', mergedQuantity);
            
            conflictingHanger.remove();
          }
          
          quantityEl.storeValue();
          ownedEl.storeValue();
          listEl.storeValue();

          updateBulkActions();
        },
        error: function (xhr) {
          quantityEl.revertValue();
          ownedEl.revertValue();
          listEl.revertValue();
          if(listChanged) moveItemToList(objectWrapper, ownedEl.val(), listEl.val());
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

  function editableInputs() {
    return $(hangersElQuery).find(
      'input[name=closet_hanger\[quantity\]], ' + 
      'input[name=closet_hanger\[owned\]], ' +
      'input[name=closet_hanger\[list_id\]]'
    )
  }

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

  $(hangersElQuery + " .select-all").live("click", function(e) {
    var checkboxes = $(this).closest(".closet-list").find(".object input[type=checkbox]");

    var allChecked = true;
    checkboxes.each(function() {
      if (!this.checked) {
        allChecked = false;
        return false;
      }
    });

    checkboxes.attr('checked', !allChecked);

    updateBulkActions();  // setting the checked prop doesn't fire change events
  });

  function getCheckboxes() {
    return $(hangersElQuery + " input[type=checkbox]");
  }

  function getCheckedIds() {
    var checkedIds = [];
    getCheckboxes().filter(':checked').each(function() {
      if (this.checked) checkedIds.push(this.id);
    });
    return checkedIds;
  }

  getCheckboxes().live("change", updateBulkActions);

  function updateBulkActions() {
    var checkedCount = getCheckboxes().filter(':checked').length;
    $('.bulk-actions').attr('data-target-count', checkedCount);
    $('.bulk-actions-target-count').text(checkedCount);
  }

  $(".bulk-actions-move-all").bind("submit", function(e) {
    // TODO: DRY
    e.preventDefault();
    var form = $(this);
    var data = form.serializeArray();
    data.push({name: "return_to", value: window.location.pathname + window.location.search});

    var checkedBoxes = getCheckboxes().filter(':checked');
    checkedBoxes.each(function() {
      data.push({name: "ids[]", value: $(this).closest('.object').attr('data-id')});
    });

    $.ajax({
      url: form.attr("action"),
      type: form.attr("method"),
      data: data,
      success: function (html) {
        var doc = $(html);
        maintainCheckboxes(function() {
          hangersEl.html( doc.find('#closet-hangers').html() );
          hangersInit();
        });
        doc.find('.flash').hide().insertBefore(hangersEl).show(500).delay(5000).hide(250);
        itemsSearchField.val("");
      },
      error: function (xhr) {
        handleSaveError(xhr, "moving these items");
      }
    });
  });

  $(".bulk-actions-remove-all").bind("submit", function(e) {
    e.preventDefault();
    var form = $(this);
    var hangerIds = [];
    var checkedBoxes = getCheckboxes().filter(':checked');
    var hangerEls = $();
    checkedBoxes.each(function() {
      hangerEls = hangerEls.add($(this).closest('.object'));
    });
    hangerEls.each(function() {
      hangerIds.push($(this).attr('data-id'));
    });
    $.ajax({
      url: form.attr("action") + ".json?" + $.param({ids: hangerIds}),
      type: "delete",
      dataType: "json",
      success: function () {
        objectRemoved(hangerEls);
      },
      error: function () {
        $.jGrowl("Error removing items. Try again?");
      }
    });
  });

  function maintainCheckboxes(fn) {
    var checkedIds = getCheckedIds();

    fn();

    checkedIds.forEach(function(id) {
      document.getElementById(id).checked = true;
    });
    updateBulkActions();
  }

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
        setTimeout(function () {
          itemsSearchField.autocomplete("search", ui.item);
        }, 0);
      } else {
        var item = ui.item.item;
        var group = ui.item.group;

        itemsSearchField.addClass("loading");

        var closetHanger = {
          owned: group.owned,
          list_id: ui.item.list ? ui.item.list.id : ''
        };

        if(!item.hasHanger) closetHanger.quantity = 1;

        $.ajax({
          url: "/user/" + itemsSearchForm.data("current-user-id") + "/items/" + item.id + "/closet_hangers",
          type: "post",
          data: {closet_hanger: closetHanger, return_to: window.location.pathname + window.location.search},
          complete: function () {
            itemsSearchField.removeClass("loading");
          },
          success: function (html) {
            var doc = $(html);
            maintainCheckboxes(function() {
              hangersEl.html( doc.find('#closet-hangers').html() );
              hangersInit();
            });
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
        var item = input.term, itemEl, occupiedGroups, hasHanger;
        for(var i in hangerGroups) {
          group = hangerGroups[i];
          itemEl = $('div.closet-hangers-group[data-owned=' + group.owned + '] div.object[data-item-id=' + item.id + ']');
          occupiedGroups = itemEl.closest('.closet-list');
          hasHanger = occupiedGroups.filter('.unlisted').length > 0;

          groupInserts[groupInserts.length] = {
            group: group,
            item: item,
            label: item.label,
            hasHanger: hasHanger
          }

          for(var i = 0; i < group.lists.length; i++) {
            hasHanger = occupiedGroups.
              filter("[data-id=" + group.lists[i].id + "]").length > 0;
            groupInserts[groupInserts.length] = {
              group: group,
              item: item,
              label: item.label,
              list: group.lists[i],
              hasHanger: hasHanger
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
      $('#autocomplete-item-tmpl').tmpl({item_name: item.label}).appendTo(li);
    } else if(item.list) { // these are list inserts
      var listName = item.list.label;
      if(item.hasHanger) {
        $('#autocomplete-already-in-collection-tmpl').
          tmpl({collection_name: listName}).appendTo(li);
      } else {
        $('#autocomplete-add-to-list-tmpl').tmpl({list_name: listName}).
          appendTo(li);
      }
      li.addClass("closet-list-autocomplete-item");
    } else { // these are group inserts
      var groupName = item.group.label;
      if(!item.hasHanger) {
        $('#autocomplete-add-to-group-tmpl').
          tmpl({group_name: groupName.replace(/\s+$/, '')}).appendTo(li);
      } else {
        $('#autocomplete-already-in-collection-tmpl').
          tmpl({collection_name: groupName}).appendTo(li);
      }
      li.addClass('closet-hangers-group-autocomplete-item');
    }
    return li.appendTo(ul);
  }

  /*

    Contact Neopets username form

  */

  var contactEl = $('#closet-hangers-contact');
  var contactForm = contactEl.children('form');
  var contactField = contactForm.children('select');

  var contactAddOption = $('<option/>',
    {text: contactField.attr('data-new-text'), value: -1});
  contactAddOption.appendTo(contactField);
  var currentUserId = $('meta[name=current-user-id]').attr('content');

  function submitContactForm() {
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
      error: function (xhr) {
        handleSaveError(xhr, 'saving Neopets username');
      }
    });
  }

  contactField.change(function(e) {
    if (contactField.val() < 0) {
      var newUsername = $.trim(prompt(contactField.attr('data-new-prompt'), ''));
      if (newUsername) {
        $.ajax({
          url: '/user/' + currentUserId + '/neopets-connections',
          type: 'POST',
          data: {neopets_connection: {neopets_username: newUsername}},
          dataType: 'json',
          success: function(connection) {
            var newOption = $('<option/>', {text: newUsername,
              value: connection.id})
            newOption.insertBefore(contactAddOption);
            contactField.val(connection.id);
            submitContactForm();
          }
        });
      }
    } else {
      submitContactForm();
    }
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
    $('div.closet-list').droppable({
      accept: 'div.object',
      activate: function () {
        $(this).find('.closet-list-content').animate({opacity: 0, height: 100}, 250);
      },
      activeClass: 'droppable-active',
      deactivate: function () {
        $(this).find('.closet-list-content').css('height', 'auto').animate({opacity: 1}, 250);
      },
      drop: function (e, ui) {
        var form = ui.draggable.find('form.closet-hanger-update');
        form.find('input[name=closet_hanger\[list_id\]]').
          val(this.getAttribute('data-id'));
        form.find('input[name=closet_hanger\[owned\]]').
          val($(this).closest('.closet-hangers-group').attr('data-owned'));
        submitUpdateForm(form);
      }
    });
  });

  /*

    Visibility Descriptions

  */

  function updateVisibilityDescription() {
    var descriptions = $(this).closest('.visibility-form').
      find('ul.visibility-descriptions');

    descriptions.children('li.current').removeClass('current');
    descriptions.children('li[data-id=' + $(this).val() + ']').addClass('current');
  }

  function visibilitySelects() { return $('form.visibility-form select') }

  visibilitySelects().live('change', updateVisibilityDescription);

  onHangersInit(function () {
    visibilitySelects().each(updateVisibilityDescription);
  });

  /*

    Help

  */

  $('#toggle-help').click(function () {
    $('#closet-hangers-help').toggleClass('hidden');
  });

  /*

    Share URL

  */

  $('#closet-hangers-share-box').mouseover(function () {
    $(this).focus();
  }).mouseout(function () {
    $(this).blur();
  });

  /*

    Initialize

  */

  hangersInit();
})();

