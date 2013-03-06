var DEBUG = (document.location.search.substr(0, 6) == '?debug');

/* Needed items form */
(function () {
  var UI = {};
  UI.form = $('#needed-items-form');
  UI.alert = $('#needed-items-alert');
  UI.pet_name_field = $('#needed-items-pet-name-field');
  UI.pet_thumbnail = $('#needed-items-pet-thumbnail');
  UI.pet_header = $('#needed-items-pet-header');
  UI.reload = $('#needed-items-reload');
  UI.pet_items = $('#needed-items-pet-items');
  UI.item_template = $('#item-template');
  
  var current_request = { abort: function () {} };
  function sendRequest(options) {
    current_request = $.ajax(options);
  }
  
  function cancelRequest() {
    if(DEBUG) console.log("Canceling request", current_request);
    current_request.abort();
  }
  
  /* Pet */
  
  var last_successful_pet_name = null;
  
  function loadPet(pet_name) {
    // If there is a request in progress, kill it. Our new pet request takes
    // priority, and, if I submit a name while the previous name is loading, I
    // don't want to process both responses.
    cancelRequest();
    
    sendRequest({
      url: UI.form.attr('action') + '.json',
      dataType: 'json',
      data: {name: pet_name},
      error: petError,
      success: function (data) { petSuccess(data, pet_name) },
      complete: petComplete
    });
    
    UI.form.removeClass('failed').addClass('loading-pet');
  }
  
  function petComplete() {
    UI.form.removeClass('loading-pet');
  }
  
  function petError(xhr) {
    UI.alert.text(xhr.responseText);
    UI.form.addClass('failed');
  }
  
  function petSuccess(data, pet_name) {
    last_successful_pet_name = pet_name;
    UI.pet_thumbnail.attr('src', petThumbnailUrl(pet_name));
    UI.pet_header.empty();
    $('#needed-items-pet-header-template').tmpl({pet_name: pet_name}).
      appendTo(UI.pet_header);
    loadItems(data.query);
  }
  
  function petThumbnailUrl(pet_name) {
    return 'http://pets.neopets.com/cpn/' + pet_name + '/1/1.png';
  }
  
  /* Items */
  
  function loadItems(query) {
    UI.form.addClass('loading-items');
    sendRequest({
      url: '/items/needed.json',
      dataType: 'json',
      data: query,
      success: itemsSuccess
    });
  }
  
  function itemsSuccess(items) {
    if(DEBUG) {
      // The dev server is missing lots of data, so sends me 2000+ needed
      // items. We don't need that many for styling, so limit it to 100 to make
      // my browser happier.
      items = items.slice(0, 100);
    }
    
    UI.pet_items.empty();
    UI.item_template.tmpl(items).appendTo(UI.pet_items);
    
    UI.form.removeClass('loading-items').addClass('loaded');
  }
  
  UI.form.submit(function (e) {
    e.preventDefault();
    loadPet(UI.pet_name_field.val());
  });
  
  UI.reload.click(function (e) {
    e.preventDefault();
    loadPet(last_successful_pet_name);
  });
})();

/* Bulk pets form */
(function () {
  var form = $('#bulk-pets-form'),
    queue_el = form.find('ul'),
    names_el = form.find('textarea'),
    add_el = $('#bulk-pets-form-add'),
    clear_el = $('#bulk-pets-form-clear'),
    bulk_load_queue;

  $(document.body).addClass('js');

  bulk_load_queue = new (function BulkLoadQueue() {
    var pets = [], url = form.attr('action') + '.json';
    
    function Pet(name) {
      var el = $('#bulk-pets-submission-template').tmpl({pet_name: name}).
        appendTo(queue_el);
      
      this.load = function () {
        el.removeClass('waiting').addClass('loading');
        var response_el = el.find('span.response');
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
            el.removeClass('loading').addClass('failed');
            response_el.text(xhr.responseText);
          },
          success: function (data) {
            var points = data.points;
            el.removeClass('loading').addClass('loaded');
            $('#bulk-pets-submission-success-template').tmpl({points: points}).
              appendTo(response_el);
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
})();
