var PREVIEW_SWF_ID = 'item-preview-swf',
  speciesList = $('#item-preview a');

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
  'http://impress.openneo.net/assets/swf/preview.swf', // URL
  PREVIEW_SWF_ID, // ID
  400, // width
  400, // height
  '9', // required version
  'http://impress.openneo.net/assets/js/swfobject/expressInstall.swf', // express install URL
  {'swf_assets_path': '/assets'}, // flashvars
  {'wmode': 'transparent'} // params
)

PetType.create_from_link(speciesList.eq(Math.floor(Math.random()*speciesList.length))).setAsCurrent();

speciesList.click(function (e) {
  e.preventDefault();
  PetType.create_from_link($(this)).setAsCurrent();
});
