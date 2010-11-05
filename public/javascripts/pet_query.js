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
    var notice = $('<div></div>', {
        'class': 'success',
        'html': "Thanks for showing us <strong>" + PetQuery.name + "</strong>! " +
          "Keep up the good work!"
      }),
      image = $('<img/>', {
        'class': 'inline-image',
        'src': petImage('cpn/' + PetQuery.name, 1)
      });
    image.prependTo(notice);
    notice.prependTo('#container');
  }
}
