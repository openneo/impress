// When the species face picker changes, update and submit the main picker form.
document.addEventListener("change", (e) => {
    if (!e.target.matches("species-face-picker")) return;

    try {
        const mainPicker = document.querySelector("#item-preview .species-color-picker");
        const mainSpeciesField =
            mainPicker.querySelector("[name='preview[species_id]']");
        mainSpeciesField.value = e.target.value;
        mainPicker.requestSubmit(); // `submit` doesn't get captured by Turbo!
    } catch (error) {
        e.preventDefault();
        console.error("Couldn't update species picker: ", error);
    }
});

class SpeciesFacePicker extends HTMLElement {
    connectedCallback() {
        this.addEventListener("click", this.#handleClick);
    }

    get value() {
        return this.querySelector("input[type=radio]:checked")?.value;
    }

    #handleClick(e) {
        if (e.target.matches("input[type=radio]")) {
            this.dispatchEvent(new Event("change", {bubbles: true}));
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

customElements.define("species-face-picker", SpeciesFacePicker);
customElements.define("species-face-picker-options", SpeciesFacePickerOptions);
