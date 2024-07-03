class OutfitLayer extends HTMLElement {
	#internals;

	constructor() {
		super();
		this.#internals = this.attachInternals();
	}

	connectedCallback() {
		setTimeout(() => this.#initializeImage(), 0);
	}

	#initializeImage() {
		this.image = this.querySelector("img");
		if (!this.image) {
			throw new Error(`<outfit-layer> must contain an <img> tag`);
		}

		this.image.addEventListener("load", () => this.#setStatus("loaded"));
		this.image.addEventListener("error", () => this.#setStatus("error"));

		this.#setStatus(this.image.complete ? "loaded" : "loading");
	}

	#setStatus(newStatus) {
		this.#internals.states.clear();
		this.#internals.states.add(newStatus);
	}
}

customElements.define("outfit-layer", OutfitLayer);
