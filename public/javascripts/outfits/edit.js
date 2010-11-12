// TODO: replace updateItems triggers, move references to wardrobe.closet to outfit controller

(function () {
  var csrf_param = $('meta[name=csrf-param]').attr('content'),
    csrf_token = $('meta[name=csrf-token]').attr('content');
  $.ajaxSetup({
    data: {csrf_param: csrf_token}
  });
})();

(function () {
  var controlOverlay = $('<div/>', {'class': 'control-overlay'});
  
  $.fn.disableControl = function () {
    this.prepend(controlOverlay.clone()).stop().fadeTo('slow', .35);
  }

  $.fn.enableControl = function () {
    this.stop().fadeTo('fast', 1).children('div.control-overlay').remove();
  }
})();

$.fn.notify = function () {
  this.show('slow').delay(5000).hide('fast');
}

var Partial = {}, main_wardrobe,
  View = Wardrobe.getStandardView({
    Preview: {
      swf_url: '/swfs/preview.swf?v=0.12',
      wrapper: $('#preview'),
      placeholder: $('#preview-swf-container')
    }
  });

Partial.ItemSet = function ItemSet(wardrobe, selector) {
  var item_set = this, ul = $(selector), items = [], setClosetItems,
    setOutfitItems, setOutfitItemsControls, no_assets_full_message = $('#no-assets-full-message'),
    container = $('#container');
  
  Partial.ItemSet.setWardrobe(wardrobe);
  
  function prepSetSpecificItems(type) {
    return function (specific_items) {
      var item, worn, li;
      for(var i = 0; i < items.length; i++) {
        item = items[i];
        in_set = $.inArray(item, specific_items) != -1;
        li = $('li.object-' + item.id).toggleClass(type, in_set).
          data('item', item).data(type, in_set).children('ul').
          children('li.control-set-for-' + type).remove().end()
          [type == 'worn' ? 'prepend' : 'append']
          (Partial.ItemSet.CONTROL_SETS[type][in_set].clone());
      }
    }
  }
  
  setClosetItems = prepSetSpecificItems('closeted');
  
  setOutfitItemsControls = prepSetSpecificItems('worn');
  setOutfitItems = function (specific_items) {
    setOutfitItemsControls(specific_items);
    setHasAssets(specific_items);
  }
  
  function setHasAssets(specific_items) {
    var item, no_assets, li, no_assets_message;
    for(var i = 0, l = specific_items.length; i < l; i++) {
      item = specific_items[i];
      no_assets = item.couldNotLoadAssetsFitting(wardrobe.outfit.getPetType());
      li = $('li.object-' + item.id).toggleClass('no-assets', no_assets);
      (function (li) {
        no_assets_message = li.find('span.no-assets-message');
        no_assets_message.remove();
        if(no_assets) {
          $('<span/>', {'class': 'no-assets-message', text: 'No data yet'}).appendTo(li);
        }
      })(li);
    }
  }
  
  this.setItems = function (new_items) {
    var item, li, controls, info_link;
    items = new_items;
    ul.children().remove();
    for(var i = 0; i < items.length; i++) {
      item = items[i];
      li = $('<li/>', {'class': 'object object-' + item.id});
      img = $('<img/>', {
        'src': item.thumbnail_url,
        'alt': item.description,
        'title': item.description
      });
      controls = $('<ul/>');
      info_link = $('<a/>', {
        'class': 'object-info',
        html: '<span>i</span>',
        href: '/items/' + item.id,
        target: '_blank'
      });
      if(
        typeof item.rarity_index != 'undefined' &&
        (item.rarity_index == 500 || item.rarity_index == 0)
      ) {
        $('<div/>', {'class': 'nc-icon', text: 'NC', title: 'NC'}).appendTo(li);
      }
      li.append(img).append(controls).append(info_link).append(item.name).appendTo(ul);
    }
    setClosetItems(wardrobe.outfit.getClosetItems());
    setOutfitItems(wardrobe.outfit.getWornItems());
  }
  
  $('span.no-assets-message').live('mouseover', function () {
    var el = $(this), o = el.offset();
    no_assets_full_message.css({
      left: o.left + (el.width() / 2) - (no_assets_full_message.width() / 2) - container.offset().left,
      top: o.top + el.height() + 10
    });
  }).live('mouseout', function () {
    no_assets_full_message.removeAttr('style');
  });
  
  wardrobe.outfit.bind('updateItemAssets', function () { setHasAssets(wardrobe.outfit.getWornItems()) });
  wardrobe.outfit.bind('updateWornItems', setOutfitItems);
  wardrobe.outfit.bind('updateClosetItems', setClosetItems);
}

