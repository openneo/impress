/** @jsx React.DOM */

(function($) {
  // Console-polyfill. MIT license.
  // https://github.com/paulmillr/console-polyfill
  // Make it safe to do console.log() always.
  var console = (function (con) {
    'use strict';
    var prop, method;
    var empty = {};
    var dummy = function() {};
    var properties = 'memory'.split(',');
    var methods = ('assert,count,debug,dir,dirxml,error,exception,group,' +
       'groupCollapsed,groupEnd,info,log,markTimeline,profile,profileEnd,' +
       'time,timeEnd,trace,warn').split(',');
    while (prop = properties.pop()) con[prop] = con[prop] || empty;
    while (method = methods.pop()) con[method] = con[method] || dummy;
    return con;
  })(window.console || {});

  var Neopia = {
    User: {
      get: function(id) {
        return Neopia.getJSON("/users/" + id).then(function(response) {
          return response.users[0];
        });
      }
    },
    Customization: {
      get: function(petId) {
        return Neopia.getJSON("/pets/" + petId + "/customization").then(function(response) {
          return response.custom_pet;
        });
      }
    },
    getJSON: function(path) {
      return $.getJSON(Neopia.API_URL + path);
    },
    init: function() {
      var hostEl = $('meta[name=neopia-host]');
      if (!hostEl.length) {
        throw "missing neopia-host meta tag";
      }
      var host = hostEl.attr('content');
      if (!host) {
        throw "neopia-host meta tag exists, but is empty";
      }
      Neopia.API_URL = "http://" + host + "/api/1";
    }
  };

  var Modeling = {
    _customizationsByPetId: {},
    _customizations: [],
    _items: [],
    _addCustomization: function(customization) {
      this._customizationsByPetId[customization.name] = customization;
      this._customizations = this._buildCustomizations();
      this._update();
    },
    _buildCustomizations: function() {
      var modelCustomizationsByPetId = this._customizationsByPetId;
      return Object.keys(modelCustomizationsByPetId).map(function(petId) {
        return modelCustomizationsByPetId[petId];
      });
    },
    _createItems: function($) {
      this._items = $('#newest-unmodeled-items li').map(function() {
        var el = $(this);
        var name = el.find('h2').text();
        return {
          component: React.renderComponent(<ModelForItem itemName={name} />,
                                           el.find('.models').get(0)),
          el: el,
          id: el.attr('data-item-id'),
          missingBodyIdsPresenceMap: el.find('span[data-body-id]').toArray().reduce(function(map, node) {
            map[$(node).attr('data-body-id')] = true;
            return map;
          }, {})
        };
      }).toArray();
    },
    _loadPetCustomization: function(neopiaPetId) {
      return Neopia.Customization.get(neopiaPetId)
        .done(this._addCustomization.bind(this))
        .fail(function() {
          console.error("couldn't load pet %s", neopiaPetId);
        });
    },
    _loadManyPetsCustomizations: function(neopiaPetIds) {
      return neopiaPetIds.map(this._loadPetCustomization.bind(this));
    },
    _loadUserCustomizations: function(neopiaUserId) {
      return Neopia.User.get(neopiaUserId).then(function(neopiaUser) {
        return neopiaUser.links.pets;
      }).then(this._loadManyPetsCustomizations.bind(this)).fail(function() {
        console.error("couldn't load user %s's customizations", neopiaUserId);
      });
    },
    _loadManyUsersCustomizations: function(neopiaUserIds) {
      return neopiaUserIds.map(this._loadUserCustomizations.bind(this));
    },
    _update: function() {
      var customizations = this._customizations;
      this._items.forEach(function(item) {
        var filteredCustomizations = customizations.filter(function(c) {
          return item.missingBodyIdsPresenceMap[c.body_id];
        });
        item.component.setState({customizations: filteredCustomizations});
      });
    },
    init: function($) {
      Neopia.init();
      this._createItems($);
      // TODO: use user prefs, silly!
      var search = document.location.search;
      var users = search.indexOf('=') >= 0 ? search.split('=')[1].split(',') : '';
      this._loadManyUsersCustomizations(users);
    }
  };

  var ModelForItem = React.createClass({
    getInitialState: function() {
      return {customizations: []};
    },
    render: function() {
      var itemName = this.props.itemName;
      function createModelPet(customization) {
        return <ModelPet customization={customization}
                         itemName={itemName}
                         key={customization.name} />;
      }
      var sortedCustomizations = this.state.customizations.sort(function(a, b) {
        var aName = a.name.toLowerCase();
        var bName = b.name.toLowerCase();
        if (aName < bName) return -1;
        if (aName > bName) return 1;
        return 0;
      });
      return <ul>{sortedCustomizations.map(createModelPet)}</ul>;
    }
  });

  var ModelPet = React.createClass({
    render: function() {
      var petName = this.props.customization.name;
      var itemName = this.props.itemName;
      var imageSrc = "http://pets.neopets.com/cpn/" + petName + "/1/1.png";
      // TODO: i18n
      var title = "Submit " + petName + " as a model, especially if they're " +
                  "wearing the " + itemName + "!";
      return <li><button title={title}>
        <img src={imageSrc} />
        <span>{petName}</span>
      </button></li>;
    }
  });

  Modeling.init($);
})(jQuery);
