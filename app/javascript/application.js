import "@hotwired/turbo-rails";

document.getElementById("locale").addEventListener("change", function () {
	document.getElementById("locale-form").submit();
});