Partial.ItemSet.CONTROL_SETS = {};

Partial.ItemSet.setWardrobe = function (wardrobe) {
  var type, verb_set, toggle, live_class, full_class, toggle_fn = {};
  for(var i = 0; i < 2; i++) {
    type = i == 0 ? 'worn' : 'closeted';
    verb_set = i == 0 ? ['Unwear', 'Wear'] : ['Uncloset', 'Closet'];
    Partial.ItemSet.CONTROL_SETS[type] = {};
    for(var j = 0; j < 2; j++) {
      toggle = j == 0;
      full_class = 'control-set control-set-for-' + type;
      live_class = 'control-set-' + (toggle ? '' : 'not-') + type;
      full_class += ' ' + live_class;
      Partial.ItemSet.CONTROL_SETS[type][toggle] = $('<a/>', {
        href: '#',
        text: verb_set[toggle ? 0 : 1]
      }).wrap('<li/>').parent().attr('class', full_class);
      
      (function (type, toggle) {
        $('li.' + live_class + ' a').live('click', function (e) {
          var el = $(this), item = el.closest('.object').data('item');
          toggle_fn[type][!toggle](item);
          e.preventDefault();
        });
      })(type, toggle);
    }
  }
  
  toggle_fn.closeted = {};
  toggle_fn.closeted[true] = $.proxy(wardrobe.outfit, 'closetItem');
  toggle_fn.closeted[false] = $.proxy(wardrobe.outfit, 'unclosetItem');

  toggle_fn.worn = {};
  toggle_fn.worn[true] = $.proxy(wardrobe.outfit, 'wearItem');
  toggle_fn.worn[false] = $.proxy(wardrobe.outfit, 'unwearItem');
  
  Partial.ItemSet.setWardrobe = $.noop;
}

View.Closet = function (wardrobe) {
  var item_set = new Partial.ItemSet(wardrobe, '#preview-closet ul');
  
  wardrobe.outfit.bind('updateClosetItems', $.proxy(item_set, 'setItems'));
}

