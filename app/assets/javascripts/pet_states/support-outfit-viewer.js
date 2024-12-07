class SupportOutfitViewer extends HTMLElement {
	#internals = this.attachInternals();

	connectedCallback() {
		this.addEventListener("mouseenter", this.#onMouseEnter, { capture: true });
		this.addEventListener("mouseleave", this.#onMouseLeave, { capture: true });
		this.addEventListener("click", this.#onClick);
		this.#internals.states.add("ready");
	}

	// When a row is hovered, highlight its corresponding outfit viewer layer.
	#onMouseEnter(e) {
		if (!e.target.matches("tr")) return;

		const id = e.target.querySelector("[data-field=id]").innerText;
		const layer = this.querySelector(
			`outfit-viewer [data-asset-id="${CSS.escape(id)}"]`,
		);
		layer.setAttribute("highlighted", "");
	}

	// When a row is unhovered, unhighlight its corresponding outfit viewer layer.
	#onMouseLeave(e) {
		if (!e.target.matches("tr")) return;

		const id = e.target.querySelector("[data-field=id]").innerText;
		const layer = this.querySelector(
			`outfit-viewer [data-asset-id="${CSS.escape(id)}"]`,
		);
		layer.removeAttribute("highlighted");
	}

	// When clicking a row, redirect the click to the first link.
	#onClick(e) {
		const row = e.target.closest("tr");
		if (row == null) return;

		row.querySelector("[data-field=links] a").click();
	}
}

customElements.define("support-outfit-viewer", SupportOutfitViewer);
