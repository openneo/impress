$.fn.notify = function () {
  return this.stop(true, true).show('slow').delay(5000).hide('fast');
}

$.fn.startLoading = function () {
  return this.delay(1000).queue(function (next) {
    $(this).addClass('loading');
    next();
  });
}

$.fn.stopLoading = function () {
  return this.removeClass('loading').clearQueue();
}

var Partial = {}, main_wardrobe,
  View = Wardrobe.getStandardView({
    Preview: {
      swf_url: '/swfs/preview.swf?v=0.12',
      wrapper: $('#preview-swf'),
      placeholder: $('#preview-swf-container'),
      image_container: '#preview-image-container'
    }
  });

Partial.ItemSet = function ItemSet(wardrobe, selector) {
  var item_set = this, ul = $(selector), items = [], setClosetItems,
    setOutfitItems, setOutfitItemsControls, no_assets_full_message = $('#no-assets-full-message'),
    container = $('#container'), item_template = $('#item-template');

  Partial.ItemSet.setWardrobe(wardrobe);

  function prepSetSpecificItems(type) {
    return function (specific_items) {
      var item, worn, li;
      for(var i = 0; i < items.length; i++) {
        item = items[i];
        in_set = $.inArray(item, specific_items) != -1;
        li = $('li.object-' + item.id).toggleClass(type, in_set).
          data('item', item).data(type, in_set);
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
      no_assets = item.couldNotLoadAssetsFitting(wardrobe.outfits.getPetType());
      li = $('li.object-' + item.id).toggleClass('no-assets', no_assets);
    }
  }

  this.setItems = function (new_items) {
    var item, li, controls, info_link;
    items = new_items;
    ul.children().remove();
    for(var i = 0; i < items.length; i++) {
      item = items[i];
      li = item_template.tmpl({
        id: item.id,
        name: item.name,
        description: item.description,
        thumbnail_url: item.thumbnail_url,
        url: item.getURL(),
        nc: typeof item.rarity_index != 'undefined' &&
            (item.rarity_index == 500 || item.rarity_index == 0),
        owned: item.owned,
        wanted: item.wanted
      });
      li.appendTo(ul);
    }
    setClosetItems(wardrobe.outfits.getClosetItems());
    setOutfitItems(wardrobe.outfits.getWornItems());
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

  wardrobe.outfits.bind('updateItemAssets', function () { setHasAssets(wardrobe.outfits.getWornItems()) });
  wardrobe.outfits.bind('updateWornItems', setOutfitItems);
  wardrobe.outfits.bind('updateClosetItems', setClosetItems);
}

Partial.ItemSet.CONTROL_SETS = {};

Partial.ItemSet.setWardrobe = function (wardrobe) {
  var type, toggle, toggle_fn = {}, toggle_classes = {worn: {}, closeted: {}};
  
  toggle_classes.worn['false'] = 'wear-item';
  toggle_classes.worn['true'] = 'unwear-item';
  toggle_classes.closeted['false'] = 'closet-item';
  toggle_classes.closeted['true'] = 'uncloset-item';
  
  for(type in toggle_classes) {
    for(toggleKey in toggle_classes[type]) {
      var toggle = (toggleKey == 'true');
      (function (type, toggle) {
        $('li.' + toggle_classes[type][toggle] + ' a').live('click', function (e) {
          e.preventDefault();
          var item = $(this).closest('.object').data('item');
          log(this, item, type, toggle, !toggle);
          toggle_fn[type][!toggle](item);
        });
      })(type, toggle);
    }
  }

  toggle_fn.closeted = {};
  toggle_fn.closeted[true] = $.proxy(wardrobe.outfits, 'closetItem');
  toggle_fn.closeted[false] = $.proxy(wardrobe.outfits, 'unclosetItem');

  toggle_fn.worn = {};
  toggle_fn.worn[true] = $.proxy(wardrobe.outfits, 'wearItem');
  toggle_fn.worn[false] = $.proxy(wardrobe.outfits, 'unwearItem');

  Partial.ItemSet.setWardrobe = $.noop;
}

View.Closet = function (wardrobe) {
  var item_set = new Partial.ItemSet(wardrobe, '#preview-closet ul');

  wardrobe.outfits.bind('updateClosetItems', $.proxy(item_set, 'setItems'));
}

View.Fullscreen = function (wardrobe) {
  var full = $(document.body).hasClass('fullscreen'), win = $(window),
    preview_el = $('#preview'), search_el = $('#preview-search'),
    preview_swf = $('#preview-swf'), sidebar_el = $('#preview-sidebar'),
    sidebar_content_el = $('#preview-sidebar-content'),
    sidebar_navbar_el = $('#preview-sidebar-navbar'), footer = $('#footer'),
    jwindow = $(window), overrideFull = false;

  function fit() {
    if(!overrideFull) {
      var newFull = jwindow.height() > 500;
      if(newFull != full) {
        full = newFull;
        $(document.body).toggleClass('fullscreen', full);
        if(!full) {
          preview_swf.removeAttr('style').css('visibility', 'visible');
          preview_el.removeAttr('style');
          sidebar_content_el.removeAttr('style');
        }
      }
    }

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

      // If the footer goes onto two lines, nudge search up.
      search_el.css('bottom', $('#footer').height());

      // Now that preview is fit, we fit the sidebar's content element, which
      // also has to deal with the constraint of its navbar's height.
      var sidebar_content_height = available.height -
        sidebar_navbar_el.outerHeight() - 1; // 1px bottom border
      sidebar_content_el.height(sidebar_content_height);
    }
  }
  $('#preview').data('fit', fit);

  win.resize(fit).load(fit);
  fit();
}

View.Hash = function (wardrobe) {
  var data = {}, proposed_data = {}, previous_query, parse_in_progress = false, TYPES = {
    INTEGER: 1,
    STRING: 2,
    INTEGER_ARRAY: 3
  }, KEYS = {
    biology: TYPES.INTEGER_ARRAY,
    closet: TYPES.INTEGER_ARRAY,
    color: TYPES.INTEGER,
    name: TYPES.STRING,
    objects: TYPES.INTEGER_ARRAY,
    outfit: TYPES.INTEGER,
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

    if(new_data.biology) {
      wardrobe.outfits.setPetStateAssetsByIds(new_data.biology);
    }
    if(new_data.color !== data.color || new_data.species !== data.species) {
      wardrobe.outfits.setPetTypeByColorAndSpecies(new_data.color, new_data.species);
    }
    if(new_data.closet) {
      if(!arraysMatch(new_data.closet, data.closet)) {
        wardrobe.outfits.setClosetItemsByIds(new_data.closet.slice(0));
      }
    } else if(new_data.objects && !arraysMatch(new_data.objects, data.closet)) {
      wardrobe.outfits.setClosetItemsByIds(new_data.objects.slice(0));
    } else {
      wardrobe.outfits.setClosetItemsByIds([]);
    }
    if(new_data.objects) {
      if(!arraysMatch(new_data.objects, data.objects)) {
        wardrobe.outfits.setWornItemsByIds(new_data.objects.slice(0));
      }
    } else {
      wardrobe.outfits.setWornItemsByIds([]);
    }
    if(new_data.name != data.name && new_data.name) {
      wardrobe.base_pet.setName(new_data.name);
    }
    if(new_data.state != data.state) {
      wardrobe.outfits.setPetStateById(new_data.state);
    }
    if(new_data.outfit != data.outfit) {
      wardrobe.outfits.setId(new_data.outfit);
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
    wardrobe.outfits.bind(event_name, function () {
      if(!wardrobe.outfits.in_transaction) response.apply(this, arguments);
    });
  }

  singleOutfitResponse('updateClosetItems', function (items) {
    var item_ids = items.mapProperty('id');
    if(!arraysMatch(item_ids, data.closet)) {
      changeQuery({closet: item_ids});
    }
  });

  singleOutfitResponse('updateWornItems', function (items) {
    var item_ids = items.mapProperty('id'), changes = {};
    if(!arraysMatch(item_ids, data.objects)) {
      changes.objects = item_ids;
    }
    if(arraysMatch(item_ids, data.closet) || arraysMatch(item_ids, data.objects)) {
      changes.closet = undefined;
    } else {
      changes.closet = wardrobe.outfits.getClosetItems().mapProperty('id');
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
    var pet_type = wardrobe.outfits.getPetType();
    if(pet_state.id != data.state && pet_type) {
      changeQuery({biology: undefined, state: pet_state.id});
    }
  });

  singleOutfitResponse('setOutfit', function (outfit) {
    if(outfit.id != data.outfit) {
      changeQuery({outfit: outfit.id});
    }
  });

  wardrobe.outfits.bind('loadOutfit', function (outfit) {
    changeQuery({
      biology: undefined,
      closet: outfit.getClosetItemIds(),
      color: outfit.pet_type.color_id,
      objects: outfit.getWornItemIds(),
      outfit: outfit.id,
      species: outfit.pet_type.species_id,
      state: outfit.pet_state.id
    });
  });

  wardrobe.outfits.bind('outfitNotFound', function (outfit) {
    var new_id = outfit ? outfit.id : undefined;
    changeQuery({outfit: new_id});
  });

  wardrobe.search.bind('updateRequest', function (request) {
    if(request.offset != data.search_offset || request.query != data.search) {
      if (typeof request.query === "string") {
        changeQuery({
          search_offset: request.offset,
          search: request.query
        });
      }
    }
  });
}

View.Outfits = function (wardrobe) {
  var current_outfit_permalink_el = $('#current-outfit-permalink'),
    new_outfit_form_el = $('#save-outfit-form'),
    new_outfit_name_el = $('#save-outfit-name'),
    outfits_el = $('#preview-outfits'),
    outfits_list_el = outfits_el.children('ul'),
    outfit_not_found_el = $('#outfit-not-found'),
    save_current_outfit_el = $('#save-current-outfit'),
    save_current_outfit_name_el = save_current_outfit_el.children('span'),
    save_outfit_wrapper_el = $('#save-outfit-wrapper'),
    save_success_el = $('#save-success'),
    save_error_el = $('#save-error'),
    stars = $('#preview-outfits div.outfit-star'),
    sidebar_el = $('#preview-sidebar'),
    signed_in,
    previously_viewing = '';

  function liForOutfit(outfit) {
    return $('li.outfit-' + outfit.id);
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
    sharing.onHide();
    navigateTo('');
  }

  function showOutfits() {
    sharing.onHide();
    wardrobe.outfits.loadOutfits();
    navigateTo('viewing-outfits');
  }
  
  function showSharing() {
    sharing.onShow();
    navigateTo('sharing');
  }

  function showNewOutfitForm() {
    new_outfit_name_el.val('');
    new_outfit_form_el.removeClass('starred').stopLoading();
    save_outfit_wrapper_el.addClass('saving-outfit');
    new_outfit_name_el.focus();
  }

  function hideNewOutfitForm() {
    save_outfit_wrapper_el.removeClass('saving-outfit');
  }

  $('#preview-sidebar-navbar-closet').click(showCloset);
  $('#preview-sidebar-navbar-sharing').click(function () {
    sharing.startLoading();
    wardrobe.outfits.share();
    showSharing();
  });
  $('#preview-sidebar-navbar-outfits').click(showOutfits);

  $('#save-outfit, #save-outfit-copy').click(showNewOutfitForm);

  $('#save-outfit-cancel').click(hideNewOutfitForm);

  $('#save-outfit-not-signed-in').click(function () {
    window.location.replace($('#userbar a').attr('href'));
  });

  /* Outfits list */
  
  var list_image_subscriptions = {};
  
  function listSubscribeToImage(outfit) {
    list_image_subscriptions[outfit.id] = wardrobe.image_subscriptions.subscribe(outfit);
  }
  
  function listUnsubscribeFromImage(outfit) {
    if(outfit.id in list_image_subscriptions) {
      if(list_image_subscriptions[outfit.id] !== null) {
        wardrobe.image_subscriptions.unsubscribe(list_image_subscriptions[outfit.id]);
      }
      
      delete list_image_subscriptions[outfit.id];
    }
  }

  $('#outfit-template').template('outfitTemplate');

  wardrobe.outfits.bind('outfitsLoaded', function (outfits) {
    var outfit_els = $.tmpl('outfitTemplate', outfits);
    outfits_list_el.html('').append(outfit_els).addClass('loaded');
    updateActiveOutfit();
    
    for(var i = 0; i < outfits.length; i++) {
      listSubscribeToImage(outfits[i]);
    }
  });

  wardrobe.outfits.bind('addOutfit', function (outfit, i) {
    var next_child = outfits_list_el.children().not('.hiding').eq(i),
      outfit_el = $.tmpl('outfitTemplate', outfit.clone());
    if(next_child.length) {
      outfit_el.insertBefore(next_child);
    } else {
      outfit_el.appendTo(outfits_list_el);
    }
    updateActiveOutfit();
    
    var naturalWidth = outfit_el.css('width');
    log("Natural width is", naturalWidth, outfit_el.width());
    outfit_el.width(0).animate({width: naturalWidth}, 'normal');
    listSubscribeToImage(outfit);
  });

  wardrobe.outfits.bind('removeOutfit', function (outfit, i) {
    var outfit_el = outfits_list_el.children().not('.hiding').eq(i);
    outfit_el.addClass('hiding').stop(true).animate({width: 0}, 'normal', function () { outfit_el.remove() });
    listUnsubscribeFromImage(outfit);
  });

  $('#preview-outfits li header, #preview-outfits li .outfit-thumbnail-wrapper').live('click', function () {
    wardrobe.outfits.load($(this).tmplItem().data.id);
  });

  $('a.outfit-rename-button').live('click', function (e) {
    e.preventDefault();
    var li = $(this).closest('li').addClass('renaming'),
      name = li.find('span.outfit-name').text();
    li.find('input.outfit-rename-field').val(name).focus();
  });

  function submitRename() {
    var el = $(this), outfit = el.tmplItem().data, new_name = el.val(),
      li = el.closest('li').removeClass('renaming');
    if(new_name != outfit.name) {
      li.startLoading();
      wardrobe.outfits.renameOutfit(outfit, new_name);
    }
  }

  $('input.outfit-rename-field').live('blur', submitRename);

  $('form.outfit-rename-form').live('submit', function (e) {
    e.preventDefault();
    var input = $(this).find('input');
    submitRename.apply(input);
  });

  $('input.outfit-url').live('mouseover', function () {
    this.focus();
  }).live('mouseout', function () {
    this.blur();
  });

  $('a.outfit-delete').live('click', function (e) {
    e.stopPropagation();
    e.preventDefault();
    $(this).closest('li').addClass('confirming-deletion');
  });

  $('a.outfit-delete-confirmation-yes').live('click', function (e) {
    var outfit = $(this).tmplItem().data;
    e.preventDefault();
    wardrobe.outfits.destroyOutfit(outfit);
    if(wardrobe.outfits.getOutfit().id == outfit.id) {
      wardrobe.outfits.setId(null);
    }
  });

  $('a.outfit-delete-confirmation-no').live('click', function (e) {
    e.preventDefault();
    $(this).closest('li').removeClass('confirming-deletion');
  });

  stars.live('click', function (e) {
    e.stopPropagation();
    var el = $(this);
    el.closest('li').startLoading();
    wardrobe.outfits.toggleOutfitStar(el.tmplItem().data);
  });
  
  function absoluteUrl(path_or_url) {
    if(path_or_url.indexOf('://') == -1) {
      var host = document.location.protocol + "//" + document.location.host;
      return host + path_or_url;
    } else {
      return path_or_url;
    }
  }
  
  function generateOutfitPermalink(outfit) {
    return absoluteUrl("/outfits/" + outfit.id);
  }

  function setOutfitPermalink(outfit, outfit_permalink_el, outfit_url_el) {
    var url = generateOutfitPermalink(outfit);
    outfit_permalink_el.attr('href', url);
    if(outfit_url_el) outfit_url_el.val(url);
  }

  function setCurrentOutfitPermalink(outfit) {
    setOutfitPermalink(outfit, current_outfit_permalink_el);
  }

  function setActiveOutfit(outfit) {
    outfits_list_el.find('li.active').removeClass('active');
    if(outfit.id) {
      setCurrentOutfitPermalink(outfit);
      liForOutfit(outfit).addClass('active');
      save_current_outfit_name_el.text(outfit.name);
    }
    save_outfit_wrapper_el.toggleClass('active-outfit', outfit.id ? true : false);
  }

  function updateActiveOutfit() {
    setActiveOutfit(wardrobe.outfits.getOutfit());
  }

  wardrobe.outfits.bind('setOutfit', setActiveOutfit);
  wardrobe.outfits.bind('outfitNotFound', setActiveOutfit);

  wardrobe.outfits.bind('outfitRenamed', function (outfit) {
    if(outfit.id == wardrobe.outfits.getId()) {
      save_current_outfit_name_el.text(outfit.name);
    }
  });
  
  function outfitElement(outfit) {
    return outfits_el.find('li.outfit-' + outfit.id);
  }
  
  wardrobe.outfits.bind('saveSuccess', function (outfit) {
    listSubscribeToImage(outfit);
  });
  
  wardrobe.image_subscriptions.bind('imageEnqueued', function (outfit) {
    if(outfit.id in list_image_subscriptions) {
      log("List sees imageEnqueued for", outfit);
      outfitElement(outfit).removeClass('thumbnail-loaded');
    }
  });
  
  wardrobe.image_subscriptions.bind('imageReady', function (outfit) {
    if(outfit.id in list_image_subscriptions) {
      log("List sees imageReady for", outfit);
      listUnsubscribeFromImage(outfit);
      
      var src = outfit.image_versions.small + '?' + (new Date()).getTime();
      outfitElement(outfit).addClass('thumbnail-loaded').addClass('thumbnail-available').
        find('img.outfit-thumbnail').attr('src', src);
    }
  });
  
  /* Sharing */
  
  var sharing = new function Sharing() {
    var WRAPPER = $('#preview-sharing');
    var sharing_url_els = {
      permalink: $('#preview-sharing-permalink-url'),
      large_image: $('#preview-sharing-large-image-url'),
      medium_image: $('#preview-sharing-medium-image-url'),
      small_image: $('#preview-sharing-small-image-url'),
    };
    var format_selector_els = $('#preview-sharing-url-formats li');
    var thumbnail_el = $('#preview-sharing-thumbnail');
    var templates = {
      html: {
        image: $('#sharing-html-image-template'),
        text: $('#sharing-html-text-template')
      },
      bbcode: {
        image: $('#sharing-bbcode-image-template'),
        text: $('#sharing-bbcode-text-template')
      }
    }
    
    function templateHTML(template, options) {
      var contents = template.tmpl(options);
      var contentsHTML = contents.clone().wrap('<div>').parent().html();
      return contentsHTML;
    }
    
    // The HTML and BBCode formats could probably be handled more dynamic-like.
    var formats = {
      plain: {
        image: function (image_url) { return image_url },
        text: function (permalink) { return permalink }
      },
      html: {
        image: function (image_url, permalink) {
          return templateHTML(templates.html.image, {
            image_url: image_url,
            permalink: permalink
          });
        },
        text: function (permalink) {
          return templateHTML(templates.html.text, {
            permalink: permalink
          });
        }
      },
      bbcode: {
        image: function (image_url, permalink) {
          return templateHTML(templates.bbcode.image, {
            image_url: image_url,
            permalink: permalink
          });
        },
        text: function (permalink) {
          return templateHTML(templates.bbcode.text, {
            permalink: permalink
          });
        }
      }
    };
    
    var format = formats.plain;
    var urls = {permalink: null, small_image: null, medium_image: null,
      large_image: null};
    
    format_selector_els.click(function () {
      var selector_el = $(this);
      format_selector_els.removeClass('active');
      selector_el.addClass('active');
      log("Setting sharing URL format:", selector_el.attr('data-format'));
      format = formats[selector_el.attr('data-format')];
      formatUrls();
    });
    
    var image_subscription = null;
    function unsubscribeFromImage() {
      wardrobe.image_subscriptions.unsubscribe(image_subscription);
      image_subscription = null;
    }
    
    function subscribeToImage(outfit) {
      image_subscription = wardrobe.image_subscriptions.subscribe(outfit);
    }
    
    function subscribeToImageIfVisible(outfit) {
      if(outfit && sidebar_el.hasClass('sharing')) {
        subscribeToImage(outfit);
      }
    }
    
    var current_shared_outfit = {id: null};
    this.setOutfit = function (outfit) {
      // If outfit has no ID but we're already on the Sharing tab (e.g. user is
      // on Sharing but goes back in history to a no-ID outfit), we can't
      // exactly do anything with it but submit it for sharing.
      if(!outfit.id) {
        sharing.startLoading();
        wardrobe.outfits.share(outfit);
        return false;
      }
      
      // But if the outfit does have a valid ID, we're good to go. If it's the
      // same as the currently shared outfit ID, then don't even change
      // anything. If it's new, then change everything.
      if(outfit.id != current_shared_outfit.id) {
        // The current shared outfit needs to be a clone, or else modifications
        // to the active outfit will show up here, too, and then our comparison
        // to discover if this is a new outfit ID or not fails.
        current_shared_outfit = outfit.clone();
        urls.permalink = generateOutfitPermalink(outfit);
        urls.small_image = absoluteUrl(outfit.image_versions.small);
        urls.medium_image = absoluteUrl(outfit.image_versions.medium);
        urls.large_image = absoluteUrl(outfit.image_versions.large);
        formatUrls();
        WRAPPER.removeClass('thumbnail-available');
        subscribeToImageIfVisible(current_shared_outfit);
      }
      WRAPPER.addClass('urls-loaded');
    }
    
    this.startLoading = function () {
      WRAPPER.removeClass('urls-loaded');
    }
    
    this.onHide = function () {
      unsubscribeFromImage();
    }
    
    this.onShow = function () {
      subscribeToImageIfVisible(wardrobe.outfits.getOutfit());
    }
    
    function formatUrls() {
      formatImageUrl('small_image');
      formatImageUrl('medium_image');
      formatImageUrl('large_image');
      formatTextUrl('permalink');
    }
    
    function formatTextUrl(key) {
      formatUrl(key, format.text(urls[key]));
    }
    
    function formatImageUrl(key) {
      formatUrl(key, format.image(urls[key], urls.permalink));
    }
    
    function formatUrl(key, url) {
      sharing_url_els[key].val(url);
    }
    
    wardrobe.image_subscriptions.bind('imageEnqueued', function (outfit) {
      if(outfit.id == current_shared_outfit.id) {
        log("Sharing thumbnail enqueued for outfit", outfit);
        WRAPPER.removeClass('thumbnail-loaded');
      }
    });
    
    wardrobe.image_subscriptions.bind('imageReady', function (outfit) {
      if(outfit.id == current_shared_outfit.id) {
        log("Sharing thumbnail ready for outfit", outfit);
        var src = outfit.image_versions.small + '?' + outfit.image_layers_hash;
        thumbnail_el.attr('src', src);
        WRAPPER.addClass('thumbnail-loaded');
        WRAPPER.addClass('thumbnail-available');
        unsubscribeFromImage(outfit);
      }
    });
    
    wardrobe.outfits.bind('updateSuccess', function (outfit) {
      if(sidebar_el.hasClass('sharing')) {
        subscribeToImage(outfit);
      }
    });
    
    wardrobe.outfits.bind('setOutfit', function (outfit) {
      log("Sharing sees the setOutfit signal, and will set", outfit);
      sharing.setOutfit(outfit);
    });
  }

  /* Saving */

  save_current_outfit_el.click(function () {
    wardrobe.outfits.update();
  });

  new_outfit_form_el.submit(function (e) {
    e.preventDefault();
    new_outfit_form_el.startLoading();
    wardrobe.outfits.create({starred: new_outfit_form_el.hasClass('starred'), name: new_outfit_name_el.val()});
  });

  new_outfit_form_el.find('div.outfit-star').click(function () {
    new_outfit_form_el.toggleClass('starred');
  });

  function saveErrorMessage(text) {
    save_error_el.text(text).notify();
  }

  wardrobe.outfits.bind('saveSuccess', function (outfit) {
    save_success_el.notify();
  });

  wardrobe.outfits.bind('createSuccess', function (outfit) {
    showOutfits();
    hideNewOutfitForm();
  });
  
  function shareComplete(outfit) {
    save_outfit_wrapper_el.stopLoading().addClass('shared-outfit');
    sharing.setOutfit(outfit);
    showSharing();
  }

  wardrobe.outfits.bind('shareSuccess', shareComplete);
  wardrobe.outfits.bind('shareSkipped', shareComplete);

  function clearSharedOutfit() {
    save_outfit_wrapper_el.removeClass('shared-outfit');
  }

  wardrobe.outfits.bind('updateClosetItems', clearSharedOutfit);
  wardrobe.outfits.bind('updateWornItems', clearSharedOutfit);
  wardrobe.outfits.bind('updatePetState', clearSharedOutfit);

  function saveFailure(outfit, response) {
    if(typeof response.full_error_messages !== 'undefined') {
      saveErrorMessage(response.full_error_messages.join(', '));
    } else {
      saveErrorMessage("Could not save outfit. Please try again.");
    }
    new_outfit_form_el.stopLoading();
    liForOutfit(outfit).stopLoading();
  }

  wardrobe.outfits.bind('saveFailure', saveFailure);
  wardrobe.outfits.bind('saveFailure', saveFailure)
  wardrobe.outfits.bind('shareFailure', function (outfit, response) {
    save_outfit_wrapper_el.stopLoading();
    saveFailure(outfit, response);
  });

  /* Error */

  wardrobe.outfits.bind('outfitNotFound', function () {
    outfit_not_found_el.notify();
  });
}

View.PetStateForm = function (wardrobe) {
  var INPUT_NAME = 'pet_state_id', form_query = '#pet-state-form',
    form = $(form_query),
    select = form.children('select');
  
  select.change(function (e) {
    var id = parseInt(select.children(':selected').val(), 10);
    wardrobe.outfits.setPetStateById(id);
  });

  function updatePetState(pet_state) {
    if(pet_state) {
      select.val(pet_state.id);
    }
  }

  wardrobe.outfits.bind('petTypeLoaded', function (pet_type) {
    var pet_states = pet_type.pet_states, i, id, option;
    select.children().remove();
    if(pet_states.length == 1) {
      form.addClass('hidden');
    } else {
      form.removeClass('hidden');
      for(var i = 0; i < pet_states.length; i++) {
        id = 'pet-state-button-' + i;
        option = $('<option/>', {
          value: pet_states[i].id,
          text: pet_states[i].gender_mood_description
        });
        option.appendTo(select);
      }
      updatePetState(wardrobe.outfits.getPetState());
    }
  });

  wardrobe.outfits.bind('updatePetState', updatePetState);
}

View.PetTypeForm = function (wardrobe) {
  var form = $('#pet-type-form'), dropdowns = {}, loaded = false;
  form.submit(function (e) {
    e.preventDefault();
    wardrobe.outfits.setPetTypeByColorAndSpecies(
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
    updatePetType(wardrobe.outfits.getPetType());
  });

  wardrobe.outfits.bind('updatePetType', updatePetType);

  wardrobe.outfits.bind('petTypeNotFound', function () {
    $('#pet-type-not-found').show('normal').delay(3000).hide('fast');
  });
}

View.PreviewAdapterForm = function (wardrobe) {
  var preview = wardrobe.views.Preview;
  var Konami=function(){var a={addEvent:function(b,c,d,e){if(b.addEventListener)b.addEventListener(c,d,false);else if(b.attachEvent){b["e"+c+d]=d;b[c+d]=function(){b["e"+c+d](window.event,e)};b.attachEvent("on"+c,b[c+d])}},input:"",pattern:"3838404037393739666513",load:function(b){this.addEvent(document,"keydown",function(c,d){if(d)a=d;a.input+=c?c.keyCode:event.keyCode;if(a.input.indexOf(a.pattern)!=-1){a.code(b);a.input=""}},this);this.iphone.load(b)},code:function(b){window.location=b},iphone:{start_x:0,start_y:0,stop_x:0,stop_y:0,tap:false,capture:false,keys:["UP","UP","DOWN","DOWN","LEFT","RIGHT","LEFT","RIGHT","TAP","TAP","TAP"],code:function(b){a.code(b)},load:function(b){a.addEvent(document,"touchmove",function(c){if(c.touches.length==1&&a.iphone.capture==true){c=c.touches[0];a.iphone.stop_x=c.pageX;a.iphone.stop_y=c.pageY;a.iphone.tap=false;a.iphone.capture=false;a.iphone.check_direction()}});a.addEvent(document,"touchend",function(){a.iphone.tap==true&&a.iphone.check_direction(b)},false);a.addEvent(document,"touchstart",function(c){a.iphone.start_x=c.changedTouches[0].pageX;a.iphone.start_y=c.changedTouches[0].pageY;a.iphone.tap=true;a.iphone.capture=true})},check_direction:function(b){x_magnitude=Math.abs(this.start_x-this.stop_x);y_magnitude=Math.abs(this.start_y-this.stop_y);x=this.start_x-this.stop_x<0?"RIGHT":"LEFT";y=this.start_y-this.stop_y<0?"DOWN":"UP";result=x_magnitude>y_magnitude?x:y;result=this.tap==true?"TAP":result;if(result==this.keys[0])this.keys=this.keys.slice(1,this.keys.length);this.keys.length==0&&this.code(b)}}};return a};
  konami = new Konami();
  konami.code = function () {
    preview.toggleAdapter();
  }
  konami.load();

  var modeWrapper = $('#preview-mode').addClass('flash-active');
  var modeOptions = $('#preview-mode-toggle li');
  function activate(el, modeOn, modeOff) {
    modeWrapper.removeClass(modeOff + '-active').addClass(modeOn + '-active');
    $(el).addClass('active');
  }

  var flashToggle = $('#preview-mode-flash').click(function () {
    activate(this, 'flash', 'image');
    preview.useSWFAdapter();
  });

  var imageToggle = $('#preview-mode-image').click(function () {
    activate(this, 'image', 'flash');
    preview.useImageAdapter();
  });

  if(preview.usingImageAdapter()) {
    activate(imageToggle, 'image', 'flash');
  }
}

View.ReportBrokenImage = function (wardrobe) {
  var link = $('#report-broken-image');
  var baseURL = link.attr('data-base-url');

  function updateLink() {
    var assets = wardrobe.outfits.getVisibleAssets();
    var url = baseURL + "?";

    for(var i = 0; i < assets.length; i++) {
      if(i > 0) url += "&";
      url += "asset_ids[" + assets[i].type + "][]=" + assets[i].id;
    }

    link.attr('href', url);
  }

  wardrobe.outfits.bind('updateWornItems', updateLink);
  wardrobe.outfits.bind('updateItemAssets', updateLink);
  wardrobe.outfits.bind('updatePetState', updateLink);
}

View.Search = function (wardrobe) {
  var form = $('form.item-search'),
    item_set = new Partial.ItemSet(wardrobe, '#preview-search-basic ul'),
    input_el = form.find('input[name=query]'),
    clear_el = $('#preview-search-form-clear'),
    error_el = $('#preview-search-form-error'),
    help_el = $('#preview-search-form-help'),
    loading_el = $('#preview-search-form-loading'),
    no_results_el = $('#preview-search-form-no-results'),
    no_results_span = no_results_el.children('span'),
    wrapper = $('#preview-search'),
    PAGINATION = {
      INNER_WINDOW: 4,
      OUTER_WINDOW: 1,
      EL_ID: '#preview-search-form-pagination',
      PER_PAGE: 21,
      TEMPLATE: $('#pagination-template')
    }, object_width = 112, last_request,
    current_query = "",
    advanced_form = $('#preview-search-advanced');

  PAGINATION.EL = $(PAGINATION.EL_ID);

  $(PAGINATION.EL_ID + ' a').live('click', function (e) {
    e.preventDefault();
    loadPage($(this).data('page'));
  });

  this.initialize = $.proxy(wardrobe.item_zone_sets, 'load');

  wardrobe.search.setPerPage(PAGINATION.PER_PAGE);

  function updatePerPage() {
    var new_per_page = Math.floor(wrapper.width() / object_width),
      offset, new_page;
    if(!$(document.body).hasClass('fullscreen')) new_per_page *= 4;
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
    wardrobe.search.setItemsByQuery(current_query, {offset: offset});
  }

  function loadPage(page) {
    wardrobe.search.setItemsByQuery(current_query, {page: page});
  }

  function stopLoading() {
    loading_el.stop(true, true).hide();
  }

  form.submit(function (e) {
    e.preventDefault();
    current_query = $(this).find('input[name=query]').val();
    wrapper.removeClass('advanced');
    loadPage(1);
  });

  advanced_form.submit(function(e) {
    e.preventDefault();
    current_query = {
      name: {
        require: $('#advanced-search-name-require').val(),
        exclude: $('#advanced-search-name-exclude').val()
      },
      nc: $('#advanced-search-nc').val(),
      occupies: $('#advanced-search-occupies').val(),
      restricts: $('#advanced-search-restricts').val(),
      species: $('#advanced-search-species').val(),
      owns: $('#advanced-search-owns').val(),
      wants: $('#advanced-search-wants').val()
    };
    wrapper.removeClass('advanced');
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
    if(wardrobe.search.request.query.length > 0) {
      if(!items.length) {
        no_results_el.show();
      }
    } else {
      help_el.show();
    }
    wrapper.toggleClass('has-results', items.length > 0);
    fit();
  });

  wardrobe.search.bind('updateRequest', function (request) {
    last_request = request;
    error_el.hide('fast');
    help_el.hide();
    no_results_el.hide();
    current_query = request.query || '';
    var human_query = typeof current_query === 'string' ? current_query : '';
    input_el.val(human_query);
    no_results_span.text(human_query);
    clear_el.toggle(!!request.query && request.query.length > 0);
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
    
    var pages = [];

    while(i <= total_pages) {
      if(subtract_left && i >= left_gap[0] && i < left_gap[1]) {
        pages.push('gap');
        i = left_gap[1];
      } else if(subtract_right && i >= right_gap[0] && i < right_gap[1]) {
        pages.push('gap');
        i = right_gap[1];
      } else {
        pages.push(i);
        i++;
      }
    }
    
    PAGINATION.EL.empty();
    PAGINATION.TEMPLATE.tmpl({
      current_page: current_page,
      total_pages: total_pages,
      pages: pages
    }).appendTo(PAGINATION.EL);
  });

  wardrobe.search.bind('error', function (error) {
    stopLoading();
    error_el.text(error).show('normal');
  });

  $('#preview-search-advanced-link, #preview-search-basic-link').click(function() {
    var fit = $('#preview').data('fit') || $.noop;
    wrapper.toggleClass('advanced');
    fit();
  });

  wardrobe.item_zone_sets.bind('update', function (item_zone_sets) {
    var selects = $('#advanced-search-occupies, #advanced-search-restricts');
    var sorted_item_zone_sets = item_zone_sets.slice(0);
    item_zone_sets.sort(function(a, b) {
      if (a.label < b.label) return -1;
      else if (a.label > b.label) return 1;
      else return 0;
    });
    item_zone_sets.forEach(function(set) {
      $('<option/>', {value: set.plainLabel, text: set.label}).
        appendTo(selects);
    });
  });
}

View.PrankColorMessage = function(wardrobe) {
  var el = $('#prank-color-message');
  var nameEls = el.find('.prank-color-message-name');
  var artistEls = el.find('.prank-color-message-artist');
  var colorsById = null;
  var petType = null;
  var petState = null;

  function updateMessage() {
    if (colorsById !== null && petType !== null && petState !== null) {
      var color = colorsById[petType.color_id];
      if (color.prank) {
        nameEls.text(color.unfunny_name);
        artistEls.text(petState.artistName);
        if (petState.artistUrl === null) {
          artistEls.removeAttr('href');
        } else {
          artistEls.attr('href', petState.artistUrl);
        }
        el.show();
      } else {
        el.hide();
      }
    }
  }

  wardrobe.pet_attributes.bind('update', function(attributes) {
    colorsById = {};
    attributes.color.forEach(function(color) {
      colorsById[color.id] = color;
    });
    updateMessage();
  });

  wardrobe.outfits.bind('updatePetType', function(newPetType) {
    petType = newPetType;
    updateMessage();
  });

  wardrobe.outfits.bind('updatePetState', function(newPetState) {
    petState = newPetState;
    updateMessage();
  });
}

var userbar_sessions_link = $('#userbar a:last');
var userbar_message_el = $('#userbar-session-message').prependTo('#userbar');

userbar_sessions_link.hover(function () {
  userbar_message_el.stop().fadeTo('normal', .5);
}, function () {
  userbar_message_el.stop().fadeOut('fast');
});

var localeForm = $('#locale-form');
localeForm.submit(function (e) {
  var fullPath = document.location.pathname + document.location.search +
                 document.location.hash;
  localeForm.find('input[name=return_to]').val(fullPath);
});

$.ajaxSetup({
  error: function (xhr) {
    $.jGrowl("There was an error loading that last resource. Oops. Please try again!");
  }
});

main_wardrobe = new Wardrobe();
main_wardrobe.registerViews(View);
main_wardrobe.initialize();

var TIME_TO_DONATION_REQUEST_IN_MINUTES = 10;
var donationRequestEl = $('#preview-sidebar-donation-request');

donationRequestEl.find('a').click(function(e) {
  donationRequestEl.slideUp(250);
  var response = this.id == 'preview-sidebar-donation-request-no-thanks' ? 0 : 1;
  if(!response) { // href is #
    e.preventDefault();
  }
  var expiryDate = new Date();
  expiryDate.setTime(expiryDate.getTime() + 7*24*60*60*1000); // one week from now
  document.cookie = "previewSidebarDonationResponse=" + response + "; expires=" + expiryDate.toGMTString();
});

if(document.cookie.indexOf('previewSidebarDonationResponse') == -1) {
  setTimeout(function () {
    donationRequestEl.slideDown(1000);
  }, TIME_TO_DONATION_REQUEST_IN_MINUTES * 60 * 1000);
}