View.Fullscreen = function (wardrobe) {
  var full = $(document.body).hasClass('fullscreen'), win = $(window),
    preview_el = $('#preview'), search_el = $('#preview-search-form'),
    preview_swf = $('#preview-swf'), sidebar_el = $('#preview-sidebar'),
    footer = $('#footer');
  
  function fit() {
    if(full) {
      preview_swf = $('#preview-swf'); // swf replaced
      var available = {
        height:  search_el.offset().top - preview_el.offset().top,
        width: preview_el.innerWidth() - sidebar_el.outerWidth() - 12 // 12px margin
      }, dim = {}, margin = {}, size = {
        old: {height: preview_swf.height(), width: preview_swf.width()},
        next: {}
      }, offset;
      if(available.height > available.width) {
        dim.larger = 'height';
        dim.smaller = 'width';
        margin.active = 'marginTop';
        margin.inactive = 'marginLeft';
      } else {
        dim.larger = 'width';
        dim.smaller = 'height';
        margin.active = 'marginLeft';
        margin.inactive = 'marginTop';
      }
      size.next[dim.smaller] = available[dim.smaller];
      size.next[dim.larger] = available[dim.smaller];
      size.next[margin.active] = (available[dim.larger] - size.next[dim.larger]) / 2;
      size.next[margin.inactive] = 0;
      preview_swf.css(size.next);
      
      preview_el.height(available.height);
    }
  }
  $('#preview').data('fit', fit);
  
  win.resize(fit).load(fit);
  fit();
  
  var Konami=function(){var a={addEvent:function(b,c,d,e){if(b.addEventListener)b.addEventListener(c,d,false);else if(b.attachEvent){b["e"+c+d]=d;b[c+d]=function(){b["e"+c+d](window.event,e)};b.attachEvent("on"+c,b[c+d])}},input:"",pattern:"3838404037393739666513",load:function(b){this.addEvent(document,"keydown",function(c,d){if(d)a=d;a.input+=c?c.keyCode:event.keyCode;if(a.input.indexOf(a.pattern)!=-1){a.code(b);a.input=""}},this);this.iphone.load(b)},code:function(b){window.location=b},iphone:{start_x:0,start_y:0,stop_x:0,stop_y:0,tap:false,capture:false,keys:["UP","UP","DOWN","DOWN","LEFT","RIGHT","LEFT","RIGHT","TAP","TAP","TAP"],code:function(b){a.code(b)},load:function(b){a.addEvent(document,"touchmove",function(c){if(c.touches.length==1&&a.iphone.capture==true){c=c.touches[0];a.iphone.stop_x=c.pageX;a.iphone.stop_y=c.pageY;a.iphone.tap=false;a.iphone.capture=false;a.iphone.check_direction()}});a.addEvent(document,"touchend",function(){a.iphone.tap==true&&a.iphone.check_direction(b)},false);a.addEvent(document,"touchstart",function(c){a.iphone.start_x=c.changedTouches[0].pageX;a.iphone.start_y=c.changedTouches[0].pageY;a.iphone.tap=true;a.iphone.capture=true})},check_direction:function(b){x_magnitude=Math.abs(this.start_x-this.stop_x);y_magnitude=Math.abs(this.start_y-this.stop_y);x=this.start_x-this.stop_x<0?"RIGHT":"LEFT";y=this.start_y-this.stop_y<0?"DOWN":"UP";result=x_magnitude>y_magnitude?x:y;result=this.tap==true?"TAP":result;if(result==this.keys[0])this.keys=this.keys.slice(1,this.keys.length);this.keys.length==0&&this.code(b)}}};return a};
  konami = new Konami();
  konami.code = function () {
    $(document.body).removeClass('fullscreen');
    preview_swf.removeAttr('style').css('visibility', 'visible');
    preview_el.removeAttr('style');
    wardrobe.search.setPerPage(21);
    wardrobe.search.setItemsByQuery(wardrobe.search.request.query, {offset: wardrobe.search.request.offset});
    full = false;
  }
  konami.load();
}

