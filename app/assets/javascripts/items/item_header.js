function setFormStateCookie(value) {
	const thirtyDays = 60 * 60 * 24 * 30;
	document.cookie = `DTIItemPageUserListsFormState=open;max-age=${thirtyDays}`;
}

const headers = document.querySelectorAll(".item-header");
for (const header of headers) {
	try {
		const form = header.querySelector(".user-lists-form");
		const opener = header.querySelector(".user-lists-form-opener");
		opener.addEventListener("click", (event) => {
			if (form.hasAttribute("hidden")) {
				form.removeAttribute("hidden");
				setFormStateCookie("open");
			} else {
				form.setAttribute("hidden", "");
				setFormStateCookie("closed");
			}
			event.preventDefault();
		});
	} catch (error) {
		console.error(`Error applying dialog behavior to item header:`, error);
	}
}
