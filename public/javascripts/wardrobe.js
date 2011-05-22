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

  function Asset(newData) {
    var asset = this;

    this.imageURL = function (size) {
      return Wardrobe.IMAGE_CONFIG.base_url + this.s3_path + "/" + size[0] + "x" + size[1] + ".png";
    }

    this.update = function (data) {
      for(var key in data) {
        if(data.hasOwnProperty(key)) {
          asset[key] = data[key];
        }
      }
    }

    this.update(newData);
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

    function getNameForSlug() {
      return item.name.toLowerCase().replace(/ /g, '-').replace(/[^a-z0-9\-]/i, '');
    }

    function getSlug() {
      var slug = item.id.toString();
      if(this.hasOwnProperty('name')) {
        slug += '-' + getNameForSlug();
      }
      return slug;
    }

    this.getURL = function() {
      return "/items/" + getSlug();
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

  function Outfit(data) {
    var outfit = this, previous_pet_type, worn_item_ids = [],
      closet_item_ids = [], new_record = true;

    this.setWornAndUnwornItemIds = function (new_ids) {
      this.worn_and_unworn_item_ids = new_ids;
      worn_item_ids = new_ids.worn;
      closet_item_ids = new_ids.unworn.concat(new_ids.worn);
    }

    if(typeof data != 'undefined') {
      this.color_id = data.color_id;
      this.id = data.id;
      this.name = data.name;
      this.pet_state_id = data.pet_state_id;
      this.starred = data.starred;
      this.species_id = data.species_id;
      this.setWornAndUnwornItemIds(data.worn_and_unworn_item_ids);
      new_record = false;
    }

    this.closet_items = [];
    this.worn_items = [];

    this.anonymous = false;

    this.getWornItemIds = function () { // TODO just expose the worn_item_ids
      return worn_item_ids;
    }

    this.getClosetItemIds = function () { // TODO just expose the closet_item_ids
      return closet_item_ids;
    }

    function getAttributes() {
      var outfit_data = {};
      outfit_data.name = outfit.name;
      outfit_data.starred = outfit.starred;
      outfit_data.worn_and_unworn_item_ids = outfit.getWornAndUnwornItemIds();
      if(outfit.pet_state) outfit_data.pet_state_id = outfit.pet_state.id;
      outfit_data.anonymous = outfit.anonymous;
      return outfit_data;
    }

    function getRestrictedZones() {
      // note: may contain duplicates - loop through assets, not these, for
      // best performance
      var restricted_zones = [],
        restrictors = outfit.worn_items;
      if(outfit.pet_state) restrictors = restrictors.concat(outfit.pet_state.assets);
      $.each(restrictors, function () {
        restricted_zones = restricted_zones.concat(this.restricted_zones);
      });
      return restricted_zones;
    }

    function hasItemInCloset(item) {
      return $.inArray(item, outfit.closet_items) != -1;
    }

    function isWearingItem(item) {
      return $.inArray(item, outfit.worn_items) != -1;
    }

    function itemAssetsOnLoad(added_item, updateItemsCallback, updateItemAssetsCallback) {
      var item_zones, item_zones_length, existing_item, existing_item_zones, passed,
        new_items = [], new_worn_item_ids = [];
      if(added_item) {
        // now that we've loaded, check for conflicts on the added item
        item_zones = added_item.getAssetsFitting(outfit.pet_type).map('zone_id');
        item_zones_length = item_zones.length;
        for(var i = 0; i < outfit.worn_items.length; i++) {
          existing_item = outfit.worn_items[i];
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
            new_worn_item_ids.push(existing_item.id);
          }
        }
        outfit.worn_items = new_items;
        worn_item_ids = new_worn_item_ids;
        updateItemsCallback(outfit.worn_items);
      }
      updateItemAssetsCallback();
    }

    function petTypeOnLoad(pet_type, petTypeLoadedCallback, updatePetStateCallback, updateItemsCallback, updateItemAssetsCallback) {
      if(!outfit.pet_state || !pet_type.ownsPetState(outfit.pet_state)) {
        outfit.setPetStateById(null, updatePetStateCallback);
      }
      petTypeLoadedCallback(pet_type);
      updateItemAssets(null, updateItemsCallback, updateItemAssetsCallback);
    }

    function updateItemAssets(added_item, updateItemsCallback, updateItemAssetsCallback) {
      if(outfit.pet_type && outfit.pet_type.loaded && worn_item_ids.length) {
        outfit.pet_type.loadItemAssets(worn_item_ids, function () {
          itemAssetsOnLoad(added_item, updateItemsCallback, updateItemAssetsCallback)
        });
      }
    }

    function sendUpdate(outfit_data, success, failure) {
      $.ajax({
        url: '/outfits/' + outfit.id,
        type: 'post',
        data: {'_method': 'put', outfit: outfit_data},
        success: function () {
          Outfit.cache[outfit.id] = outfit;
          success(outfit);
        },
        error: function (xhr) {
          if(typeof failure !== 'undefined') {
            failure(outfit, $.parseJSON(xhr.responseText));
          }
        }
      });
    }

    this.closetItem = function (item, updateClosetItemsCallback) {
      if(!hasItemInCloset(item)) {
        this.closet_items.push(item);
        closet_item_ids.push(item.id);
        updateClosetItemsCallback(this.closet_items);
      }
    }

    this.getPetStateId = function () {
      if(typeof outfit.pet_state_id === 'undefined') {
        outfit.pet_state_id = outfit.pet_state.id;
      }
      return outfit.pet_state_id;
    }

    this.getVisibleAssets = function () {
      var assets, restricted_zones = getRestrictedZones(),
        visible_assets = [];
      assets = this.pet_state ? this.pet_state.assets : [];
      for(var i = 0; i < outfit.worn_items.length; i++) {
        assets = assets.concat(outfit.worn_items[i].getAssetsFitting(outfit.pet_type));
      }
      $.each(assets, function () {
        if($.inArray(this.zone_id, restricted_zones) == -1) {
          visible_assets.push(this);
        }
      });
      return visible_assets;
    }

    this.rename = function (new_name, success, failure) {
      this.updateAttributes({name: new_name}, success, failure);
    }

    this.setClosetItemsByIds = function (ids, updateItemsCallback) {
      if(ids) closet_item_ids = ids;
      if(ids && ids.length) {
        Item.loadByIds(ids, function (items) {
          outfit.closet_items = items;
          updateItemsCallback(items);
        });
      } else {
        this.closet_items = [];
        updateItemsCallback(this.closet_items);
      }
    }

    this.setPetStateById = function (id, petStateOnLoad) {
      if(!id && this.pet_type) {
        id = this.pet_type.pet_state_ids[0];
      }
      if(id) {
        this.pet_state = PetState.find(id);
        this.pet_state_id = id;
        this.pet_state.loadAssets(petStateOnLoad);
      }
    }

    this.setPetTypeByColorAndSpecies = function (color_id, species_id, updatePetTypeCallback, petTypeLoadedCallback, petTypeNotFoundCallback, updatePetStateCallback, updateItemsCallback, updateItemAssetsCallback) {
      this.pet_type = PetType.findOrCreateByColorAndSpecies(color_id, species_id);
      this.color_id = color_id;
      this.species_id = species_id;
      updatePetTypeCallback(this.pet_type);
      this.pet_type.load(function (pet_type) { petTypeOnLoad(pet_type, petTypeLoadedCallback, updatePetStateCallback, updateItemsCallback, updateItemAssetsCallback) }, petTypeNotFoundCallback);
    }

    this.setWornItemsByIds = function (ids, updateItemsCallback, updateItemAssetsCallback) {
      if(ids) worn_item_ids = ids;
      if(ids && ids.length) {
        this.worn_items = Item.loadByIds(ids, updateItemsCallback);
      } else {
        this.worn_items = [];
        updateItemsCallback(this.worn_items);
      }
      updateItemAssets(null, updateItemsCallback, updateItemAssetsCallback);
    }

    this.toggleStar = function (success) {
      this.updateAttributes({starred: !outfit.starred}, success);
    }

    this.unclosetItem = function (item, updateClosetItemsCallback, updateWornItemsCallback) {
      var i = $.inArray(item, this.closet_items), id_i;
      if(i != -1) {
        this.closet_items.splice(i, 1);
        id_i = $.inArray(item.id, closet_item_ids);
        closet_item_ids.splice(id_i, 1);
        updateClosetItemsCallback(this.closet_items);
        this.unwearItem(item, updateWornItemsCallback);
      }
    }

    this.unwearItem = function (item, updateWornItemsCallback) {
      var i = $.inArray(item, this.worn_items), id_i;
      if(i != -1) {
        this.worn_items.splice(i, 1);
        id_i = $.inArray(item.id, worn_item_ids);
        worn_item_ids.splice(id_i, 1);
        updateWornItemsCallback(this.worn_items);
      }
    }

    this.update = function (success, failure) {
      sendUpdate(getAttributes(), success, failure);
    }

    this.wearItem = function (item, updateWornItemsCallback, updateClosetItemsCallback, updateItemAssetsCallback) {
      if(!isWearingItem(item)) {
        this.worn_items.push(item);
        worn_item_ids.push(item.id);
        this.closetItem(item, updateClosetItemsCallback);
        if(updateItemAssetsCallback) {
          updateItemAssets(item, updateWornItemsCallback, updateItemAssetsCallback);
        }
        updateWornItemsCallback(this.worn_items);
      }
    }

    this.getWornAndUnwornItemIds = function () {
      var unworn_item_ids = [], id;
      for(var i = 0; i < closet_item_ids.length; i++) {
        id = closet_item_ids[i];
        if($.inArray(id, worn_item_ids) === -1) {
          unworn_item_ids.push(id);
        }
      }
      outfit.worn_and_unworn_item_ids = {worn: worn_item_ids, unworn: unworn_item_ids};
      return outfit.worn_and_unworn_item_ids;
    }

    this.clone = function () {
      var new_outfit = new Outfit;
      new_outfit.cloneAttributesFrom(outfit);
      new_outfit.id = outfit.id;
      new_outfit.name = outfit.name;
      new_outfit.starred = outfit.starred;
      return new_outfit;
    }

    this.cloneAttributesFrom = function (base_outfit) {
      var base_ids = base_outfit.getWornAndUnwornItemIds(),
        new_ids = {};
      outfit.color_id = base_outfit.color_id
      outfit.species_id = base_outfit.species_id;
      outfit.pet_state_id = base_outfit.getPetStateId();
      outfit.pet_state = base_outfit.pet_state;
      outfit.pet_type = base_outfit.pet_type;
      outfit.closet_items = base_outfit.closet_items.slice(0);
      outfit.worn_items = base_outfit.worn_items.slice(0);
      new_ids.worn = base_ids.worn.slice(0);
      new_ids.unworn = base_ids.unworn.slice(0);
      outfit.setWornAndUnwornItemIds(new_ids);
    }

    this.destroy = function (success) {
      $.ajax({
        url: '/outfits/' + outfit.id + '.json',
        type: 'post',
        data: {'_method': 'delete'},
        success: function () { success(outfit) }
      });
    }

    this.create = function (success, error) {
      $.ajax({
        url: '/outfits',
        type: 'post',
        data: {outfit: getAttributes()},
        success: function (data) {
          new_record = false;
          outfit.id = data;
          Outfit.cache[data] = outfit;
          success(outfit);
        },
        error: function (xhr) {
          error(outfit, $.parseJSON(xhr.responseText));
        }
      });
    }

    this.updateAttributes = function (attributes, success, failure) {
      var outfit_data = {};
      for(var key in attributes) {
        if(attributes.hasOwnProperty(key)) {
          outfit_data[key] = outfit[key] = attributes[key];
        }
      }
      sendUpdate(outfit_data, success, failure);
    }
  }

  Outfit.cache = {};

  Outfit.find = function (id, callback) {
    if(typeof Outfit.cache[id] !== 'undefined') {
      callback(Outfit.cache[id]);
    } else {
      $.ajax({
        url: '/outfits/' + id + '.json',
        success: function (data) {
          var outfit = new Outfit(data);
          Outfit.cache[id] = outfit;
          callback(outfit);
        },
        error: function () {
          callback(null);
        }
      });
    }
  }

  Outfit.loadForCurrentUser = function (success) {
    var outfits = [];
    $.getJSON('/users/current-user/outfits.json', function (data) {
      var outfit_data, outfit, i;
      for(var i = 0; i < data.length; i++) {
        outfit_data = data[i];
        outfit = new Outfit(outfit_data);
        outfits.push(outfit);
        Outfit.cache[outfit_data.id] = outfit;
      }
      success(outfits);
    });
  }

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

  /*
  *
  * Controllers
  *
  */

  function Controller() {
    var controller = this;
    this.events = {};

    function fireEvent(event_name, subarguments) {
      var events = controller.events[event_name];
      if(typeof events !== 'undefined') {
        for(var i = 0; i < events.length; i++) {
          events[i].apply(controller, subarguments);
        }
      }
    }

    this.bind = function (event, callback) {
      if(typeof this.events[event] == 'undefined') {
        this.events[event] = [];
      }
      this.events[event].push(callback);
    }

    this.event = function (event_name) {
      return function () {
        fireEvent(event_name, arguments);
      }
    }

    this.events.trigger = function (event_name) {
      var subarguments, event;
      if(controller.events[event_name]) {
        subarguments = Array.prototype.slice.apply(arguments, [1]);
        fireEvent(event_name, subarguments);
      }
    }
  }

  Controller.all = {};

  Controller.all.Outfit = function OutfitController() {
    var controller = this, outfit = new Outfit;

    this.in_transaction = false;

    function setFullOutfit(new_outfit) {
      outfit = new_outfit;
      controller.in_transaction = true;
      controller.setPetStateById(outfit.pet_state_id);
      controller.setPetTypeByColorAndSpecies(outfit.color_id, outfit.species_id);
      controller.setClosetItemsByIds(outfit.getClosetItemIds());
      controller.setWornItemsByIds(outfit.getWornItemIds());
      controller.events.trigger('setOutfit', outfit);
      controller.in_transaction = false;
      controller.events.trigger('loadOutfit', outfit);
    }

    function setOutfitIdentity(new_outfit) {
      new_outfit.cloneAttributesFrom(outfit);
      outfit = new_outfit;
    }

    this.closetItem = function (item) {
      outfit.closetItem(
        item,
        controller.event('updateClosetItems')
      );
    }

    this.getClosetItems = function () {
      return outfit.closet_items;
    }

    this.getId = function () {
      return outfit.id;
    }

    this.getOutfit = function () {
      return outfit;
    }

    this.getPetState = function () {
      return outfit.pet_state;
    }

    this.getPetType = function () {
      return outfit.pet_type;
    }

    this.getVisibleAssets = function () {
      return outfit.getVisibleAssets();
    }

    this.getWornItems = function () {
      return outfit.worn_items;
    }

    this.load = function (new_outfit_id) {
      Outfit.find(new_outfit_id, function (new_outfit) {
        setFullOutfit(new_outfit.clone());
      });
    }

    this.loadData = function (new_outfit_data) {
      setFullOutfit(new Outfit(new_outfit_data));
    }

    this.create = function (attributes) {
      if(attributes) {
        outfit.starred = attributes.starred;
        outfit.name = attributes.name;
      }
      outfit.create(
        function (outfit) {
          controller.events.trigger('saveSuccess', outfit);
          controller.events.trigger('createSuccess', outfit);
          controller.events.trigger('setOutfit', outfit);
        },
        controller.event('saveFailure')
      );
    }

    this.setClosetItemsByIds = function (item_ids) {
      outfit.setClosetItemsByIds(
        item_ids,
        controller.event('updateClosetItems')
      );
    }

    this.setId = function (outfit_id) {
      // Note that this does not load the outfit, but only sets the ID of the
      // outfit we're supposedly working with. This allows the hash to contain
      // the outfit ID while still allowing us to change as we go
      if(outfit_id) {
        Outfit.find(outfit_id, function (new_outfit) {
          if(new_outfit) {
            setOutfitIdentity(new_outfit);
            controller.events.trigger('setOutfit', outfit);
          } else {
            controller.events.trigger('outfitNotFound', outfit);
          }
        });
      } else {
        setOutfitIdentity(new Outfit);
        controller.events.trigger('setOutfit', outfit);
      }
    }

    this.setPetStateById = function (pet_state_id) {
      outfit.setPetStateById(pet_state_id, controller.event('updatePetState'));
    }

    this.setPetTypeByColorAndSpecies = function(color_id, species_id) {
      outfit.setPetTypeByColorAndSpecies(color_id, species_id,
        controller.event('updatePetType'),
        controller.event('petTypeLoaded'),
        controller.event('petTypeNotFound'),
        controller.event('updatePetState'),
        controller.event('updateWornItems'),
        controller.event('updateItemAssets')
      );
    }

    this.setWornItemsByIds = function (item_ids) {
      outfit.setWornItemsByIds(
        item_ids,
        controller.event('updateWornItems'),
        controller.event('updateItemAssets')
      );
    }

    this.share = function () {
      var sharedOutfit = outfit.clone();
      sharedOutfit.anonymous = true;
      sharedOutfit.create(
        controller.event('shareSuccess'),
        controller.event('shareFailure')
      );
    }

    this.unclosetItem = function (item) {
      outfit.unclosetItem(
        item,
        controller.event('updateClosetItems'),
        controller.event('updateWornItems')
      );
    }

    this.unwearItem = function (item) {
      outfit.unwearItem(item, controller.event('updateWornItems'));
    }

    this.update = function () {
      outfit.update(
        function (outfit) {
          controller.events.trigger('saveSuccess', outfit),
          controller.events.trigger('updateSuccess', outfit)
        },
        controller.event('saveFailure')
      );
    }

    this.wearItem = function (item) {
      outfit.wearItem(
        item,
        controller.event('updateWornItems'),
        controller.event('updateClosetItems'),
        controller.event('updateItemAssets')
      );
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

  Controller.all.User = function UserController() {
    var controller = this, outfits = [], outfits_loaded = false;

    function compareOutfits(a, b) {
      if(a.starred) {
        if(!b.starred) return -1;
      } else if(b.starred) {
        return 1;
      }
      if(a.name < b.name) return -1;
      else if(a.name == b.name) return 0;
      else return 1;
    }

    function insertOutfit(outfit) {
      for(var i = 0; i < outfits.length; i++) {
        if(compareOutfits(outfit, outfits[i]) < 0) {
          outfits.splice(i, 0, outfit);
          controller.events.trigger('addOutfit', outfit, i);
          return;
        }
      }
      controller.events.trigger('addOutfit', outfit, outfits.length);
      outfits.push(outfit);
    }

    function sortOutfits(outfits) {
      outfits.sort(compareOutfits);
    }

    function yankOutfit(outfit) {
      var i;
      for(i = 0; i < outfits.length; i++) {
        if(outfit.id == outfits[i].id) {
          outfits.splice(i, 1);
          break;
        }
      }
      controller.events.trigger('removeOutfit', outfit, i);
    }

    this.addOutfit = insertOutfit;

    this.destroyOutfit = function (outfit) {
      outfit.destroy(function () {
        yankOutfit(outfit);
      });
    }

    this.loadOutfits = function () {
      if(!outfits_loaded) {
        Outfit.loadForCurrentUser(function (new_outfits) {
          outfits = new_outfits;
          outfits_loaded = true;
          sortOutfits(outfits);
          controller.events.trigger('outfitsLoaded', outfits);
        });
      }
    }

    this.renameOutfit = function (outfit, new_name) {
      var old_name = outfit.name;
      outfit.rename(new_name, function () {
        yankOutfit(outfit);
        insertOutfit(outfit);
        controller.events.trigger('outfitRenamed', outfit);
      }, function (outfit_copy, response) {
        outfit.name = old_name;
        controller.events.trigger('saveFailure', outfit_copy, response);
      });
    }

    this.toggleOutfitStar = function (outfit) {
      outfit.toggleStar(function () {
        yankOutfit(outfit);
        insertOutfit(outfit);
        controller.events.trigger('outfitStarToggled', outfit);
      });
    }

    this.updateOutfit = function (outfit) {
      for(var i = 0; i < outfits.length; i++) {
        if(outfits[i].id == outfit.id) {
          outfits[i] = outfit.clone();
          break;
        }
      }
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

Wardrobe.IMAGE_CONFIG = {
  base_url: "https://s3.amazonaws.com/impress-asset-images/",
  sizes: [
    [600, 600],
    [300, 300],
    [150, 150]
  ]
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

      var outfit_events = ['updateWornItems', 'updateClosetItems', 'updateItemAssets', 'updatePetType', 'updatePetState'];
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
    var preview = this;
    var preview_el = $(options.Preview.wrapper),
      preview_swf_placeholder = $(options.Preview.placeholder);

    function SWFAdapter() {
      var preview_swf_id = preview_swf_placeholder.attr('id'),
        preview_swf,
        update_pending_flash = false;

      preview_el.removeClass('image-adapter').addClass('swf-adapter');

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

      this.previewSWFIsReady = function () {
        preview_swf = document.getElementById(preview_swf_id);
        if(update_pending_flash) {
          update_pending_flash = false;
          this.updateAssets();
        }
      }

      this.updateAssets = function () {
        var assets, assets_for_swf;
        if(update_pending_flash) return false;
        if(preview_swf && preview_swf.setAssets) {
          assets = wardrobe.outfit.getVisibleAssets();
          preview_swf.setAssets(assets);
        } else {
          update_pending_flash = true;
        }
      }
    }

    function ImageAdapter() {
      var pendingAssets = {}, pendingAssetIds = [], pendingInterval,
        pendingAssetsCount = 0,
        pendingMessageEl = $('<span/>', {id: 'preview-images-pending'}),
        previewImageContainer = $(options.Preview.image_container);

      var ASSET_PING_RATE = 5000;

      preview_el.removeClass('swf-adapter').addClass('image-adapter');
      pendingMessageEl.appendTo(previewImageContainer);

      this.updateAssets = function () {
        var assets = wardrobe.outfit.getVisibleAssets(), asset,
          availableAssets = [];
        pendingAssets = {};
        pendingAssetsCount = 0;
        clearView();
        for(var i in assets) {
          if(!assets.hasOwnProperty(i)) continue;
          asset = assets[i];
          if(asset.has_image) {
            addToView(asset);
          } else {
            pendingAssets[asset.id] = asset;
            pendingAssetsCount++;
          }
        }
        updatePendingStatus();
      }

      function addToView(asset) {
        $(
          '<img/>',
          {
            css: {
              zIndex: asset.depth
            },
            src: asset.imageURL(bestSize())
          }
        ).appendTo(previewImageContainer);
      }

      // TODO: choose new best size on window resize
      function bestSize() {
        var sizes = Wardrobe.IMAGE_CONFIG.sizes,
          width = preview_el.width(), height = preview_el.height();
        for(var i in sizes) {
          if(sizes[i][0] < width && sizes[i][1] < height) return sizes[i];
        }
        return sizes[sizes.length - 1];
      }

      function clearView() {
        previewImageContainer.children('img').remove();
      }

      function loadPendingAssets() {
        var pendingAssetIds = {
          biology: [],
          object: []
        }, asset;
        for(var i in pendingAssets) {
          if(pendingAssets.hasOwnProperty(i)) {
            pendingAssetIds[pendingAssets[i].type].push(pendingAssets[i].id);
          }
        }
        $.getJSON(
          '/swf_assets.json',
          {
            ids: pendingAssetIds
          },
          function (assetsData) {
            var assetData, asset;
            for(var i in assetsData) {
              assetData = assetsData[i];
              if(assetData.has_image && pendingAssets.hasOwnProperty(assetData.id)) {
                asset = pendingAssets[assetData.id];
                asset.update(assetData);
                delete pendingAssets[assetData.id];
                pendingAssetsCount--;
                addToView(asset);
              }
            }
            updatePendingStatus();
          }
        );
      }

      function updateContainerSize() {
        var size = bestSize();
        previewImageContainer.css({
          height: size[1],
          width: size[0]
        });
      }

      function updatePendingInterval() {
        if(pendingAssetsCount) {
          if(pendingInterval == null) {
            pendingInterval = setInterval(loadPendingAssets, ASSET_PING_RATE);
          }
        } else {
          if(pendingInterval != null) {
            clearInterval(pendingInterval);
            pendingInterval = null;
          }
        }
      }

      function updatePendingMessage() {
        pendingMessageEl.text("Waiting on " + pendingAssetsCount + " images").
          attr("className", "waiting-on-" + pendingAssetsCount);
      }

      function updatePendingStatus() {
        updatePendingInterval();
        updatePendingMessage();
      }

      updateContainerSize();
      $(window).resize(updateContainerSize);
    }

    this.adapter = new SWFAdapter();

    function updateAssets() {
      preview.adapter.updateAssets();
    }

    wardrobe.outfit.bind('updateWornItems', updateAssets);
    wardrobe.outfit.bind('updateItemAssets', updateAssets);
    wardrobe.outfit.bind('updatePetState', updateAssets);

    this.useSWFAdapter = function () { preview.adapter = new SWFAdapter(); updateAssets(); }
    this.useImageAdapter = function () { preview.adapter = new ImageAdapter(); updateAssets(); }
    this.toggleAdapter = function () {
      var nextAdapter = preview.adapter.constructor == SWFAdapter ? ImageAdapter : SWFAdapter;
      preview.adapter = new nextAdapter();
      updateAssets();
    }
  }

  window.previewSWFIsReady = function (id) {
    Wardrobe.StandardPreview.views_by_swf_id[id].previewSWFIsReady();
  }

  return StandardView;
}

