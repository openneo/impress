(function () {
	function petImage(id, size) {
		return "https://pets.neopets.com/" + id + "/1/" + size + ".png";
	}

	var PetQuery = {},
		query_string = (document.location.hash || document.location.search).replace(
			/^#/,
			"",
		);

	for (const [key, value] of new URLSearchParams(query_string).entries()) {
		PetQuery[key] = value;
	}

	if (PetQuery.name) {
		if (PetQuery.species && PetQuery.color) {
			var image_url = petImage("cpn/" + PetQuery.name, 1);
			if (PetQuery.name.startsWith("@")) {
				image_url = petImage("cp/" + PetQuery.name.substr(1), 1);
			}
			$("#pet-query-notice-template")
				.tmpl({
					pet_name: PetQuery.name,
					pet_image_url: image_url,
				})
				.prependTo("#container");
		}
	}

	var preview_el = $("#pet-preview"),
		img_el = preview_el.find("img"),
		response_el = preview_el.find("span");

	var defaultPreviewUrl = img_el.attr("src");

	preview_el.click(function () {
		var job = Preview.visitableJob();
		if (job) job.visit();
	});

	// Bumped whenever the preview moves on to something new, so that a slow
	// pet type lookup doesn't clobber whatever the user has done since.
	var petTypeRequestId = 0;

	var Preview = {
		// Stop listening for the current job's image, if it's still in flight.
		cancelCurrent: function () {
			if (Preview.Job.current) Preview.Job.current.loading = false;
		},
		clear: function () {
			petTypeRequestId++;
			if (typeof Preview.Job.fallback != "undefined") {
				Preview.Job.fallback.setAsCurrent();
			} else {
				// Nothing to fall back to (yet), so go back to the blank preview.
				// If a feature arrives later, `loadFeature` will show it.
				Preview.cancelCurrent();
				Preview.Job.current = undefined;
				img_el.attr("src", defaultPreviewUrl);
				preview_el.removeClass("loading loaded hidden");
				response_el.empty();
			}
		},
		displayLoading: function () {
			preview_el.addClass("loading");
			response_el.text("Loading...");
		},
		failed: function () {
			// The failed job isn't on screen anymore, so forget it. That way, the
			// user can retry it, rather than `updateWithName` thinking it's shown.
			Preview.cancelCurrent();
			Preview.Job.current = undefined;
			preview_el.removeClass("loading loaded").addClass("hidden");
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
				if (!Preview.Job.current || name != Preview.Job.current.name) {
					petTypeRequestId++;
					job = new Preview.Job.Name(name);
					job.setAsCurrent();
					Preview.displayLoading();
				}
			} else {
				Preview.clear();
			}
		},
		// The job whose preview is on screen, if any, for clicks and submits.
		visitableJob: function () {
			return preview_el.hasClass("loaded") ? Preview.Job.current : undefined;
		},
	};

	function loadFeature() {
		$.getJSON("/donations/features", function (features) {
			if (features.length > 0) {
				var feature = features[Math.floor(Math.random() * features.length)];
				Preview.Job.fallback = new Preview.Job.Feature(feature);
				// Show it if nothing else is showing, but don't replace an error
				// message (which is shown with the `hidden` class).
				if (!Preview.Job.current && !preview_el.hasClass("hidden")) {
					Preview.Job.fallback.setAsCurrent();
				}
			}
		});
	}

	loadFeature();

	Preview.Job = function (key, base) {
		var job = this,
			quality = 2;
		job.loading = false;

		function getImageSrc() {
			if (base === "cp" || base === "cpn") {
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
			// If another job's image is still in flight, it's been replaced, so
			// its load/error events should no longer count.
			if (Preview.Job.current !== job) Preview.cancelCurrent();
			Preview.Job.current = job;
			load();
		};

		this.notFound = function () {
			Preview.notFound("pet-not-found");
		};
	};

	Preview.Job.Name = function (name) {
		this.name = name;
		if (name.startsWith("@")) {
			// This is an image hash "pet name".
			Preview.Job.apply(this, [name.substr(1), "cp"]);
		} else {
			// This is a normal pet name.
			Preview.Job.apply(this, [name, "cpn"]);
		}

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
			if (feature.outfit_image_url === defaultPreviewUrl) {
				// Even the boring image failed! Don't keep retrying it forever.
				Preview.failed();
				response_el.text(this.name);
				return;
			}

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
		// Setting `undefined` would clear a name the browser restored for us.
		if (PetQuery.name) name_el.val(PetQuery.name);
		Preview.updateWithName(name_el);

		// `input` (rather than `keyup`) also catches pasting, autofill, etc, and
		// skips keys that don't change the value, like Shift and arrow keys.
		name_el.bind("input", function () {
			clearTimeout(previewWithNameTimeout);
			var name_el = $(this);
			previewWithNameTimeout = setTimeout(function () {
				Preview.updateWithName(name_el);
			}, 250);
		});

		img_el
			.load(function () {
				// The default preview image can finish loading before any job has
				// started, so there may not be a current job yet.
				if (Preview.Job.current && Preview.Job.current.loading) {
					Preview.Job.current.loading = false;
					Preview.Job.current.increaseQualityIfPossible();
					preview_el
						.removeClass("loading")
						.removeClass("hidden")
						.addClass("loaded");
					response_el.text(Preview.Job.current.name);
				}
			})
			.error(function () {
				if (Preview.Job.current && Preview.Job.current.loading) {
					Preview.Job.current.loading = false;
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
			var name = nameComponents.color + " " + nameComponents.species;
			var requestId = ++petTypeRequestId;
			// Don't let the previous job's image finish and replace "Loading...".
			Preview.cancelCurrent();
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
					if (requestId !== petTypeRequestId) return;
					var job = new Preview.Job.Hash(data.image_hash, form);
					job.name = name;
					job.setAsCurrent();
				},
				error: function (xhr) {
					if (requestId !== petTypeRequestId) return;
					if (xhr.status === 404) {
						Preview.notFound("pet-type-not-found", {
							color_name: nameComponents.color,
							species_name: nameComponents.species,
						});
					} else {
						Preview.notFound("load-error");
					}
				},
			});
		});

		$(".load-pet-to-wardrobe").submit(function (e) {
			var job = Preview.visitableJob();
			if ($(this).find(".main-pet-name").val() === "" && job) {
				e.preventDefault();
				job.visit();
			}
		});
	});

	$("#latest-contribution-created-at").timeago();
})();
