// <click-to-copy value="..."> — copies its `value` attribute to the clipboard
// when clicked, then briefly toggles a `.copied` class for visual feedback.
// (We use a class rather than `:state(copied)` because Safari's CustomStateSet
// has been flaky for us historically — see commit ff3dd224.)
class ClickToCopy extends HTMLElement {
	#resetTimer;

	connectedCallback() {
		this.setAttribute("role", "button");
		this.setAttribute("tabindex", "0");
		if (!this.hasAttribute("title")) {
			this.setAttribute("title", "Click to copy");
		}
		this.addEventListener("click", this.#handleActivate);
		this.addEventListener("keydown", this.#handleKeyDown);
	}

	disconnectedCallback() {
		this.removeEventListener("click", this.#handleActivate);
		this.removeEventListener("keydown", this.#handleKeyDown);
		clearTimeout(this.#resetTimer);
	}

	#handleKeyDown = (event) => {
		if (event.key === "Enter" || event.key === " ") {
			event.preventDefault();
			this.#handleActivate();
		}
	};

	#handleActivate = async () => {
		const value = this.getAttribute("value") ?? "";
		try {
			await navigator.clipboard.writeText(value);
			this.#flashCopied();
		} catch (error) {
			console.error("Could not copy to clipboard:", error);
		}
	};

	#flashCopied() {
		this.classList.add("copied");
		clearTimeout(this.#resetTimer);
		this.#resetTimer = setTimeout(() => {
			this.classList.remove("copied");
		}, 1500);
	}
}

customElements.define("click-to-copy", ClickToCopy);
