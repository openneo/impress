import { useLocalStorage } from "../util";

/**
 * usePreferArchive helps the user choose to try using our archive before
 * using images.neopets.com, when images.neopets.com is being slow and bleh!
 */
function usePreferArchive() {
  const [preferArchiveSavedValue, setPreferArchive] = useLocalStorage(
    "DTIPreferArchive",
    null
  );

  // Oct 13 2022: I might default this back to on again if the lag gets
  // miserable again, but it's okaaay right now? ish? Bad enough that I want to
  // offer this option, but decent enough that I don't want to turn it on by
  // default and break new items yet!
  const preferArchive = preferArchiveSavedValue ?? false;

  return [preferArchive, setPreferArchive];
}

export default usePreferArchive;
