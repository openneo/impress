// When we load in a new preview, set the status on the images. We use this in
// our CSS to show a loading state when needed.
function setImageStatuses() {
	for (const layer of document.querySelectorAll(".outfit-layer")) {
		const isLoaded = layer.querySelector("img").complete;
		layer.setAttribute("data-status", isLoaded ? "loaded" : "loading");
	}
}
document.addEventListener("turbo:frame-render", () => setImageStatuses());
document.addEventListener("turbo:load", () => setImageStatuses());

// When a preview image loads or fails, update its status. (Note that `load`
// does not fire for images that were loaded from cache, which is why we need
// both this and `setImageStatuses` when rendering new images!)
document.addEventListener(
	"load",
	({ target }) => {
		if (target.matches(".outfit-layer img")) {
			target.closest(".outfit-layer").setAttribute("data-status", "loaded");
		}
	},
	{ capture: true },
);
document.addEventListener(
	"error",
	({ target }) => {
		if (target.matches(".outfit-layer img")) {
			target.closest(".outfit-layer").setAttribute("data-status", "error");
		}
	},
	{ capture: true },
);
