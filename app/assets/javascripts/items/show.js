// When the species face picker changes, update and submit the main picker form.
document.addEventListener("change", (e) => {
	if (!e.target.matches("species-face-picker")) return;

	try {
		const mainPickerForm = document.querySelector(
			"#item-preview species-color-picker form",
		);
		const mainSpeciesField = mainPickerForm.querySelector(
			"[name='preview[species_id]']",
		);
		mainSpeciesField.value = e.target.value;
		mainPickerForm.requestSubmit(); // `submit` doesn't get captured by Turbo!
	} catch (error) {
		console.error("Couldn't update species picker: ", error);
	}
});

// If the preview frame fails to load, try a full pageload.
document.addEventListener("turbo:frame-missing", (e) => {
	if (!e.target.matches("#item-preview")) return;

	e.detail.visit(e.detail.response.url);
	e.preventDefault();
});

class SpeciesColorPicker extends HTMLElement {
	#internals;

	constructor() {
		super();
		this.#internals = this.attachInternals();
	}

	connectedCallback() {
		// Listen for changes to auto-submit the form, then tell CSS about it!
		this.addEventListener("change", this.#handleChange);
		this.#internals.states.add("auto-loading");
	}

	#handleChange(e) {
		this.querySelector("form").requestSubmit();
	}
}

class SpeciesFacePicker extends HTMLElement {
	connectedCallback() {
		this.addEventListener("click", this.#handleClick);
	}

	get value() {
		return this.querySelector("input[type=radio]:checked")?.value;
	}

	#handleClick(e) {
		if (e.target.matches("input[type=radio]")) {
			this.dispatchEvent(new Event("change", { bubbles: true }));
		}
	}
}

class SpeciesFacePickerOptions extends HTMLElement {
	static observedAttributes = ["inert", "aria-hidden"];

	connectedCallback() {
		// Once this component is loaded, we stop being inert and aria-hidden. We're ready!
		this.#activate();
	}

	attributeChangedCallback() {
		// If a Turbo Frame tries to morph us into being inert again, activate again!
		// (It's important that the server's HTML always return `inert`, for progressive
		// enhancement; and it's important to morph this element, so radio focus state
		// is preserved. To thread that needle, we have to monitor and remove!)
		this.#activate();
	}

	#activate() {
		this.removeAttribute("inert");
		this.removeAttribute("aria-hidden");
	}
}

// TODO: If it ever gets wide support, remove this in favor of the CSS rule
//       `interpolate-size: allow-keywords`, to animate directly from `auto`.
//       https://drafts.csswg.org/css-values-5/#valdef-interpolate-size-allow-keywords
class MeasuredContainer extends HTMLElement {
	static observedAttributes = ["style"];

	connectedCallback() {
		setTimeout(() => this.#measure(), 0);
	}

	attributeChangedCallback() {
		// When `--natural-width` gets morphed away by Turbo, measure it again!
		if (this.style.getPropertyValue("--natural-width") === "") {
			this.#measure();
		}
	}

	#measure() {
		// Find our `<measured-content>` child, and set our natural width as
		// `var(--natural-width)` in the context of our CSS styles.
		const content = this.querySelector("measured-content");
		if (content == null) {
			throw new Error(`<measured-container> must contain a <measured-content>`);
		}
		this.style.setProperty("--natural-width", content.offsetWidth + "px");
	}
}

customElements.define("species-color-picker", SpeciesColorPicker);
customElements.define("species-face-picker", SpeciesFacePicker);
customElements.define("species-face-picker-options", SpeciesFacePickerOptions);
customElements.define("measured-container", MeasuredContainer);
