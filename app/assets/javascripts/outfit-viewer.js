class OutfitViewer extends HTMLElement {
	#internals;

	constructor() {
		super();
		this.#internals = this.attachInternals(); // for CSS `:state()`
	}

	connectedCallback() {
		// The `<outfit-layer>` is connected to the DOM right before its
		// children are. So, to engage with the children, wait a tick!
		setTimeout(() => this.#connectToChildren(), 0);
	}

	#connectToChildren() {
		const playPauseToggle = document.querySelector(".play-pause-toggle");

		// Read our initial playing state from the toggle, and subscribe to changes.
		this.#setIsPlaying(playPauseToggle.checked);
		playPauseToggle.addEventListener("change", () => {
			this.#setIsPlaying(playPauseToggle.checked);
			this.#setIsPlayingCookie(playPauseToggle.checked);
		});

		// Tell the CSS our first frame has rendered, which we use for loading
		// state transitions.
		this.#internals.states.add("after-first-frame");
	}

	#setIsPlaying(isPlaying) {
		// TODO: Listen for changes to the child list, and add `playing` when new
		// nodes arrive, if playing.
		const thirtyDays = 60 * 60 * 24 * 30;
		if (isPlaying) {
			this.#internals.states.add("playing");
			for (const layer of this.querySelectorAll("outfit-layer")) {
				layer.play();
			}
		} else {
			this.#internals.states.delete("playing");
			for (const layer of this.querySelectorAll("outfit-layer")) {
				layer.pause();
			}
		}
	}

	#setIsPlayingCookie(isPlaying) {
		const thirtyDays = 60 * 60 * 24 * 30;
		const value = isPlaying ? "true" : "false";
		document.cookie = `DTIOutfitViewerIsPlaying=${value};max-age=${thirtyDays}`;
	}
}

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
		// When this `<outfit-layer>` leaves the DOM, stop listening for iframe
		// messages, if we were.
		window.removeEventListener("message", this.#onMessage);
	}

	play() {
		this.#sendMessageToIframe({ type: "play" });
	}

	pause() {
		this.#sendMessageToIframe({ type: "pause" });
	}

	#connectToChildren() {
		const image = this.querySelector("img");
		const iframe = this.querySelector("iframe");

		if (image) {
			// If this is an image layer, track its loading state by listening
			// to the load/error events, and initialize based on whether it's
			// already `complete` (which it can be if it loaded from cache).
			this.#setStatus(image.complete ? "loaded" : "loading");
			image.addEventListener("load", () => this.#setStatus("loaded"));
			image.addEventListener("error", () => this.#setStatus("error"));
		} else if (iframe) {
			this.iframe = iframe;

			// Initialize status to `loading`, and asynchronously request a
			// status message from the iframe if it managed to load before this
			// triggers (impressive, but I think I've seen it happen!). Then,
			// wait for messages or error events from the iframe to update
			// status further if needed.
			this.#setStatus("loading");
			this.#sendMessageToIframe({ type: "requestStatus" });
			window.addEventListener("message", (m) => this.#onMessage(m));
			this.iframe.addEventListener("error", () =>
				this.#setStatus("error"),
			);
		} else {
			throw new Error(
				`<outfit-layer> must contain an <img> or <iframe> tag`,
			);
		}
	}

	#onMessage({ source, data }) {
		// Ignore messages that aren't from *our* frame.
		if (source !== this.iframe.contentWindow) {
			return;
		}

		// Validate the incoming status message, then set our status to match.
		if (data.type === "status") {
			if (data.status === "loaded") {
				this.#setStatus("loaded");
				this.#setHasAnimations(data.hasAnimations);
			} else if (data.status === "error") {
				this.#setStatus("error");
			} else {
				throw new Error(
					`<outfit-layer> got unexpected status: ` +
						JSON.stringify(data.status),
				);
			}
		} else {
			throw new Error(
				`<outfit-layer> got unexpected message: ` +
					JSON.stringify(data),
			);
		}
	}

	/**
	 * Set the status value that the CSS `:state()` selector will match.
	 * For example, when loading, `:state(loading)` matches this element.
	 */
	#setStatus(newStatus) {
		this.#internals.states.delete("loading");
		this.#internals.states.delete("loaded");
		this.#internals.states.delete("error");
		this.#internals.states.add(newStatus);
	}

	/**
	 * Set whether CSS selector `:state(has-animations)` matches this element.
	 */
	#setHasAnimations(hasAnimations) {
		if (hasAnimations) {
			this.#internals.states.add("has-animations");
		} else {
			this.#internals.states.delete("has-animations");
		}
	}

	#sendMessageToIframe(message) {
		// If we have no frame or it hasn't loaded, ignore this message.
		if (this.iframe == null) {
			return;
		}
		if (this.iframe.contentWindow == null) {
			console.debug(
				`Ignoring message, frame not loaded yet: `,
				this.iframe,
				message,
			);
			return;
		}

		// The frame is sandboxed (origin == null), so send to Any origin.
		this.iframe.contentWindow.postMessage(message, "*");
	}
}

customElements.define("outfit-viewer", OutfitViewer);
customElements.define("outfit-layer", OutfitLayer);

// Morph turbo-frames on this page, to reuse asset nodes when we want to—very
// important for movies!—but ensure that it *doesn't* do its usual behavior of
// aggressively reusing existing <outfit-layer> nodes for entirely different
// assets. (It's a lot clearer for managing the loading state, and not showing
// old incorrect layers!) (We also tried using `id` to enforce this… no luck.)
function morphWithOutfitLayers(currentElement, newElement) {
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
}
addEventListener("turbo:before-frame-render", (event) => {
	// Rather than enforce Idiomorph must be loaded, let's just be resilient
	// and only bother if we have it. (Replacing content is not *that* bad!)
	if (typeof Idiomorph !== "undefined") {
		event.detail.render = (a, b) => morphWithOutfitLayers(a, b);
	}
});
