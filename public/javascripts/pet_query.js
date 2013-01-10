function petImage(id, size) {
  return 'http://pets.neopets.com/' + id + '/1/' + size + '.png';
}

var PetQuery = {},
  query_string = document.location.hash || document.location.search;

$.each(query_string.substr(1).split('&'), function () {
  var split_piece = this.split('=');
  if(split_piece.length == 2) {
    PetQuery[split_piece[0]] = split_piece[1];
  }
});

if(PetQuery.name) {
  if(PetQuery.species && PetQuery.color) {
    $('#pet-query-notice-template').tmpl({
      pet_name: PetQuery.name,
      pet_image_url: petImage('cpn/' + PetQuery.name, 1)
    }).prependTo('#container');
  }
}
