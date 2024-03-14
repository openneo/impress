function setFormStateCookie(value) {
	const thirtyDays = 60 * 60 * 24 * 30;
	document.cookie = `DTIItemPageUserListsFormState=${value};max-age=${thirtyDays}`;
}

document.addEventListener("click", (event) => {
	if (event.target.matches(".item-header .user-lists-form-opener")) {
		const header = event.target.closest(".item-header");
		const form = header.querySelector(".user-lists-form");
		if (form.hasAttribute("hidden")) {
			form.removeAttribute("hidden");
			setFormStateCookie("open");
		} else {
			form.setAttribute("hidden", "");
			setFormStateCookie("closed");
		}
		event.preventDefault();
	}
});
