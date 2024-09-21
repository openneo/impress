import "@hotwired/turbo-rails";

document.addEventListener("change", (e) => {
	if (!e.target.matches("#locale")) return;
	document.getElementById("locale-form").submit();
});
