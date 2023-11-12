(function () {
  // don't need to export anything in here

  var preview_el = $("#pet-preview"),
    img_el = preview_el.find("img"),
    response_el = preview_el.find("span");

  var defaultPreviewUrl = img_el.attr("src");

  preview_el.click(function () {
    Preview.Job.current.visit();
  });

  var Preview = {
    clear: function () {
      if (typeof Preview.Job.fallback != "undefined")
        Preview.Job.fallback.setAsCurrent();
    },
    displayLoading: function () {
      preview_el.addClass("loading");
      response_el.text("Loading...");
    },
    failed: function () {
      preview_el.addClass("hidden");
    },
    notFound: function (key, options) {
      Preview.failed();
      response_el.empty();
      $("#preview-" + key + "-template")
        .tmpl(options)
        .appendTo(response_el);
    },
    updateWithName: function (name_el) {
      var name = name_el.val(),
        job;
      if (name) {
        currentName = name;
        if (!Preview.Job.current || name != Preview.Job.current.name) {
          job = new Preview.Job.Name(name);
          job.setAsCurrent();
          Preview.displayLoading();
        }
      } else {
        Preview.clear();
      }
    },
  };

  function loadNotable() {
    // TODO: add HTTPS to notables
    // $.getJSON('https://notables.openneo.net/api/1/days/ago/1?callback=?', function (response) {
    //   var notables = response.notables;
    //   var i = Math.floor(Math.random() * notables.length);
    //   Preview.Job.fallback = new Preview.Job.Name(notables[i].petName);
    //   if(!Preview.Job.current) {
    //     Preview.Job.fallback.setAsCurrent();
    //   }
    // });
    if (!Preview.Job.current) {
      Preview.Job.fallback.setAsCurrent();
    }
  }

  function loadFeature() {
    $.getJSON("/donations/features", function (features) {
      if (features.length > 0) {
        var feature = features[Math.floor(Math.random() * features.length)];
        Preview.Job.fallback = new Preview.Job.Feature(feature);
        if (!Preview.Job.current) {
          Preview.Job.fallback.setAsCurrent();
        }
      } else {
        loadNotable();
      }
    });
  }

  loadFeature();

  Preview.Job = function (key, base) {
    var job = this,
      quality = 2;
    job.loading = false;

    function getImageSrc() {
      if (key.substr(0, 3) === "a:-") {
        // lol lazy code for prank image :P
        // TODO: HTTPS?
        return (
          "https://swfimages.impress.openneo.net" +
          "/biology/000/000/0-2/" +
          key.substr(2) +
          "/300x300.png"
        );
      } else if (base === "cp" || base === "cpn") {
        return petImage(base + "/" + key, quality);
      } else if (base === "url") {
        return key;
      } else {
        throw new Error("unrecognized image base " + base);
      }
    }

    function load() {
      job.loading = true;
      img_el.attr("src", getImageSrc());
    }

    this.increaseQualityIfPossible = function () {
      if (quality == 2) {
        quality = 4;
        load();
      }
    };

    this.setAsCurrent = function () {
      Preview.Job.current = job;
      load();
    };

    this.notFound = function () {
      Preview.notFound("pet-not-found");
    };
  };

  Preview.Job.Name = function (name) {
    this.name = name;
    Preview.Job.apply(this, [name, "cpn"]);

    this.visit = function () {
      $(".main-pet-name").val(this.name).closest("form").submit();
    };
  };

  Preview.Job.Hash = function (hash, form) {
    Preview.Job.apply(this, [hash, "cp"]);

    this.visit = function () {
      window.location =
        "/wardrobe?color=" +
        form.find(".color").val() +
        "&species=" +
        form.find(".species").val();
    };
  };

  Preview.Job.Feature = function (feature) {
    Preview.Job.apply(this, [feature.outfit_image_url, "url"]);
    this.name = "Thanks for donating, " + feature.donor_name + "!"; // TODO: i18n

    this.visit = function () {
      window.location = "/donate";
    };

    this.notFound = function () {
      // The outfit thumbnail hasn't generated or is missing or something.
      // Let's fall back to a boring image for now.
      var boring = new Preview.Job.Feature({
        donor_name: feature.donor_name,
        outfit_image_url: defaultPreviewUrl,
      });
      boring.setAsCurrent();
    };
  };

  $(function () {
    var previewWithNameTimeout;

    var name_el = $(".main-pet-name");
    name_el.val(PetQuery.name);
    Preview.updateWithName(name_el);

    name_el.keyup(function () {
      if (previewWithNameTimeout) {
        clearTimeout(previewWithNameTimeout);
        Preview.Job.current.loading = false;
      }
      var name_el = $(this);
      previewWithNameTimeout = setTimeout(function () {
        Preview.updateWithName(name_el);
      }, 250);
    });

    img_el
      .load(function () {
        if (Preview.Job.current.loading) {
          Preview.Job.loading = false;
          Preview.Job.current.increaseQualityIfPossible();
          preview_el
            .removeClass("loading")
            .removeClass("hidden")
            .addClass("loaded");
          response_el.text(Preview.Job.current.name);
        }
      })
      .error(function () {
        if (Preview.Job.current.loading) {
          Preview.Job.loading = false;
          Preview.Job.current.notFound();
        }
      });

    $(".species, .color").change(function () {
      var type = {},
        nameComponents = {};
      var form = $(this).closest("form");
      form.find("select").each(function () {
        var el = $(this),
          selectedEl = el.children(":selected"),
          key = el.attr("name");
        type[key] = selectedEl.val();
        nameComponents[key] = selectedEl.text();
      });
      name = nameComponents.color + " " + nameComponents.species;
      Preview.displayLoading();
      $.ajax({
        url:
          "/species/" +
          type.species +
          "/colors/" +
          type.color +
          "/pet_type.json",
        dataType: "json",
        success: function (data) {
          var job;
          if (data) {
            job = new Preview.Job.Hash(data.image_hash, form);
            job.name = name;
            job.setAsCurrent();
          } else {
            Preview.notFound("pet-type-not-found", {
              color_name: nameComponents.color,
              species_name: nameComponents.species,
            });
          }
        },
      });
    });

    $(".load-pet-to-wardrobe").submit(function (e) {
      if ($(this).find(".main-pet-name").val() === "" && Preview.Job.current) {
        e.preventDefault();
        Preview.Job.current.visit();
      }
    });
  });

  $("#latest-contribution-created-at").timeago();
})();
