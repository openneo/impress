class OutfitLayer extends HTMLElement {
	#internals;

	constructor() {
		super();
		this.#internals = this.attachInternals();
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
			this.#setStatus("loading");
		} else {
			throw new Error(
				`<outfit-layer> must contain an <img> or <iframe> tag`,
			);
		}
	}

	#onMessage({ source, data }) {
		if (source !== this.iframe.contentWindow) {
			return;
		}

		if (
			data.type === "status" &&
			["loaded", "error"].includes(data.status)
		) {
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
