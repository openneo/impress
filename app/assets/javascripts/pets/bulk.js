/* Bulk pets form */
(function () {
	var form = $("#bulk-pets-form"),
		queue_el = form.find("ul"),
		names_el = form.find("textarea"),
		add_el = $("#bulk-pets-form-add"),
		clear_el = $("#bulk-pets-form-clear"),
		bulk_load_queue;

	$(document.body).addClass("js");

	function petThumbnailUrl(pet_name) {
		// if first character is "@", use the hash url
		if (pet_name[0] == "@") {
			return "https://pets.neopets.com/cp/" + pet_name.substr(1) + "/1/1.png";
		}

		return "https://pets.neopets.com/cpn/" + pet_name + "/1/1.png";
	}

	bulk_load_queue = new (function BulkLoadQueue() {
		var RECENTLY_SENT_INTERVAL_IN_SECONDS = 30;
		var RECENTLY_SENT_MAX = 3;
		var pets = [],
			url = form.attr("action") + ".json",
			recently_sent_count = 0,
			loading = false;

		function Pet(name) {
			var el = $("#bulk-pets-submission-template")
				.tmpl({ pet_name: name, pet_thumbnail: petThumbnailUrl(name) })
				.appendTo(queue_el);

			this.load = function () {
				el.removeClass("waiting").addClass("loading");
				var response_el = el.find("span.response");
				pets.shift();
				loading = true;
				$.ajax({
					beforeSend: (xhr) => {
						const token = document
							.querySelector('meta[name="csrf-token"]')
							?.getAttribute("content");
						xhr.setRequestHeader("X-CSRF-Token", token);
					},
					complete: function (data) {
						loading = false;
						loadNextIfReady();
					},
					data: { name: name },
					dataType: "json",
					error: function (xhr) {
						el.removeClass("loading").addClass("failed");
						response_el.text(xhr.responseText);
					},
					success: function (data) {
						var points = data.points;
						el.removeClass("loading").addClass("loaded");
						$("#bulk-pets-submission-success-template")
							.tmpl({ points: points })
							.appendTo(response_el);
					},
					type: "post",
					url: url,
				});

				recently_sent_count++;
				setTimeout(function () {
					recently_sent_count--;
					loadNextIfReady();
				}, RECENTLY_SENT_INTERVAL_IN_SECONDS * 1000);
			};
		}

		this.add = function (name) {
			name = name.replace(/^\s+|\s+$/g, "");
			if (name.length) {
				var pet = new Pet(name);
				pets.push(pet);
				if (pets.length == 1) loadNextIfReady();
			}
		};

		function loadNextIfReady() {
			if (!loading && recently_sent_count < RECENTLY_SENT_MAX && pets.length) {
				pets[0].load();
			}
		}
	})();

	names_el.keyup(function () {
		var names = this.value.split("\n"),
			x = names.length - 1,
			i,
			name;
		for (i = 0; i < x; i++) {
			bulk_load_queue.add(names[i]);
		}
		this.value = x >= 0 ? names[x] : "";
	});

	add_el.click(function () {
		bulk_load_queue.add(names_el.val());
		names_el.val("");
	});

	clear_el.click(function () {
		queue_el.children("li.loaded, li.failed").remove();
	});
})();
