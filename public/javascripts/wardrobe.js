var SHORT_URL_HOST = 'http://bit.ly/';

window.log = window.SWFLog = $.noop;

function arraysMatch(array1, array2) {
  // http://www.breakingpar.com/bkp/home.nsf/0/87256B280015193F87256BFB0077DFFD
  var temp;
  if(!$.isArray(array1)|| !$.isArray(array2)) {
    return array1 == array2;
  }
  temp = [];
  if ( (!array1[0]) || (!array2[0]) ) {
    return false;
  }
  if (array1.length != array2.length) {
    return false;
  }
  for (var i=0; i<array1.length; i++) {
    key = (typeof array1[i]) + "~" + array1[i];
    if (temp[key]) { temp[key]++; } else { temp[key] = 1; }
  }
  for (var i=0; i<array2.length; i++) {
    key = (typeof array2[i]) + "~" + array2[i];
    if (temp[key]) {
      if (temp[key] == 0) { return false; } else { temp[key]--; }
    } else {
      return false;
    }
  }
  return true;
}

Array.prototype.map = function (property) {
  return $.map(this, function (element) {
    return element[property];
  });
}

function DeepObject() {}

DeepObject.prototype.deepGet = function () {
  var scope = this, i;
  $.each(arguments, function () {
    scope = scope[this];
    if(typeof scope == 'undefined') return false;
  });
  return scope;
}

DeepObject.prototype.deepSet = function () {
  var pop = $.proxy(Array.prototype.pop, 'apply'),
    value = pop(arguments),
    final_key = pop(arguments),
    scope = this;
  $.each(arguments, function () {
    if(typeof scope[this] == 'undefined') {
      scope[this] = {};
    }
    scope = scope[this];
  });
  scope[final_key] = value;
}

