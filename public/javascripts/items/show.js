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

function impressUrl(path) {
  return 'http://' + IMPRESS_HOST + path;
}

function PetType() {}

PetType.prototype.load = function () {
  var url = '/species/' + this.species_id + '/color/' + this.color_id + '/pet_type.json',
    pet_type = this;
  $.getJSON(url, function (data) {
    pet_type.id = data.id;
    pet_type.body_id = data.body_id;
    $.getJSON('/pet_types/' + data.id + '/swf_assets.json', function (assets) {
      pet_type.assets = assets;
      Preview.update();
    });
  });
}

PetType.prototype.setAsCurrent = function () {
  PetType.current = this;
  speciesList.filter('.current').removeClass('current');
  this.link.addClass('current');
  this.load();
}

PetType.create_from_link = function (link) {
  var pet_type = new PetType();
  pet_type.color_id = link.attr('data-color-id');
  pet_type.species_id = link.attr('data-species-id');
  pet_type.link = link;
  return pet_type;
}

Preview = new function Preview() {
  var assets = [], swf_id, swf, updateWhenFlashReady = false;
  
  this.setFlashIsReady = function () {
    log('flash ready');
    swf = document.getElementById(swf_id);
    if(updateWhenFlashReady) this.update();
  }
  
  this.update = function (assets) {
    var assets;
    log('want to update');
    if(swf) {
      log('got to update');
      log(PetType.current.assets);
      assets = $.each(PetType.current.assets, function () {
        this.local_path = this.local_url;
      });
      log(assets);
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
      400, // width
      400, // height
      '9', // required version
      impressUrl('/assets/js/swfobject/expressInstall.swf'), // express install URL
      {'swf_assets_path': impressUrl('/assets')}, // flashvars
      {'wmode': 'transparent', 'allowscriptaccess': 'always'} // params
    );
  }
}

Preview.embed(PREVIEW_SWF_ID);

PetType.create_from_link(speciesList.eq(Math.floor(Math.random()*speciesList.length))).setAsCurrent();

speciesList.click(function (e) {
  e.preventDefault();
  PetType.create_from_link($(this)).setAsCurrent();
});

MainWardrobe = { View: { Outfit: Preview } };
