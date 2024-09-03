// When the species *face* picker changes, update and submit the main picker form.
document.addEventListener("click", (e) => {
    if (!e.target.matches(".species-face-picker input[type=radio]")) return;

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
