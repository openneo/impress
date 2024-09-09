document.addEventListener("change", ({ target }) => {
	if (target.matches('select[name="closet_list[visibility]"]')) {
		target.closest("form").setAttribute("data-list-visibility", target.value);
	}
});
