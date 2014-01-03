/** @jsx React.DOM */

// Console-polyfill. MIT license.
// https://github.com/paulmillr/console-polyfill
// Make it safe to do console.log() always.
(function (con) {
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
})(window.console = window.console || {});

(function() {
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
    _modelForItemComponents: [],
    _customizationsByPetId: {},
    _addCustomization: function(customization) {
      this._customizationsByPetId[customization.name] = customization;
      this._update();
    },
    _getCustomizations: function() {
      var modelCustomizationsByPetId = this._customizationsByPetId;
      return Object.keys(modelCustomizationsByPetId).map(function(petId) {
        return modelCustomizationsByPetId[petId];
      });
    },
    _loadPetCustomization: function(neopiaPetId) {
      return Neopia.Customization.get(neopiaPetId)
        .done(this._addCustomization.bind(this));
    },
    _loadManyPetsCustomizations: function(neopiaPetIds) {
      return neopiaPetIds.map(this._loadPetCustomization.bind(this));
    },
    _loadUserCustomizations: function(neopiaUserId) {
      return Neopia.User.get(neopiaUserId).then(function(neopiaUser) {
        return neopiaUser.links.pets;
      }).then(this._loadManyPetsCustomizations.bind(this));
    },
    _loadManyUsersCustomizations: function(neopiaUserIds) {
      return neopiaUserIds.map(this._loadUserCustomizations.bind(this));
    },
    _update: function() {
      var state = {
        customizations: this._getCustomizations()
      };
      this._modelForItemComponents.forEach(function(c) {
        c.setState(state);
      });
    },
    init: function() {
      Neopia.init();
      this._modelForItemComponents = $('#newest-unmodeled-items li').map(function() {
        return React.renderComponent(<ModelForItem />,
                                     $(this).find('.models').get(0));
      }).toArray();
      var users = ["borovan", "donna"];
      this._loadManyUsersCustomizations(users);
    }
  };

  var ModelForItem = React.createClass({
    getInitialState: function() {
      return {customizations: []};
    },
    render: function() {
      function createModelPet(customization) {
        return <ModelPet customization={customization}
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
      var imageSrc = "http://pets.neopets.com/cpn/" + petName + "/1/1.png";
      return <li><button>
        <img src={imageSrc} />
        <span>{petName}</span>
      </button></li>;
    }
  });

  Modeling.init();
})();
