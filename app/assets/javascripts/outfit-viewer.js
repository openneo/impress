class OutfitLayer extends HTMLElement {
	#internals;

	constructor() {
		super();
		this.#internals = this.attachInternals();

		// An <outfit-layer> starts in the loading state, and then might very
		// quickly decide it's not after `#connectToChildren`. This is to prevent a
		// flash of *non*-loading state, when a new layer loads in. (e.g. In the
		// time between our parent <turbo-frame> loading, which shows the loading
		// spinner; and us being marked `:state(loading)`, which shows the loading
		// spinner; we don't want the loading spinner to do its usual *immediate*
		// total fade-out; then have to fade back in again, on the usual delay.)
		this.#setStatus("loading");
	}

	connectedCallback() {
		setTimeout(() => this.#connectToChildren(), 0);
	}

	disconnectedCallback() {
		window.removeEventListener("message", this.#onMessage);
	}

	#connectToChildren() {
		const image = this.querySelector("img");
		const iframe = this.querySelector("iframe");

		if (image) {
			image.addEventListener("load", () => this.#setStatus("loaded"));
			image.addEventListener("error", () => this.#setStatus("error"));
			this.#setStatus(image.complete ? "loaded" : "loading");
		} else if (iframe) {
			this.iframe = iframe;
			window.addEventListener("message", (m) => this.#onMessage(m));
			this.iframe.addEventListener("error", () => this.#setStatus("error"));
			this.#setStatus("loading");
		} else {
			throw new Error(`<outfit-layer> must contain an <img> or <iframe> tag`);
		}
	}

	#onMessage({ source, data }) {
		if (source !== this.iframe.contentWindow) {
			return;
		}

		if (data.type === "status" && ["loaded", "error"].includes(data.status)) {
			this.#setStatus(data.status);
		} else {
			throw new Error(
				`<outfit-layer> got unexpected message: ${JSON.stringify(data)}`,
			);
		}
	}

	#setStatus(newStatus) {
		this.#internals.states.clear();
		this.#internals.states.add(newStatus);
	}
}

customElements.define("outfit-layer", OutfitLayer);

// Morph turbo-frames on this page, to reuse asset nodes when we want to—very
// important for movies!—but ensure that it *doesn't* do its usual behavior of
// aggressively reusing existing <outfit-layer> nodes for entirely different
// assets. (It's a lot clearer for managing the loading state, and not showing
// old incorrect layers!) (We also tried using `id` to enforce this… no luck.)
addEventListener("turbo:before-frame-render", (event) => {
	if (typeof Idiomorph !== "undefined") {
		event.detail.render = (currentElement, newElement) => {
			Idiomorph.morph(currentElement, newElement.innerHTML, {
				morphStyle: "innerHTML",
				callbacks: {
					beforeNodeMorphed: (currentNode, newNode) => {
						// If Idiomorph wants to transform an <outfit-layer> to
						// have a different data-asset-id attribute, we replace
						// the node ourselves and abort the morph.
						if (
							newNode.tagName === "OUTFIT-LAYER" &&
							newNode.getAttribute("data-asset-id") !==
								currentNode.getAttribute("data-asset-id")
						) {
							currentNode.replaceWith(newNode);
							return false;
						}
					},
				},
			});
		};
	}
});
