/** @jsx React.DOM */

(function($, I18n) {
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
        return $.ajax({
          dataType: "json",
          url: Neopia.API_URL + "/users/" + id,
          useCSRFProtection: false
        }).then(function(response) {
          return response.users[0];
        });
      }
    },
    Customization: {
      request: function(petId, type) {
        return $.ajax({
          dataType: "json",
          type: type,
          url: Neopia.API_URL + "/pets/" + petId + "/customization",
          useCSRFProtection: false
        });
      },
      get: function(petId) {
        return this.request(petId, "GET");
      },
      post: function(petId) {
        return this.request(petId, "POST");
      }
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

  var ImpressUser = (function() {
    var userSignedIn = ($('meta[name=user-signed-in]').attr('content') === 'true');
    if (userSignedIn) {
      var currentUserId = $('meta[name=current-user-id').attr('content');
      return {
        addNeopetsUsername: function(username) {
          return $.ajax({
            url: '/user/' + currentUserId + '/neopets-connections',
            type: 'POST',
            data: {neopets_connection: {neopets_username: username}}
          });
        },
        removeNeopetsUsername: function(username) {
          return $.ajax({
            url: '/user/' + currentUserId + '/neopets-connections/' + encodeURIComponent(username),
            type: 'POST',
            data: {_method: 'DELETE'}
          });
        },
        getNeopetsUsernames: function() {
          return JSON.parse($('#modeling-neopets-users').attr('data-usernames'));
        }
      };
    } else {
      return {
        _key: "guestNeopetsUsernames",
        _setNeopetsUsernames: function(usernames) {
          localStorage.setItem(this._key, JSON.stringify(usernames));
        },
        addNeopetsUsername: function(username) {
          this._setNeopetsUsernames(this.getNeopetsUsernames().concat([username]));
        },
        removeNeopetsUsername: function(username) {
          this._setNeopetsUsernames(this.getNeopetsUsernames().filter(function(u) {
            return u !== username;
          }));
        },
        getNeopetsUsernames: function() {
          return JSON.parse(localStorage.getItem(this._key)) || [];
        }
      };
    }
  })();

  var Modeling = {
    _customizationsByPetId: {},
    _customizations: [],
    _itemsById: {},
    _items: [],
    _usersComponent: {setState: function() {}},
    _neopetsUsernamesPresenceMap: {},
    _addCustomization: function(customization) {
      // Set all equipped, interesting items' statuses as success and cross
      // them off the list.
      var itemsById = this._itemsById;
      var equippedByZone = customization.custom_pet.equipped_by_zone;
      var closetItems = customization.closet_items;
      Object.keys(equippedByZone).forEach(function(zoneId) {
        var equippedClosetId = equippedByZone[zoneId].closet_obj_id;
        var equippedObjectId = closetItems[equippedClosetId].obj_info_id;
        if (itemsById.hasOwnProperty(equippedObjectId)) {
          customization.statusByItemId[equippedObjectId] = "success";
          itemsById[equippedObjectId].el.find("span[data-body-id=" +
            customization.custom_pet.body_id + "]").addClass("modeled")
            .attr("title", I18n.modeledBodyTitle);
        }
      });
      this._customizationsByPetId[customization.custom_pet.name] = customization;
      this._customizations = this._buildCustomizations();
      this._updateCustomizations();
    },
    _addNewCustomization: function(customization) {
      customization.loadingForItemId = null;
      customization.statusByItemId = {};
      this._addCustomization(customization);
    },
    _buildCustomizations: function() {
      var modelCustomizationsByPetId = this._customizationsByPetId;
      return Object.keys(modelCustomizationsByPetId).map(function(petId) {
        return modelCustomizationsByPetId[petId];
      });
    },
    _createItems: function($) {
      var itemsById = this._itemsById;
      this._items = $('#newest-unmodeled-items li').map(function() {
        var el = $(this);
        var item = {
          el: el,
          id: el.attr('data-item-id'),
          name: el.find('h2').text(),
          missingBodyIdsPresenceMap: el.find('span[data-body-id]').toArray().reduce(function(map, node) {
            map[$(node).attr('data-body-id')] = true;
            return map;
          }, {})
        };
        item.component = React.renderComponent(<ModelForItem item={item} />,
                                               el.find('.models').get(0));
        itemsById[item.id] = item;
        return item;
      }).toArray();
    },
    _loadPetCustomization: function(neopiaPetId) {
      return Neopia.Customization.get(neopiaPetId)
        .done(this._addNewCustomization.bind(this))
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
    _startLoading: function(neopiaPetId, itemId) {
      var customization = this._customizationsByPetId[neopiaPetId];
      customization.loadingForItemId = itemId;
      customization.statusByItemId[itemId] = "loading";
      this._updateCustomizations();
    },
    _stopLoading: function(neopiaPetId, itemId, status) {
      var customization = this._customizationsByPetId[neopiaPetId];
      customization.loadingForItemId = null;
      customization.statusByItemId[itemId] = status;
      this._updateCustomizations();
    },
    _updateCustomizations: function() {
      var neopetsUsernamesPresenceMap = this._neopetsUsernamesPresenceMap;
      var liveCustomizations = this._customizations.filter(function(c) {
        return neopetsUsernamesPresenceMap[c.custom_pet.owner];
      });
      this._items.forEach(function(item) {
        var filteredCustomizations = liveCustomizations.filter(function(c) {
          return item.missingBodyIdsPresenceMap[c.custom_pet.body_id];
        });
        item.component.setState({customizations: filteredCustomizations});
      });
    },
    _updateUsernames: function() {
      var usernames = Object.keys(this._neopetsUsernamesPresenceMap);
      this._usersComponent.setState({usernames: usernames});
    },
    init: function($) {
      Neopia.init();
      this._createItems($);
      var usersEl = $('#modeling-neopets-users');
      this._usersComponent = React.renderComponent(<NeopetsUsernamesForm />,
                                                   usersEl.get(0));
      var usernames = ImpressUser.getNeopetsUsernames();
      usernames.forEach(this._registerUsername.bind(this));
      this._updateUsernames();
    },
    model: function(neopiaPetId, itemId) {
      var oldCustomization = this._customizationsByPetId[neopiaPetId];
      var itemsById = this._itemsById;
      this._startLoading(neopiaPetId, itemId);
      return Neopia.Customization.post(neopiaPetId)
        .done(function(newCustomization) {
          // Add this field as null for consistency.
          newCustomization.loadingForItemId = null;

          // Copy previous statuses.
          newCustomization.statusByItemId = oldCustomization.statusByItemId;

          // Set the attempted item's status as unworn (to possibly be
          // overridden by the upcoming loop in _addCustomization).
          newCustomization.statusByItemId[itemId] = "unworn";

          // Now, finally, let's overwrite the old customization with the new.
          Modeling._addCustomization(newCustomization);
        })
        .fail(function() {
          Modeling._stopLoading(neopiaPetId, itemId, "error");
        });
    },
    _registerUsername: function(username) {
      this._neopetsUsernamesPresenceMap[username] = true;
      this._loadUserCustomizations(username);
      this._updateUsernames();
    },
    addUsername: function(username) {
      if (typeof this._neopetsUsernamesPresenceMap[username] === 'undefined') {
        ImpressUser.addNeopetsUsername(username);
        this._registerUsername(username);
      }
    },
    removeUsername: function(username) {
      if (this._neopetsUsernamesPresenceMap[username]) {
        ImpressUser.removeNeopetsUsername(username);
        delete this._neopetsUsernamesPresenceMap[username];
        this._updateCustomizations();
        this._updateUsernames();
      }
    }
  };

  var ModelForItem = React.createClass({
    getInitialState: function() {
      return {customizations: []};
    },
    render: function() {
      var item = this.props.item;
      function createModelPet(customization) {
        return <ModelPet customization={customization}
                         item={item}
                         key={customization.custom_pet.name} />;
      }
      var sortedCustomizations = this.state.customizations.slice(0).sort(function(a, b) {
        var aName = a.custom_pet.name.toLowerCase();
        var bName = b.custom_pet.name.toLowerCase();
        if (aName < bName) return -1;
        if (aName > bName) return 1;
        return 0;
      });
      return <ul>{sortedCustomizations.map(createModelPet)}</ul>;
    }
  });

  var ModelPet = React.createClass({
    render: function() {
      var petName = this.props.customization.custom_pet.name;
      var status = this.props.customization.statusByItemId[this.props.item.id];
      var loadingForItemId = this.props.customization.loadingForItemId;
      var disabled = (status === "loading"
                   || status === "success");
      if (loadingForItemId !== null && loadingForItemId !== this.props.item.id) {
        disabled = true;
      }
      var itemName = this.props.item.name;
      var imageSrc = "http://pets.neopets.com/cpn/" + petName + "/1/1.png?" +
        this.appearanceQuery();
      var title = I18n.pet.title
        .replace(/%{pet}/g, petName)
        .replace(/%{item}/g, itemName);
      var statusMessage = I18n.pet.status[status] || "";
      return <li data-status={status}><button onClick={this.handleClick} title={title} disabled={disabled}>
        <img src={imageSrc} />
        <div>
          <span className="pet-name">{petName}</span>
          <span className="message">{statusMessage}</span>
        </div>
      </button></li>;
    },
    handleClick: function(e) {
      Modeling.model(this.props.customization.custom_pet.name, this.props.item.id);
    },
    appearanceQuery: function() {
      // By appending this string to the image URL, we update it when and only
      // when the pet's appearance has changed.
      var assetIdByZone = {};
      var biologyByZone = this.props.customization.custom_pet.biology_by_zone;
      var biologyPartIds = Object.keys(biologyByZone).forEach(function(zone) {
        assetIdByZone[zone] = biologyByZone[zone].part_id;
      });
      var equippedByZone = this.props.customization.custom_pet.equipped_by_zone;
      var equippedAssetIds = Object.keys(equippedByZone).forEach(function(zone) {
        assetIdByZone[zone] = equippedByZone[zone].asset_id;
      });
      // Sort the zones, so the string (which should match exactly when the
      // appearance matches) isn't dependent on iteration order.
      return Object.keys(assetIdByZone).sort().map(function(zone) {
        return "zone[" + zone + "]=" + assetIdByZone[zone];
      }).join("&");
    }
  });

  var NeopetsUsernamesForm = React.createClass({
    getInitialState: function() {
      return {usernames: [], newUsername: ""};
    },
    render: function() {
      function buildUsernameItem(username) {
        return <NeopetsUsernameItem username={username} key={username} />;
      }
      return <div>
        <ul>{this.state.usernames.slice(0).sort().map(buildUsernameItem)}</ul>
          <form onSubmit={this.handleSubmit}>
            <input type="text" placeholder={I18n.neopetsUsernamesForm.label}
                   onChange={this.handleChange}
                   value={this.state.newUsername} />
            <button type="submit">{I18n.neopetsUsernamesForm.submit}</button></form></div>;
    },
    handleChange: function(e) {
      this.setState({newUsername: e.target.value});
    },
    handleSubmit: function(e) {
      e.preventDefault();
      this.state.newUsername = $.trim(this.state.newUsername);
      if (this.state.newUsername.length) {
        Modeling.addUsername(this.state.newUsername);
        this.setState({newUsername: ""});
      }
    }
  });

  var NeopetsUsernameItem = React.createClass({
    render: function() {
      return <li>{this.props.username} <button onClick={this.handleClick}>×</button></li>
    },
    handleClick: function(e) {
      Modeling.removeUsername(this.props.username);
    }
  });

  Modeling.init($);
})(jQuery, ModelingI18n);