View.Hash = function (wardrobe) {
  var data = {}, proposed_data = {}, previous_query, parse_in_progress = false, TYPES = {
    INTEGER: 1,
    STRING: 2,
    INTEGER_ARRAY: 3
  }, KEYS = {
    closet: TYPES.INTEGER_ARRAY,
    color: TYPES.INTEGER,
    name: TYPES.STRING,
    objects: TYPES.INTEGER_ARRAY,
    search: TYPES.STRING,
    search_offset: TYPES.INTEGER,
    species: TYPES.INTEGER,
    state: TYPES.INTEGER
  }, links_with_return_to = $('a[href*=return_to]');
  
  function checkQuery() {
    var query = (document.location.hash || document.location.search).substr(1);
    if(query != previous_query) {
      parseQuery(query);
      previous_query = query;
    }
  }
  
  function parseQuery(query) {
    var new_data = {}, pairs = query.split('&');
    parse_in_progress = true;
    for(var i = 0; i < pairs.length; i++) {
      var pair = pairs[i].split('='),
        key = decodeURIComponent(pair[0]),
        value = decodeURIComponent(pair[1]);
      if(value) {
        if(KEYS[key] == TYPES.INTEGER) {
          new_data[key] = +value;
        } else if(KEYS[key] == TYPES.STRING) {
          new_data[key] = decodeURIComponent(value).replace(/\+/g, ' ');
        } else if(key.substr(key.length-2) == '[]') {
          key = key.substr(0, key.length-2);
          if(KEYS[key] == TYPES.INTEGER_ARRAY) {
            if(typeof new_data[key] == 'undefined') new_data[key] = [];
            new_data[key].push(+value);
          }
        }
      }
    }
    
    if(new_data.color !== data.color || new_data.species !== data.species) {
      wardrobe.outfit.setPetTypeByColorAndSpecies(new_data.color, new_data.species);
    }
    if(new_data.closet) {
      if(!arraysMatch(new_data.closet, data.closet)) {
        wardrobe.outfit.setClosetItemsByIds(new_data.closet.slice(0));
      }
    } else if(new_data.objects && !arraysMatch(new_data.objects, data.closet)) {
      wardrobe.outfit.setClosetItemsByIds(new_data.objects.slice(0));
    } else {
      wardrobe.outfit.setClosetItemsByIds([]);
    }
    if(new_data.objects) {
      if(!arraysMatch(new_data.objects, data.objects)) {
        wardrobe.outfit.setWornItemsByIds(new_data.objects.slice(0));
      }
    } else {
      wardrobe.outfit.setWornItemsByIds([]);
    }
    if(new_data.name != data.name && new_data.name) {
      wardrobe.base_pet.setName(new_data.name);
    }
    if(new_data.state != data.state) {
      wardrobe.outfit.setPetStateById(new_data.state);
    }
    if(new_data.search != data.search || new_data.search_offset != data.search_offset) {
      wardrobe.search.setItemsByQuery(new_data.search, {offset: new_data.search_offset});
    }
    data = new_data;
    parse_in_progress = false;
    updateLinksWithReturnTo();
  }
  
  function changeQuery(changes) {
    var value;
    if(!parse_in_progress) {
      for(var key in changes) {
        if(changes.hasOwnProperty(key)) {
          value = changes[key];
          if(value === undefined) {
            delete data[key];
          } else {
            data[key] = changes[key];
          }
        }
      }
      updateQuery();
    }
  }
  
  function updateQuery() {
    var new_query;
    new_query = $.param(data).replace(/%5B%5D/g, '[]');
    previous_query = new_query;
    document.location.hash = '#' + new_query;
    updateLinksWithReturnTo();
  }
  
  function updateLinksWithReturnTo() {
    links_with_return_to.each(function () {
      var new_return_to = 'return_to=' + encodeURIComponent(
        document.location.pathname +
        document.location.search +
        document.location.hash
      );
      this.href = this.href.replace(/return_to=[^&]+/, new_return_to);
    });
  }
  
  this.initialize = function () {
    checkQuery();
    setInterval(checkQuery, 100);
  }
  
  function singleOutfitResponse(event_name, response) {
    wardrobe.outfit.bind(event_name, function () {
      if(!wardrobe.outfit.in_transaction) response.apply(this, arguments);
    });
  }
  
  singleOutfitResponse('updateClosetItems', function (items) {
    var item_ids = items.map('id');
    if(!arraysMatch(item_ids, data.closet)) {
      changeQuery({closet: item_ids});
    }
  });
  
  singleOutfitResponse('updateWornItems', function (items) {
    var item_ids = items.map('id'), changes = {};
    if(!arraysMatch(item_ids, data.objects)) {
      changes.objects = item_ids;
    }
    if(arraysMatch(item_ids, data.closet) || arraysMatch(item_ids, data.objects)) {
      changes.closet = undefined;
    } else {
      changes.closet = wardrobe.outfit.getClosetItems().map('id');
    }
    if(changes.objects || changes.closet) changeQuery(changes);
  });
  
  singleOutfitResponse('updatePetType', function (pet_type) {
    if(pet_type.color_id != data.color || pet_type.species_id != data.species) {
      changeQuery({
        color: pet_type.color_id,
        species: pet_type.species_id,
        state: undefined
      });
    }
  });
  
  singleOutfitResponse('petTypeNotFound', function () {
    window.history.back();
  });
  
  singleOutfitResponse('updatePetState', function (pet_state) {
    var pet_type = wardrobe.outfit.getPetType();
    if(pet_state.id != data.state && pet_type && (data.state || pet_state.id != pet_type.pet_state_ids[0])) {
      changeQuery({state: pet_state.id});
    }
  });
  
  wardrobe.outfit.bind('setOutfit', function (outfit) {
    changeQuery({
      closet: outfit.getClosetItemIds(),
      color: outfit.pet_type.color_id,
      objects: outfit.getWornItemIds(),
      species: outfit.pet_type.species_id,
      state: outfit.pet_state.id
    });
  });
  
  wardrobe.search.bind('updateRequest', function (request) {
    if(request.offset != data.search_offset || request.query != data.search) {
      changeQuery({
        search_offset: request.offset,
        search: request.query
      });
    }
  });
}