function Wardrobe() {
  var wardrobe = this, BiologyAsset, ItemAsset;
  
  /*
  *
  * Models
  *
  */
  
  function determineRestrictedZones() {
    var i, zone;
    this.restricted_zones = [];
    while((zone = this.zones_restrict.indexOf(1, zone) + 1) != 0) {
      this.restricted_zones.push(zone);
    }
  }
  
  function Asset(data) {
    var asset = this;
    for(var key in data) {
      if(data.hasOwnProperty(key)) {
        asset[key] = data[key];
      }
    }
  }
  
  function BiologyAsset(data) {
    Asset.apply(this, [data]);
    determineRestrictedZones.apply(this);
  }
  
  function ItemAsset(data) {
    Asset.apply(this, [data]);
  }
  
  function Item(id) {
    var item = this;
    this.id = id;
    this.assets_by_body_id = {};
    this.load_started = false;
    this.loaded = false;
    
    this.getAssetsFitting = function (pet_type) {
      return this.assets_by_body_id[pet_type.body_id] || [];
    }
    
    this.hasAssetsFitting = function (pet_type) {
      return typeof item.assets_by_body_id[pet_type.body_id] != 'undefined' &&
        item.assets_by_body_id[pet_type.body_id].length > 0;
    }
    
    this.couldNotLoadAssetsFitting = function (pet_type) {
      return typeof item.assets_by_body_id[pet_type.body_id] != 'undefined' &&
        item.assets_by_body_id[pet_type.body_id].length == 0;
    }
    
    this.update = function (data) {
      for(var key in data) {
        if(data.hasOwnProperty(key) && key != 'id') { // do not replace ID with string
          item[key] = data[key];
        }
      }
      determineRestrictedZones.apply(this);
      this.loaded = true;
    }
    
    Item.cache[id] = this;
  }
  
  Item.find = function (id) {
    var item = Item.cache[id];
    if(!item) {
      item = new Item(id);
    }
    return item;
  }
  
  var item_load_callbacks = [];
  
  Item.loadByIds = function (ids, success) {
    var ids_to_load = [], ids_not_loaded = [], items = $.map(ids, function (id) {
      var item = Item.find(id);
      if(!item.load_started) {
        ids_to_load.push(id);
        item.load_started = true;
      }
      if(!item.loaded) {
        ids_not_loaded.push(id);
      }
      return item;
    });
    if(ids_to_load.length) {
      $.getJSON('/items.json', {ids: ids_to_load}, function (data) {
        var set, set_items, set_ids, set_callback, run_callback, ids_from_data = [];
        $.each(data, function () {
          ids_from_data.push(+this.id);
          Item.find(this.id).update(this);
        });
        for(var i = 0; i < item_load_callbacks.length; i++) {
          set = item_load_callbacks[i];
          set_items = set[0];
          set_ids = set[1];
          set_callback = set[2];
          run_callback = true;
          for(var j = 0; j < set_ids.length; j++) {
            if($.inArray(set_ids[j], ids_from_data) == -1) {
              run_callback = false;
              break;
            }
          }
          if(run_callback) set_callback(set_items);
        }
        success(items);
      });
    } else if(ids_not_loaded.length) {
      item_load_callbacks.push([items, ids_not_loaded, success]);
    } else {
      success(items);
    }
    return items;
  }
  
  Item.PER_PAGE = 21;
  
  Item.loadByQuery = function (query, offset, success, error) {
    var page = Math.round(offset / Item.PER_PAGE) + 1;
    $.getJSON('/items.json', {q: query, per_page: Item.PER_PAGE, page: page}, function (data) {
      var items = [], item, item_data;
      if(data.items) {
        for(var i = 0; i < data.items.length; i++) {
          item_data = data.items[i];
          item = Item.find(item_data.id);
          item.update(item_data);
          items.push(item);
        }
        success(items, data.total_pages, page);
      } else if(data.error) {
        error(data.error);
      }
    });
  }
  
  Item.cache = {};
  
  function ItemZoneSet(name) {
    this.name = name;
  }
  
  ItemZoneSet.loadAll = function (success) {
    $.getJSON('/item_zone_sets.json', function (data) {
      for(var i = 0, l = data.length; i < l; i++) {
        ItemZoneSet.all.push(new ItemZoneSet(data[i]));
      }
      success(ItemZoneSet.all);
    });
  }
  
  ItemZoneSet.all = [];
  
  function PetAttribute() {}
  
  PetAttribute.loadAll = function (success) {
    $.getJSON('/pet_attributes.json', function (data) {
      success(data);
    });
  }
  
  function PetState(id) {
    var pet_state = this, loaded = false;
    
    this.id = id;
    this.assets = [];
    
    this.loadAssets = function (success) {
      var params;
      if(loaded) {
        success(pet_state);
      } else {
        $.getJSON('/pet_states/' + pet_state.id + '/swf_assets.json',
        function (data) {
          pet_state.assets = $.map(data, function (obj) { return new BiologyAsset(obj) });
          loaded = true;
          success(pet_state);
        });
      }
    }
    
    PetState.cache[id] = this;
  }
  
  PetState.find = function (id) {
    var pet_state = PetState.cache[id];
    if(!pet_state) {
      pet_state = new PetState(id);
    }
    return pet_state;
  }
  
  PetState.cache = {};
  
  function PetType() {
    var pet_type = this;
    
    this.loaded = false;
    this.pet_states = [];

    this.load = function (success, error) {
      if(pet_type.loaded) {
        success(pet_type);
      } else {
        $.getJSON('/species/' + pet_type.species_id + '/color/' + pet_type.color_id + '/pet_type.json', {
          'for': 'wardrobe'
        }, function (data) {
          if(data) {
            for(var key in data) {
              if(data.hasOwnProperty(key)) {
                pet_type[key] = data[key];
              }
            }
            for(var i = 0; i < pet_type.pet_state_ids.length; i++) {
              pet_type.pet_states.push(PetState.find(pet_type.pet_state_ids[i]));
            }
            PetType.cache_by_color_and_species.deepSet(
              pet_type.color_id,
              pet_type.species_id,
              pet_type
            );
            pet_type.loaded = true;
            success(pet_type);
          } else {
            error(pet_type);
          }
        });
      }
    }
    
    this.loadItemAssets = function (item_ids, success) {
      var item_ids_needed = [];
      for(var i = 0; i < item_ids.length; i++) {
        var id = item_ids[i], item = Item.find(id);
        if(!item.hasAssetsFitting(pet_type)) item_ids_needed.push(id);
      }
      if(item_ids_needed.length) {
        $.getJSON('/bodies/' + pet_type.body_id + '/swf_assets.json', {
          item_ids: item_ids_needed
        }, function (data) {
          var item;
          $.each(data, function () {
            var item = Item.find(this.parent_id),
              asset = new ItemAsset(this);
            if(typeof item.assets_by_body_id[pet_type.body_id] == 'undefined') {
              item.assets_by_body_id[pet_type.body_id] = [];
            }
            item.assets_by_body_id[pet_type.body_id].push(asset);
          });
          for(var i = 0, l = item_ids.length; i < l; i++) {
            item = Item.find(item_ids[i]);
            if(!item.hasAssetsFitting(pet_type)) {
              item.assets_by_body_id[pet_type.body_id] = [];
            }
          }
          success();
        });
      } else {
        success();
      }
    }
    
    this.toString = function () {
      return 'PetType{color_id: ' + this.color_id + ', species_id: ' +
        this.species_id + '}';
    }
    
    this.ownsPetState = function (pet_state) {
      for(var i = 0; i < this.pet_states.length; i++) {
        if(this.pet_states[i] == pet_state) return true;
      }
      return false;
    }
  }
  
  PetType.cache_by_color_and_species = new DeepObject();
  
  PetType.findOrCreateByColorAndSpecies = function (color_id, species_id) {
    var pet_type = PetType.cache_by_color_and_species.deepGet(color_id, species_id);
    if(!pet_type) {
      pet_type = new PetType();
      pet_type.color_id = color_id;
      pet_type.species_id = species_id;
    }
    return pet_type;
  }
  
  function SwfAsset() {}
  
  /*
  *
  * Controllers
  *
  */
  
  function Controller() {
    var controller = this;
    this.events = {};
    
    this.bind = function (event, callback) {
      if(typeof this.events[event] == 'undefined') {
        this.events[event] = [];
      }
      this.events[event].push(callback);
    }
    
    this.events.trigger = function (event) {
      var subarguments;
      if(controller.events[event]) {
        subarguments = Array.prototype.slice.apply(arguments, [1]);
        $.each(controller.events[event], function () {
          this.apply(controller, subarguments);
        });
      }
    }
  }
  
  Controller.all = {};
  
  Controller.all.Outfit = function OutfitController() {
    var outfit = this, previous_pet_type, item_ids = [];
    
    this.items = [];
    
    function getRestrictedZones() {
      // note: may contain duplicates - loop through assets, not these, for
      // best performance
      var restricted_zones = [],
        restrictors = outfit.items.concat(outfit.pet_state.assets);
      $.each(restrictors, function () {
        restricted_zones = restricted_zones.concat(this.restricted_zones);
      });
      return restricted_zones;
    }
    
    function hasItem(item) {
      return $.inArray(item, outfit.items) != -1;
    }
    
    function itemAssetsOnLoad(added_item) {
      var item_zones, item_zones_length, existing_item, existing_item_zones, passed,
        new_items = [], new_item_ids = [];
      if(added_item) {
        // now that we've loaded, check for conflicts on the added item
        item_zones = added_item.getAssetsFitting(outfit.pet_type).map('zone_id');
        item_zones_length = item_zones.length;
        for(var i = 0; i < outfit.items.length; i++) {
          existing_item = outfit.items[i];
          existing_item_zones = existing_item.getAssetsFitting(outfit.pet_type).map('zone_id');
          passed = true;
          if(existing_item != added_item) {
            for(var j = 0; j < item_zones_length; j++) {
              if($.inArray(item_zones[j], existing_item_zones) != -1) {
                passed = false;
                break;
              }
            }
          }
          if(passed) {
            new_items.push(existing_item);
            new_item_ids.push(existing_item.id);
          }
        }
        outfit.items = new_items;
        item_ids = new_item_ids;
        outfit.events.trigger('updateItems', outfit.items);
      }
      outfit.events.trigger('updateItemAssets');
    }
    
    function itemsOnLoad(items) {
      outfit.events.trigger('updateItems', items);
    }
    
    function petStateOnLoad(pet_state) {
      outfit.events.trigger('updatePetState', pet_state);
    }
    
    function petTypeOnLoad(pet_type) {
      if(!outfit.pet_state || !pet_type.ownsPetState(outfit.pet_state)) {
        outfit.setPetStateById();
      }
      outfit.events.trigger('petTypeLoaded', pet_type);
      updateItemAssets();
    }
    
    function petTypeOnError(pet_type) {
      outfit.events.trigger('petTypeNotFound', pet_type);
    }
    
    function updateItemAssets(added_item) {
      if(outfit.pet_type && outfit.pet_type.loaded && item_ids.length) {
        outfit.pet_type.loadItemAssets(item_ids, function () {
          itemAssetsOnLoad(added_item)
        });
      }
    }
    
    this.addItem = function (item) {
      if(!hasItem(item)) {
        this.items.push(item);
        item_ids.push(item.id);
        updateItemAssets(item);
        outfit.events.trigger('updateItems', this.items);
      }
    }
    
    this.getVisibleAssets = function () {
      var assets = this.pet_state.assets, restricted_zones = getRestrictedZones(),
        visible_assets = [];
      for(var i = 0; i < outfit.items.length; i++) {
        assets = assets.concat(outfit.items[i].getAssetsFitting(outfit.pet_type));
      }
      $.each(assets, function () {
        if($.inArray(this.zone_id, restricted_zones) == -1) {
          visible_assets.push(this);
        }
      });
      return visible_assets;
    }
    
    this.removeItem = function (item) {
      var i = $.inArray(item, this.items), id_i;
      if(i != -1) {
        this.items.splice(i, 1);
        id_i = $.inArray(item.id, item_ids);
        item_ids.splice(id_i, 1);
        outfit.events.trigger('updateItems', this.items);
      }
    }
    
    this.setPetStateById = function (id) {
      if(!id && this.pet_type) {
        id = this.pet_type.pet_state_ids[0];
      }
      if(id) {
        this.pet_state = PetState.find(id);
        this.pet_state.loadAssets(petStateOnLoad);
      }
    }
    
    this.setPetTypeByColorAndSpecies = function (color_id, species_id) {
      this.pet_type = PetType.findOrCreateByColorAndSpecies(color_id, species_id);
      outfit.events.trigger('updatePetType', this.pet_type);
      this.pet_type.load(petTypeOnLoad, petTypeOnError);
    }
    
    this.setItemsByIds = function (ids) {
      if(ids) item_ids = ids;
      if(ids && ids.length) {
        this.items = Item.loadByIds(ids, itemsOnLoad);
      } else {
        this.items = [];
        itemsOnLoad(this.items);
      }
      updateItemAssets();
    }
  }
  
  Controller.all.Closet = function ClosetController() {
    // FIXME: a lot of duplication from outfit controller
    var closet = this, item_ids = [];
    this.items = [];
    
    function hasItem(item) {
      return $.inArray(item, closet.items) != -1;
    }
    
    function itemsOnLoad(items) {
      closet.events.trigger('updateItems', items);
    }
    
    this.addItem = function (item) {
      if(!hasItem(item)) {
        this.items.push(item);
        item_ids.push(item.id);
        closet.events.trigger('updateItems', this.items);
      }
    }
    
    this.removeItem = function (item) {
      var i = $.inArray(item, this.items), id_i;
      if(i != -1) {
        this.items.splice(i, 1);
        id_i = $.inArray(item.id, item_ids);
        item_ids.splice(id_i, 1);
        closet.events.trigger('updateItems', this.items);
      }
    }
    
    this.setItemsByIds = function (ids) {
      if(ids && ids.length) {
        item_ids = ids;
        this.items = Item.loadByIds(ids, itemsOnLoad);
      } else {
        item_ids = ids;
        this.items = [];
        itemsOnLoad(this.items);
      }
    }
  }
  
  Controller.all.BasePet = function BasePetController() {
    var base_pet = this;
    
    this.setName = function (name) {
      base_pet.name = name;
      base_pet.events.trigger('updateName', name);
    }
  }
  
  Controller.all.PetAttributes = function PetAttributesController() {
    var pet_attributes = this;
    
    function onLoad(attributes) {
      pet_attributes.events.trigger('update', attributes);
    }
    
    this.load = function () {
      PetAttribute.loadAll(onLoad);
    }
  }
  
  Controller.all.ItemZoneSets = function ItemZoneSetsController() {
    var item_zone_sets = this;
    
    function onLoad(sets) {
      item_zone_sets.events.trigger('update', sets);
    }
    
    this.load = function () {
      ItemZoneSet.loadAll(onLoad);
    }
  }
  
  Controller.all.Search = function SearchController() {
    var search = this;
    
    this.request = {};
    
    function itemsOnLoad(items, total_pages, page) {
      search.events.trigger('updateItems', items);
      search.events.trigger('updatePagination', page, total_pages);
    }
    
    function itemsOnError(error) {
      search.events.trigger('error', error);
    }
    
    this.setItemsByQuery = function (query, where) {
      var offset = (typeof where.offset != 'undefined') ? where.offset : (Item.PER_PAGE * (where.page - 1));
      search.request = {
        query: query,
        offset: offset
      };
      search.events.trigger('updateRequest', search.request);
      if(query) {
        Item.loadByQuery(query, offset, itemsOnLoad, itemsOnError);
        search.events.trigger('startRequest');
      } else {
        search.events.trigger('updateItems', []);
        search.events.trigger('updatePagination', 0, 0);
      }
    }
    
    this.setPerPage = function (per_page) {
      Item.PER_PAGE = per_page;
    }
  }

  var underscored_name;

  for(var name in Controller.all) {
    if(Controller.all.hasOwnProperty(name)) {
      // underscoring translated from
      // http://api.rubyonrails.org/classes/ActiveSupport/Inflector.html#M000710
      underscored_name = name.replace(/([A-Z]+)([A-Z][a-z])/g, '$1_$2').
        replace(/([a-z\d])([A-Z])/g,'$1_$2').toLowerCase();
      wardrobe[underscored_name] = new Controller.all[name];
      Controller.apply(wardrobe[underscored_name]);
    }
  }
  
  this.initialize = function () {
    var view;
    for(var name in wardrobe.views) {
      if(wardrobe.views.hasOwnProperty(name)) {
        view = wardrobe.views[name];
        if(typeof view.initialize == 'function') {
          view.initialize();
        }
      }
    }
  }
  
  this.registerViews = function (views) {
    wardrobe.views = {};
    $.each(views, function (name) {
      wardrobe.views[name] = new this(wardrobe);
    });
  }
}

