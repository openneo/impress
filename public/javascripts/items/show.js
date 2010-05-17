var PREVIEW_SWF_ID = 'item-preview-swf',
  PREVIEW_SWF = document.getElementById(PREVIEW_SWF_ID),
  IMPRESS_HOST = PREVIEW_SWF.getAttribute('data-impress-host'),
  speciesList = $('#item-preview a');

function impressUrl(path) {
  return 'http://' + IMPRESS_HOST + path;
}

function PetType() {}

PetType.prototype.load = function () {
  var url = '/species/' + this.species_id + '/color/' + this.color_id + '/pet_type.json';
  $.getJSON(url, function (data) {
    console.log(data);
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

swfobject.embedSWF(
  impressUrl('/assets/swf/preview.swf'), // URL
  PREVIEW_SWF_ID, // ID
  400, // width
  400, // height
  '9', // required version
  impressUrl('/assets/js/swfobject/expressInstall.swf'), // express install URL
  {'swf_assets_path': impressUrl('/assets')}, // flashvars
  {'wmode': 'transparent', 'allowscriptaccess': 'always'} // params
)

PetType.create_from_link(speciesList.eq(Math.floor(Math.random()*speciesList.length))).setAsCurrent();

speciesList.click(function (e) {
  e.preventDefault();
  PetType.create_from_link($(this)).setAsCurrent();
});