View.Outfits = function (wardrobe) {
  var outfits_el = $('#preview-outfits'), sidebar_el = $('#preview-sidebar'),
    controls = $('#pet-type-form, #pet-state-form, #preview-swf, #preview-search-form'),
    save_success_el = $('#save-success'), save_error_el = $('#save-error'),
    new_outfit_el = $('#new-outfit'), new_outfit_form_el = $('#new-outfit-form'),
    new_outfit_name_el = $('#new-outfit-name'),
    outfits_list_el = outfits_el.children('ul'),
    stars = $('#preview-outfits div.outfit-star'),
    signed_in,
    previously_viewing = '';
  
  function navLinkTo(callback) {
    return function (e) {
      e.preventDefault();
      callback();
    }
  }
  
  function navigateTo(will_be_viewing) {
    var currently_viewing = sidebar_el.attr('class');
    if(currently_viewing != will_be_viewing) previously_viewing = currently_viewing;
    sidebar_el.attr('class', will_be_viewing);
  }
  
  /* Show for login */
  
  signed_in = $('meta[name=user-signed-in]').attr('content') == 'true';
  if(signed_in) {
    $(document.body).addClass('user-signed-in');
  } else {
    $(document.body).addClass('user-not-signed-in');
  }
  
  /* Nav */
  
  function showCloset() {
    controls.enableControl('fast');
    navigateTo('');
  }
  
  function showOutfits() {
    wardrobe.user.loadOutfits();
    controls.enableControl('fast');
    navigateTo('viewing-outfits');
  }
  
  function showSavingOutfit() {
    controls.disableControl('slow');
    navigateTo('viewing-saving-outfit');
    new_outfit_name_el.focus();
  }
  
  $('#preview-sidebar-nav-outfits').click(navLinkTo(showOutfits));
  
  $('#preview-sidebar-nav-closet').click(navLinkTo(showCloset));
  
  $('#preview-sidebar-nav-cancel-save').click(function (e) {
    e.preventDefault();
    controls.enableControl('fast');
    sidebar_el.attr('class', previously_viewing);
  });
  
  $('#save-outfit').click(function () {
    new_outfit_name_el.val('');
    new_outfit_el.removeClass('starred').show();
    showSavingOutfit();
  });
  
  $('#save-outfit-not-signed-in').click(function () {
    window.location.replace($('#userbar a').attr('href'));
  });
  
  /* Outfits list */
  
  $('#outfit-template').template('outfitTemplate');
  
  wardrobe.user.bind('outfitsLoaded', function (outfits) {
    var outfit_els = $.tmpl('outfitTemplate', outfits);
    outfits_list_el.html('').append(outfit_els).addClass('loaded');
  });
  
  wardrobe.user.bind('addOutfit', function (outfit, i) {
    var next_child = outfits_list_el.children().not('.hiding').eq(i),
      outfit_el = $.tmpl('outfitTemplate', outfit);
    if(next_child.length) {
      outfit_el.insertBefore(next_child);
    } else {
      outfit_el.appendTo(outfits_list_el);
    }
    outfit_el.hide().show('normal');
  });
  
  wardrobe.user.bind('removeOutfit', function (outfit, i) {
    var outfit_el = outfits_list_el.children().not('.hiding').eq(i);
    outfit_el.addClass('hiding').hide('normal', function () { outfit_el.remove() });
  });
  
  $('#preview-outfits h4').live('click', function () {
    wardrobe.outfit.load($(this).tmplItem().data.clone());
  });
  
  $('input.outfit-url').live('mouseover', function () {
    this.focus();
  }).live('mouseout', function () {
    this.blur();
  });
  
  $('button.outfit-delete').live('click', function (e) {
    e.preventDefault();
    $(this).closest('li').addClass('confirming-deletion');
  });
  
  $('a.outfit-delete-confirmation-yes').live('click', function (e) {
    e.preventDefault();
    wardrobe.user.destroyOutfit($(this).tmplItem().data);
  });
  
  $('a.outfit-delete-confirmation-no').live('click', function (e) {
    e.preventDefault();
    $(this).closest('li').removeClass('confirming-deletion');
  });
  
  stars.live('click', function () {
    var el = $(this);
    setTimeout(function () { el.addClass('loading') }, 1000);
    wardrobe.user.toggleOutfitStar(el.tmplItem().data);
  });
  
  wardrobe.user.bind('outfitStarToggled', function (outfit) {
    // test
  });
  
  /* Saving */
  
  new_outfit_form_el.submit(function (e) {
    e.preventDefault();
    wardrobe.outfit.save(new_outfit_el.hasClass('starred'), new_outfit_name_el.val());
  });
  
  new_outfit_el.find('div.outfit-star').click(function () {
    new_outfit_el.toggleClass('starred');
  });
  
  var SAVE_ERRORS = {
      'item_outfit_relationships': "Item not found. How odd. Pull some items out of your closet and try again.",
      'pet_state': "Pet state not found. How odd. Try picking a new Gender/Emotion.",
      'name': "Outfits must have a name",
      'user': "You must be logged in to save outfits"
    };
  
  function saveErrorMessage(text) {
    save_error_el.text(text).notify();
  }
  
  wardrobe.outfit.bind('saveSuccess', function (outfit) {
    wardrobe.user.addOutfit(outfit);
    save_success_el.notify();
    showOutfits();
  });
  
  wardrobe.outfit.bind('saveFailure', function (response) {
    var errors = response.errors;
    if(typeof errors == 'undefined') {
      saveErrorMessage("Whoops! The save failed, but the server didn't say why. Please try again.");
    } else {
      for(var key in SAVE_ERRORS) {
        if(SAVE_ERRORS.hasOwnProperty(key) && typeof errors[key] != 'undefined') {
          saveErrorMessage(SAVE_ERRORS[key]);
          break;
        }
      }
    }
  });
}

