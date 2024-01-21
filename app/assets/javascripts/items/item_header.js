const userListSections = document.querySelectorAll(
	".item-header .user-lists-section");
for (const section of userListSections) {
	try {
		const dialog = section.querySelector("dialog");
		const opener = section.querySelector(".dialog-opener");
		const closer = section.querySelector(".dialog-closer");
		if (dialog.showModal) { // check browser support
			opener.addEventListener("click", (event) => {
				dialog.show();
				event.preventDefault();
			});
			document.body.addEventListener("click", (event) => {
				if (dialog.open && !section.contains(event.target)) {
					dialog.close();
				}
			});
		}
	} catch (error) {
		console.error(`Error applying dialog behavior to item header:`, error);
	}
}
