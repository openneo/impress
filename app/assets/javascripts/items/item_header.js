const headers = document.querySelectorAll(".item-header");
for (const header of headers) {
	try {
		const form = header.querySelector(".user-lists-form");
		const opener = header.querySelector(".user-lists-form-opener");
		opener.addEventListener("click", (event) => {
			form.toggleAttribute("hidden");
			event.preventDefault();
		});
	} catch (error) {
		console.error(`Error applying dialog behavior to item header:`, error);
	}
}