View.PetStateForm = function (wardrobe) {
  var INPUT_NAME = 'pet_state_id', form_query = '#pet-state-form',
    form = $(form_query),
    ul = form.children('ul'),
    radio_query = form_query + ' input[name=' + INPUT_NAME + ']';
  $(radio_query).live('click', function () {
    wardrobe.outfit.setPetStateById(+this.value);
  });
  
  function updatePetState(pet_state) {
    if(pet_state) {
      ul.children('li.selected').removeClass('selected');
      $(radio_query + '[value=' + pet_state.id + ']')
        .attr('checked', 'checked').parent().addClass('selected');
    }
  }
  
  wardrobe.outfit.bind('petTypeLoaded', function (pet_type) {
    var ids = pet_type.pet_state_ids, i, id, li, radio, label;
    ul.children().remove();
    if(ids.length == 1) {
      form.addClass('hidden');
    } else {
      form.removeClass('hidden');
      for(var i = 0; i < ids.length; i++) {
        id = 'pet-state-radio-' + i;
        li = $('<li/>');
        radio = $('<input/>', {
          id: id,
          name: INPUT_NAME,
          type: 'radio',
          value: ids[i]
        });
        label = $('<label/>', {
          'for': id,
          text: i + 1
        });
        if(i == 0) radio.attr('checked', 'checked');
        radio.appendTo(li);
        label.appendTo(li);
        li.appendTo(ul);
      }
      updatePetState(wardrobe.outfit.pet_state);
    }
  });
  
  wardrobe.outfit.bind('updatePetState', updatePetState);
}

View.PetTypeForm = function (wardrobe) {
  var form = $('#pet-type-form'), dropdowns = {}, loaded = false;
  form.submit(function (e) {
    e.preventDefault();
    wardrobe.outfit.setPetTypeByColorAndSpecies(
      +dropdowns.color.val(), +dropdowns.species.val()
    );
  }).children('select').each(function () {
    dropdowns[this.name] = $(this);
  });
  
  this.initialize = function () {
    wardrobe.pet_attributes.load();
  }
  
  function updatePetType(pet_type) {
    if(loaded && pet_type) {
      $.each(dropdowns, function (name) {
        dropdowns[name].val(pet_type[name + '_id']);
      });
    }
  }
  
  wardrobe.pet_attributes.bind('update', function (attributes) {
    $.each(attributes, function (type) {
      var dropdown = dropdowns[type];
      $.each(this, function () {
        var option = $('<option/>', {
          text: this.name,
          value: this.id
        });
        option.appendTo(dropdown);
      });
    });
    loaded = true;
    updatePetType(wardrobe.outfit.getPetType());
  });
  
  wardrobe.outfit.bind('updatePetType', updatePetType);
  
  wardrobe.outfit.bind('petTypeNotFound', function () {
    $('#pet-type-not-found').show('normal').delay(3000).hide('fast');
  });
}

