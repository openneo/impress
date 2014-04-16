var disqus_shortname = 'dresstoimpress';

(function () { // don't need to export anything in here

var preview_el = $('#pet-preview'),
  img_el = preview_el.find('img'),
  response_el = preview_el.find('span'),
  name_el = $('#main-pet-name');

preview_el.click(function () {
  Preview.Job.current.visit();
});

var Preview = {
  clear: function () {
    if(typeof Preview.Job.fallback != 'undefined') Preview.Job.fallback.setAsCurrent();
  },
  displayLoading: function () {
    preview_el.addClass('loading');
    response_el.text('Loading...');
  },
  failed: function () {
    preview_el.addClass('hidden');
  },
  notFound: function (key, options) {
    Preview.failed();
    response_el.empty();
    $('#preview-' + key + '-template').tmpl(options).appendTo(response_el);
  },
  updateWithName: function () {
    var name = name_el.val(), job;
    if(name) {
      currentName = name;
      if(!Preview.Job.current || name != Preview.Job.current.name) {
        job = new Preview.Job.Name(name);
        job.setAsCurrent();
        Preview.displayLoading();
      }
    } else {
      Preview.clear();
    }
  }
}

$.getJSON('http://notables.openneo.net/api/1/days/ago/1?callback=?', function (response) {
  var notables = response.notables;
  var i = Math.floor(Math.random() * notables.length);
  Preview.Job.fallback = new Preview.Job.Name(notables[i].petName);
  if(!Preview.Job.current) {
    Preview.Job.fallback.setAsCurrent();
  }
});

Preview.Job = function (key, base) {
  var job = this,
    quality = 2;
  job.loading = false;
  
  function getImageSrc() {
    if (key.substr(0, 3) === 'a:-') {
      // lol lazy code for prank image :P
      return "http://swfimages.impress.openneo.net" +
        "/biology/000/000/0-2/" + key.substr(2) + "/300x300.png";
    } else {
      return petImage(base + '/' + key, quality);
    }
  }
  
  function load() {
    job.loading = true;
    img_el.attr('src', getImageSrc());
  }
  
  this.increaseQualityIfPossible = function () {
    if(quality == 2) {
      quality = 4;
      load();
    }
  }
  
  this.setAsCurrent = function () {
    Preview.Job.current = job;
    load();
  }
}

Preview.Job.Name = function (name) {
  this.name = name;
  Preview.Job.apply(this, [name, 'cpn']);

  this.visit = function() {
    name_el.val(this.name).closest('form').submit();
  }
}

Preview.Job.Hash = function (hash) {
  Preview.Job.apply(this, [hash, 'cp']);

  this.visit = function() {
    window.location = "/wardrobe?color=" + $('#color').val() + "&species=" +
      $('#species').val();
  }
}


$(function () {
  var previewWithNameTimeout;
  
  name_el.val(PetQuery.name);
  Preview.updateWithName();
  
  name_el.keyup(function () {
    if(previewWithNameTimeout) {
      clearTimeout(previewWithNameTimeout);
      Preview.Job.current.loading = false;
    }
    previewWithNameTimeout = setTimeout(Preview.updateWithName, 250);
  });
  
  img_el.load(function () {
    if(Preview.Job.current.loading) {
      Preview.Job.loading = false;
      Preview.Job.current.increaseQualityIfPossible();
      preview_el.removeClass('loading').removeClass('hidden').addClass('loaded');
      response_el.text(Preview.Job.current.name);
    }
  }).error(function () {
    if(Preview.Job.current.loading) {
      Preview.Job.loading = false;
      Preview.notFound('pet-not-found');
    }
  });
  
  var selectFields = $('#species, #color');
  selectFields.change(function () {
    var type = {}, nameComponents = {};
    selectFields.each(function () {
      var el = $(this), selectedEl = el.children(':selected'), key = el.attr('id');
      type[key] = selectedEl.val();
      nameComponents[key] = selectedEl.text();
    });
    name = nameComponents.color + ' ' + nameComponents.species;
    Preview.displayLoading();
    $.ajax({
      url: '/species/' + type.species + '/color/' + type.color + '/pet_type.json',
      data: {
        'for': 'image'
      },
      dataType: 'json',
      success: function (data) {
        var job;
        if(data) {
          job = new Preview.Job.Hash(data.image_hash);
          job.name = name;
          job.setAsCurrent();
        } else {
          Preview.notFound('pet-type-not-found', {
            color_name: nameComponents.color,
            species_name: nameComponents.species
          });
        }
      }
    });
  });
  
  $.getJSON('http://blog.openneo.net/api/read/json?callback=?', function (data) {
    var post = data.posts[0], el = $('#blog-preview'),
      url = post['url-with-slug'], header = "Here's the latest!", body = '',
      truncate_body_at = 500, image;
    if(post.type == 'regular') {
      header = post['regular-title'];
      body = post['regular-body'];
    } else if(post.type == 'link') {
      header = post['link-text'];
      body = post['link-description'];
    } else if(post.type == 'photo') {
      body = post['photo-caption'];
      image = post['photo-url-75'];
    }
    // No truncation on this new layout
    /*body = body.replace(/(<\/?[\S][^>]*>)/gi, '');
    if(body.length > truncate_body_at) {
      body = body.substring(0, truncate_body_at);
      body = body.replace(/\s+\w+$/, '');
      body += '&hellip;';
    }*/
    el.find('h2').text(header).wrapInner($('<a/>', {href: url}));
    var contentEl = el.find('div');
    contentEl.html(body);
    $('<a/>', {'id': 'blog-preview-comments', href: url + '#disqus_thread'}).appendTo(el);
    if(image) {
      el.find('img').attr('src', image).parent().attr('href', url);
    }
    
    // Localize
    var localizedBodies = {};
    contentEl.find('.locale').each(function () {
      var localizedBody = $(this);
      var locale = localizedBody.attr('class').match(/locale-(\S+)/)[1];
      localizedBodies[locale] = localizedBody;
    });
    
    var fallbacks = $('#locale option:selected').attr('data-fallbacks').split(',');
    var bestLocale = null;
    for(var i = 0; i < fallbacks.length; i++) {
      if(localizedBodies.hasOwnProperty(fallbacks[i])) {
        bestLocale = fallbacks[i];
        break;
      }
    }
    
    if(bestLocale) {
      // I feel bad doing all this in JS rather than CSS, but sometimes you
      // gotta do what you gotta do if you wanna support any number of locales.
      for(var locale in localizedBodies) {
        localizedBodies[locale].hide();
      }
      
      localizedBodies[bestLocale].show();
      
      contentEl.find('.no-locale').hide();
    }
    
    el.fadeIn('medium');
    addDisqusCount();
  });

  var neopiaError = document.location.search.match(/neopia%5Berror%5D=([^&]+)/);
  if (neopiaError !== null) {
    var message = decodeURI(neopiaError[1]).replace(/\+/g, ' ');
    if (message === "pet not found") {
      $('#pet-not-found').show();
    } else {
      var el = $('#neopia-error');
      var text = el.text().replace('%{message}', message);
      el.text(text).show();
    }
  }

  $('#load-pet-to-wardrobe').submit(function(e) {
    if (name_el.val() === "" && Preview.Job.current) {
      e.preventDefault();
      Preview.Job.current.visit();
    }
  });
});

function addDisqusCount() { 
  var s = document.createElement('script'); s.async = true;
  s.type = 'text/javascript';
  s.src = 'http://' + disqus_shortname + '.disqus.com/count.js';
  (document.getElementsByTagName('HEAD')[0] || document.getElementsByTagName('BODY')[0]).appendChild(s);}
})();

$('#latest-contribution-created-at').timeago();
