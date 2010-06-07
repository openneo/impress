// TODO: zones_restrict

var PREVIEW_SWF_ID = 'item-preview-swf',
  PREVIEW_SWF = document.getElementById(PREVIEW_SWF_ID),
  IMPRESS_HOST = PREVIEW_SWF.getAttribute('data-impress-host'),
  speciesList = $('#item-preview a'),
  MainWardrobe;

if(console === undefined || console.log === undefined) {
  function log() {}
} else {
  log = $.proxy(console, 'log');
}

String.prototype.capitalize = function () {
  return this.charAt(0).toUpperCase() + this.substr(1);
}

String.prototype.article = function () {
  return 'aeiou'.indexOf(this.charAt(0).toLowerCase()) == -1 ? 'a' : 'an'
}

function impressUrl(path) {
  return 'http://' + IMPRESS_HOST + path;
}

function LoadError(base_msg) {
  this.render = function (args) {
    var msg = base_msg, token, article_token;
    for(var i in args) {
      token = "$" + i;
      article_token = token + "_article";
      if(msg.indexOf(article_token) != -1) {
        msg = msg.replace(article_token, args[i].article());
      }
      msg = msg.replace(token, args[i]);
    }
    return "Whoops - we've never seen " + msg + " before! If you have, please " +
    "<a href='http://" + IMPRESS_HOST + "'>submit that pet's name</a> as soon as you " +
    "get the chance! Thanks!";
  }
}

function PetType() {
  var pet_type = this, loaded_data = false, loaded_assets = false;
  
  this.activated = true;
  this.assets = true;
  
  this.deactivate = function (error, args) {
    var msg;
    this.activated = false;
    if(typeof args == 'undefined') args = {};
    args.color = this.color_name.capitalize();
    args.species = this.species_name.capitalize();
    this.deactivation_msg = error.render(args);
    if(this == PetType.current) showDeactivationMsg();
    var img = this.link.children('img').get(0);
    this.link.addClass('deactivated');
    img.src = img.src.replace('/1/', '/2/');
  }
  
  this.load = function () {
    Item.current.load(this);
    loadAssets();
  }

  this.setAsCurrent = function () {
    PetType.current = this;
    speciesList.filter('.current').removeClass('current');
    this.link.addClass('current');
    if(this.activated) {
      Preview.enable();
      this.load();
    } else {
      showDeactivationMsg();
    }
  }
  
  function loadAssets() {
    function onComplete() { if(pet_type == PetType.current) Preview.update(); }
    if(!loaded_assets) {
      $.getJSON('/pet_types/' + pet_type.id + '/swf_assets.json', function (assets) {
        pet_type.assets = assets;
        loaded_assets = true;
        onComplete();
      });
    }
    onComplete();
  }
  
  function showDeactivationMsg() {
    Preview.disable(pet_type.deactivation_msg);
  }
}

PetType.all = [];

PetType.LOAD_ERROR = new LoadError("$color_article $color $species");
PetType.DASH_REGEX = /-/g;

PetType.createFromLink = function (link) {
  var pet_type = new PetType();
  $.each(link.get(0).attributes, function () {
    if(this.name.substr(0, 5) == 'data-') {
      pet_type[this.name.substr(5).replace(PetType.DASH_REGEX, '_')] = this.value;
    }
  });
  pet_type.link = link;
  PetType.all.push(pet_type);
  return pet_type;
}

function Item() {
  this.assets_by_body_id = {};
  
  this.load = function (pet_type) {
    var url = '/' + this.id + '/swf_assets.json?body_id=' + pet_type.body_id,
      item = this;
    function onComplete() { if(pet_type == PetType.current) Preview.update() }
    if(this.getAssetsForPetType(pet_type).length) {
      onComplete();
    } else {
      $.getJSON(url, function (data) {
        if(data.length) {
          item.assets_by_body_id[pet_type.body_id] = data;
          onComplete();
        } else {
          pet_type.deactivate(Item.LOAD_ERROR, {
            item: item.name
          });
        }
      });
    }
  }
  
  this.getAssetsForPetType = function (pet_type) {
    return this.assets_by_body_id[pet_type.body_id] || [];
  }
  
  this.setAsCurrent = function () {
    Item.current = this;
  }
}

Item.LOAD_ERROR = new LoadError("$species_article $species wear a $item");

Item.createFromLocation = function () {
  var item = new Item();
  item.id = parseInt(document.location.pathname.substr(1));
  return item;
}

Preview = new function Preview() {
  var swf_id, swf, updateWhenFlashReady = false;
  
  this.setFlashIsReady = function () {
    swf = document.getElementById(swf_id);
    if(updateWhenFlashReady) this.update();
  }
  
  this.update = function (assets) {
    var assets = [], asset_sources = [
      PetType.current.assets,
      Item.current.getAssetsForPetType(PetType.current)
    ];
    if(swf) {
      $.each(asset_sources, function () {
        assets = assets.concat(this);
      });
      $.each(assets, function () {
        this.local_path = this.local_url;
      });
      swf.setAssets(assets);
    } else {
      updateWhenFlashReady = true;
    }
  }
  
  this.embed = function (id) {
    swf_id = id;
    swfobject.embedSWF(
      impressUrl('/assets/swf/preview.swf'), // URL
      id, // ID
      '100%', // width
      '100%', // height
      '9', // required version
      impressUrl('/assets/js/swfobject/expressInstall.swf'), // express install URL
      {'swf_assets_path': impressUrl('/assets')}, // flashvars
      {'wmode': 'transparent', 'allowscriptaccess': 'always'} // params
    );
  }
  
  this.disable = function (msg) {
    $('#' + swf_id).hide();
    $('#item-preview-error').html(msg).show();
  }
  
  this.enable = function () {
    $('#item-preview-error').hide();
    $('#' + swf_id).show();
  }
}

Preview.embed(PREVIEW_SWF_ID);

Item.createFromLocation().setAsCurrent();
Item.current.name = $('#item-name').text();

PetType.createFromLink(speciesList.eq(Math.floor(Math.random()*speciesList.length))).setAsCurrent();

speciesList.each(function () {
  var pet_type = PetType.createFromLink($(this));
  $(this).click(function (e) {
    e.preventDefault();
    pet_type.setAsCurrent();
  });
});

MainWardrobe = { View: { Outfit: Preview } };
