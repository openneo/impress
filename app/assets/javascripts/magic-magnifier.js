class MagicMagnifier extends HTMLElement {
	#internals = this.attachInternals();

	connectedCallback() {
		setTimeout(() => this.#attachLens(), 0);
		this.addEventListener("mousemove", this.#onMouseMove);
	}

	#attachLens() {
		const lens = document.createElement("magic-magnifier-lens");
		lens.inert = true;
		lens.useContent(this.children);
		this.appendChild(lens);
	}

	#onMouseMove(e) {
		const lens = this.querySelector("magic-magnifier-lens");
		const rect = this.getBoundingClientRect();
		const x = e.clientX - rect.left;
		const y = e.clientY - rect.top;
		this.style.setProperty("--magic-magnifier-x", x + "px");
		this.style.setProperty("--magic-magnifier-y", y + "px");
		this.#internals.states.add("ready");
	}
}

class MagicMagnifierLens extends HTMLElement {
	useContent(contentNodes) {
		for (const contentNode of contentNodes) {
			this.appendChild(contentNode.cloneNode(true));
		}
	}
}

customElements.define("magic-magnifier", MagicMagnifier);
customElements.define("magic-magnifier-lens", MagicMagnifierLens);
