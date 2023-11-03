import React from "react";
import { useToast } from "@chakra-ui/react";

import { emptySearchQuery } from "./SearchToolbar";
import ItemsAndSearchPanels from "./ItemsAndSearchPanels";
import SearchFooter from "./SearchFooter";
import useOutfitSaving from "./useOutfitSaving";
import useOutfitState, { OutfitStateContext } from "./useOutfitState";
import WardrobePageLayout from "./WardrobePageLayout";
import WardrobePreviewAndControls from "./WardrobePreviewAndControls";

/**
 * WardrobePage is the most fun page on the site - it's where you create
 * outfits!
 *
 * This page has two sections: the OutfitPreview, where we show the outfit as a
 * big image; and the ItemsAndSearchPanels, which let you manage which items
 * are in the outfit and find new ones.
 *
 * This component manages shared outfit state, and the fullscreen responsive
 * page layout.
 */
function WardrobePage() {
  const toast = useToast();
  const { loading, error, outfitState, dispatchToOutfit } = useOutfitState();

  const [searchQuery, setSearchQuery] = React.useState(emptySearchQuery);

  // We manage outfit saving up here, rather than at the point of the UI where
  // "Saving" indicators appear. That way, auto-saving still happens even when
  // the indicator isn't on the page, e.g. when searching.
  // NOTE: This only applies to navigations leaving the wardrobe-2020 app, not
  // within!
  const outfitSaving = useOutfitSaving(outfitState, dispatchToOutfit);

  // TODO: I haven't found a great place for this error UI yet, and this case
  // isn't very common, so this lil toast notification seems good enough!
  React.useEffect(() => {
    if (error) {
      console.error(error);
      toast({
        title: "We couldn't load this outfit 😖",
        description: "Please reload the page to try again. Sorry!",
        status: "error",
        isClosable: true,
        duration: 999999999,
      });
    }
  }, [error, toast]);

  // For new outfits, we only block navigation while saving. For existing
  // outfits, we block navigation while there are any unsaved changes.
  const shouldBlockNavigation =
    outfitSaving.canSaveOutfit &&
    ((outfitSaving.isNewOutfit && outfitSaving.isSaving) ||
      (!outfitSaving.isNewOutfit && !outfitSaving.latestVersionIsSaved));

  // In addition to a <Prompt /> for client-side nav, we need to block full nav!
  React.useEffect(() => {
    if (shouldBlockNavigation) {
      const onBeforeUnload = (e) => {
        // https://developer.mozilla.org/en-US/docs/Web/API/WindowEventHandlers/onbeforeunload#example
        e.preventDefault();
        e.returnValue = "";
      };

      window.addEventListener("beforeunload", onBeforeUnload);
      return () => window.removeEventListener("beforeunload", onBeforeUnload);
    }
  }, [shouldBlockNavigation]);

  const title = `${outfitState.name || "Untitled outfit"} | Dress to Impress`;
  React.useEffect(() => {
    document.title = title;
  }, [title]);

  // NOTE: Most components pass around outfitState directly, to make the data
  //       relationships more explicit... but there are some deep components
  //       that need it, where it's more useful and more performant to access
  //       via context.
  return (
    <OutfitStateContext.Provider value={outfitState}>
      <WardrobePageLayout
        previewAndControls={
          <WardrobePreviewAndControls
            isLoading={loading}
            outfitState={outfitState}
            dispatchToOutfit={dispatchToOutfit}
          />
        }
        itemsAndMaybeSearchPanel={
          <ItemsAndSearchPanels
            loading={loading}
            searchQuery={searchQuery}
            onChangeSearchQuery={setSearchQuery}
            outfitState={outfitState}
            outfitSaving={outfitSaving}
            dispatchToOutfit={dispatchToOutfit}
          />
        }
        searchFooter={
          <SearchFooter
            searchQuery={searchQuery}
            onChangeSearchQuery={setSearchQuery}
            outfitState={outfitState}
          />
        }
      />
    </OutfitStateContext.Provider>
  );
}

export default WardrobePage;