Wardrobe.StandardPreview = {
  views_by_swf_id: {}
};

Wardrobe.getStandardView = function (options) {
  var StandardView = {};
  
  function requireKeys() {
    var key, key_stack = [], scope = options;
    for(var i = 0; i < arguments.length; i++) {
      key = arguments[i];
      key_stack.push(key);
      scope = scope[key];
      if(typeof scope == "undefined") {
        throw "Options for Wardrobe.getStandardView must include " + key_stack.join(".");
      }
    }
  }
  
  requireKeys('Preview', 'swf_url');
  requireKeys('Preview', 'wrapper');
  requireKeys('Preview', 'placeholder');
  
  if(document.location.search.substr(0, 6) == '?debug') {
    StandardView.Console = function (wardrobe) {
      if(typeof console != 'undefined' && typeof console.log == 'function') {
        window.log = $.proxy(console, 'log');
      }
      
      this.initialize = function () {
        log('Welcome to the Wardrobe!');
      }
      
      var outfit_events = ['updateItems', 'updateItemAssets', 'updatePetType', 'updatePetState'];
      for(var i = 0; i < outfit_events.length; i++) {
        (function (event) {
          wardrobe.outfit.bind(event, function (obj) {
            log(event, obj);
          });
        })(outfit_events[i]);
      }
      
      wardrobe.outfit.bind('petTypeNotFound', function (pet_type) {
        log(pet_type.toString() + ' not found');
      });
    }
  }

  StandardView.Preview = function (wardrobe) {
    var preview_el = $(options.Preview.wrapper),
      preview_swf_placeholder = $(options.Preview.placeholder),
      preview_swf_id = preview_swf_placeholder.attr('id'),
      preview_swf,
      update_pending_flash = false;
    
    swfobject.embedSWF(
      options.Preview.swf_url,
      preview_swf_id,
      '100%',
      '100%',
      '9',
      '/assets/js/swfobject/expressInstall.swf',
      {'id': preview_swf_id},
      {'wmode': 'transparent'}
    );
    
    Wardrobe.StandardPreview.views_by_swf_id[preview_swf_id] = this;
    console.log(Wardrobe.StandardPreview.views_by_swf_id);
    
    this.previewSWFIsReady = function () {
      preview_swf = document.getElementById(preview_swf_id);
      if(update_pending_flash) {
        update_pending_flash = false;
        updateAssets();
      }
    }
    
    function updateAssets() {
      var assets, assets_for_swf;
      if(update_pending_flash) return false;
      if(preview_swf && preview_swf.setAssets) {
        assets = wardrobe.outfit.getVisibleAssets();
        preview_swf.setAssets(assets);
      } else {
        update_pending_flash = true;
      }
    }
    
    wardrobe.outfit.bind('updateItems', updateAssets);
    wardrobe.outfit.bind('updateItemAssets', updateAssets);
    wardrobe.outfit.bind('updatePetState', updateAssets);
  }
  
  window.previewSWFIsReady = function (id) {
    Wardrobe.StandardPreview.views_by_swf_id[id].previewSWFIsReady();
  }
  
  return StandardView;
}
