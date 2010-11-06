var form = $('#bulk-pets-form'),
  queue_el = form.find('ul'),
  names_el = form.find('textarea'),
  add_el = $('#bulk-pets-form-add'),
  clear_el = $('#bulk-pets-form-clear'),
  bulk_load_queue;

$(document.body).addClass('js');

bulk_load_queue = new (function BulkLoadQueue() {
  var pets = [],
    standard_pet_el = $('<li/>'),
    url = form.attr('action') + '.json';
  standard_pet_el.append('<img/>').append($('<span/>', {'class': 'name'}))
    .append($('<span/>', {'class': 'response', text: 'Waiting...'}));
  
  function Pet(name) {
    var el = standard_pet_el.clone()
      .children('img').attr('src', petImage('cpn/' + name, 1)).end()
      .children('span.name').text(name).end();
    el.appendTo(queue_el);
    
    this.load = function () {
      var response_el = el.children('span.response').text('Loading...');
      $.ajax({
        complete: function (data) {
          pets.shift();
          if(pets.length) {
            pets[0].load();
          }
        },
        data: {name: name},
        dataType: 'json',
        error: function (xhr) {
          el.addClass('failed');
          response_el.text(xhr.responseText);
        },
        success: function (data) {
          var response = data === true ? 'Thanks!' : data + ' points';
          el.addClass('loaded');
          response_el.text(response);
        },
        type: 'post',
        url: url
      });
    }
  }
  
  this.add = function (name) {
    name = name.replace(/^\s+|\s+$/g, '');
    if(name.length) {
      var pet = new Pet(name);
      pets.push(pet);
      if(pets.length == 1) pet.load();
    }
  }
})();

names_el.keyup(function () {
  var names = this.value.split('\n'), x = names.length - 1, i, name;
  for(i = 0; i < x; i++) {
    bulk_load_queue.add(names[i]);
  }
  this.value = (x >= 0) ? names[x] : '';
});

add_el.click(function () {
  bulk_load_queue.add(names_el.val());
  names_el.val('');
});

clear_el.click(function () {
  queue_el.children('li.loaded, li.failed').remove();
});