View.Search = function (wardrobe) {
  var form_selector = '#preview-search-form', form = $(form_selector),
    item_set = new Partial.ItemSet(wardrobe, form_selector + ' ul'),
    input_el = form.find('input[name=query]'),
    clear_el = $('#preview-search-form-clear'),
    error_el = $('#preview-search-form-error'),
    help_el = $('#preview-search-form-help'),
    loading_el = $('#preview-search-form-loading'),
    no_results_el = $('#preview-search-form-no-results'),
    no_results_span = no_results_el.children('span'),
    PAGINATION = {
      INNER_WINDOW: 4,
      OUTER_WINDOW: 1,
      GAP_TEXT: '&hellip;',
      PREV_TEXT: '&larr; Previous',
      NEXT_TEXT: 'Next &rarr;',
      PAGE_EL: $('<a/>', {href: '#'}),
      CURRENT_EL: $('<span/>', {'class': 'current'}),
      EL_ID: '#preview-search-form-pagination',
      PER_PAGE: 21
    }, object_width = 112, last_request;
    
  PAGINATION.EL = $(PAGINATION.EL_ID);
  PAGINATION.GAP_EL = $('<span/>', {'class': 'gap', html: PAGINATION.GAP_TEXT})
  PAGINATION.PREV_EL = $('<a/>', {href: '#', rel: 'prev', html: PAGINATION.PREV_TEXT});
  PAGINATION.NEXT_EL = $('<a/>', {href: '#', rel: 'next', html: PAGINATION.NEXT_TEXT});
  
  $(PAGINATION.EL_ID + ' a').live('click', function (e) {
    e.preventDefault();
    loadPage($(this).data('page'));
  });
  
  this.initialize = $.proxy(wardrobe.item_zone_sets, 'load');
  
  wardrobe.search.setPerPage(PAGINATION.PER_PAGE);
  
  function updatePerPage() {
    var new_per_page = Math.floor(form.width() / object_width),
      offset, new_page;
    if(new_per_page != PAGINATION.PER_PAGE) {
      PAGINATION.PER_PAGE = new_per_page;
      wardrobe.search.setPerPage(PAGINATION.PER_PAGE);
      if(last_request) {
        loadOffset(last_request.offset);
      }
    }
  }
  $(window).resize(updatePerPage).load(updatePerPage);
  updatePerPage();
  
  function loadOffset(offset) {
    wardrobe.search.setItemsByQuery(input_el.val(), {offset: offset});
  }
  
  function loadPage(page) {
    wardrobe.search.setItemsByQuery(input_el.val(), {page: page});
  }
  
  function stopLoading() {
    loading_el.stop(true, true).hide();
  }
  
  form.submit(function (e) {
    e.preventDefault();
    loadPage(1);
  });
  
  clear_el.click(function (e) {
    e.preventDefault();
    input_el.val('');
    form.submit();
  });
  
  wardrobe.search.bind('startRequest', function () {
    loading_el.delay(1000).show('slow');
  });
  
  wardrobe.search.bind('updateItems', function (items) {
    var fit = $('#preview').data('fit') || $.noop;
    stopLoading();
    item_set.setItems(items);
    if(wardrobe.search.request.query) {
      if(!items.length) {
        no_results_el.show();
      }
    } else {
      help_el.show();
    }
    form.toggleClass('has-results', items.length > 0);
    fit();
  });
  
  wardrobe.search.bind('updateRequest', function (request) {
    last_request = request;
    error_el.hide('fast');
    help_el.hide();
    no_results_el.hide();
    input_el.val(request.query || '');
    no_results_span.text(request.query);
    clear_el.toggle(!!request.query);
  });
  
  wardrobe.search.bind('updatePagination', function (current_page, total_pages) {
    // ported from http://github.com/mislav/will_paginate/blob/master/lib/will_paginate/view_helpers.rb#L274
    var window_from = current_page - PAGINATION.INNER_WINDOW,
      window_to = current_page + PAGINATION.INNER_WINDOW,
      visible = [], left_gap, right_gap, subtract_left, subtract_right,
      i = 1;
    
    if(window_to > total_pages) {
      window_from -= window_to - total_pages;
      window_to = total_pages;
    }
    
    if(window_from < 1) {
      window_to += 1 - window_from;
      window_from = 1;
      if(window_to > total_pages) window_to = total_pages;
    }
    
    left_gap  = [2 + PAGINATION.OUTER_WINDOW, window_from];
    right_gap = [window_to + 1, total_pages - PAGINATION.OUTER_WINDOW];
    
    subtract_left = (left_gap[1] - left_gap[0]) > 1;
    subtract_right = (right_gap[1] - right_gap[0]) > 1;
    
    PAGINATION.EL.children().remove();
    
    if(current_page > 1) {
      PAGINATION.PREV_EL.clone().data('page', current_page - 1).appendTo(PAGINATION.EL);
    }
    
    while(i <= total_pages) {
      if(subtract_left && i >= left_gap[0] && i < left_gap[1]) {
        PAGINATION.GAP_EL.clone().appendTo(PAGINATION.EL);
        i = left_gap[1];
      } else if(subtract_right && i >= right_gap[0] && i < right_gap[1]) {
        PAGINATION.GAP_EL.clone().appendTo(PAGINATION.EL);
        i = right_gap[1];
      } else {
        if(i == current_page) {
          PAGINATION.CURRENT_EL.clone().text(i).appendTo(PAGINATION.EL);
        } else {
          PAGINATION.PAGE_EL.clone().text(i).data('page', i).appendTo(PAGINATION.EL);
        }
        i++;
      }
    }
    
    if(current_page < total_pages) {
      PAGINATION.NEXT_EL.clone().data('page', current_page + 1).appendTo(PAGINATION.EL);
    }
  });
  
  wardrobe.search.bind('error', function (error) {
    stopLoading();
    error_el.text(error).show('normal');
  });
  
  help_el.find('dt').each(function () {
    var el = $(this);
    if(!el.children().length) {
      el.wrapInner($('<a/>', {href: '#'}));
    }
  }).children('span:not(.search-helper)').each(function () {
    var el = $(this);
    el.replaceWith($('<a/>', {href: '#', text: el.text()}));
  });
  
  help_el.find('dt a').live('click', function (e) {
    var el = $(this), siblings = el.parent().children(), query;
    e.preventDefault();
    if(siblings.length > 1) {
      query = siblings.map(function () {
        var el = $(this);
        return el[el.is('select') ? 'val' : 'text']();
      }).get().join('');
    } else {
      query = el.text();
    }
    input_el.val(query);
    form.submit();
  });
  
  $('select.search-helper').live('change', function () {
    var el = $(this), filter = el.attr('data-search-filter');
    $('select.search-helper[data-search-filter=' + filter + ']').val(el.val());
  });
  
  function prepBuildHelper(type, getSet) {
    return function (objs) {
      var select = $('<select/>',
        {'class': 'search-helper', 'data-search-filter': type}),
        span = $('span.search-helper[data-search-filter=' + type + ']');
      objs = getSet(objs);
      for(var i = 0, l = objs.length; i < l; i++) {
        $('<option/>', {text: objs[i].name}).appendTo(select);
      }
      span.replaceWith(function () {
        return select.clone().fadeIn('fast');
      });
    }
  }
  
  function getSpecies(x) { return x.species }
  
  wardrobe.item_zone_sets.bind('update', prepBuildHelper('type', function (x) {
    return x;
  }));
  
  wardrobe.pet_attributes.bind('update', prepBuildHelper('species', getSpecies));
  //wardrobe.pet_attributes.bind('update', prepBuildHelper('only', getSpecies));
}

View.Title = function (wardrobe) {
  wardrobe.base_pet.bind('updateName', function (name) {
    $('#title').text("Planning " + name + "'s outfit");
  });
}

var userbar_sessions_link = $('#userbar a:last'),
  userbar_message_verb = userbar_sessions_link.text() == 'Log out' ? 'logged out' : 'sent to the login page',
  userbar_message_el = $('<span/>', {
    id: 'userbar-message',
    text: "You will be " + userbar_message_verb + ", then brought back to this exact outfit you've made."
  }).prependTo('#userbar');

userbar_sessions_link.hover(function () {
  userbar_message_el.stop().fadeTo('normal', .5);
}, function () {
  userbar_message_el.stop().fadeOut('fast');
});

$.ajaxSetup({
  error: function (xhr) {
    $.jGrowl("There was an error loading that last resource. Oops. Please try again!");
  }
});

main_wardrobe = new Wardrobe();
main_wardrobe.registerViews(View);
main_wardrobe.initialize();
