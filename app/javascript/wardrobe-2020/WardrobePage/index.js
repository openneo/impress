import React from "react";
import { useToast } from "@chakra-ui/react";
import { useRouter } from "next/router";

import { emptySearchQuery } from "./SearchToolbar";
import ItemsAndSearchPanels from "./ItemsAndSearchPanels";
import SearchFooter from "./SearchFooter";
import SupportOnly from "./support/SupportOnly";
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
  // the indicator isn't on the page, e.g. when searching. We also mount a
  // <Prompt /> in this component to prevent navigating away before saving.
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
    <>
      <OutfitStateContext.Provider value={outfitState}>
        <SupportOnly>
          <WardrobeDevHacks />
        </SupportOnly>

        {/*
         * TODO: This might unnecessarily block navigations that we don't
         * necessarily need to, e.g., navigating back to Your Outfits while the
         * save request is in flight. We could instead submit the save mutation
         * immediately on client-side nav, and have each outfit save mutation
         * install a `beforeunload` handler that ensures that you don't close
         * the page altogether while it's in flight. But let's start simple and
         * see how annoying it actually is in practice lol
         */}
        <Prompt
          when={shouldBlockNavigation}
          message="Are you sure you want to leave? Your changes might not be saved."
        />

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
    </>
  );
}

/**
 * SavedOutfitMetaTags renders the meta tags that we use to render pretty
 * share cards for social media for saved outfits!
 */
function SavedOutfitMetaTags({ outfitState }) {
  const updatedAtTimestamp = Math.floor(
    new Date(outfitState.updatedAt).getTime() / 1000
  );
  const imageUrl =
    `https://impress-outfit-images.openneo.net/outfits` +
    `/${encodeURIComponent(outfitState.id)}` +
    `/v/${encodeURIComponent(updatedAtTimestamp)}` +
    `/600.png`;

  return (
    <>
      <meta
        property="og:title"
        content={outfitState.name || "Untitled outfit"}
      />
      <meta property="og:type" content="website" />
      <meta property="og:image" content={imageUrl} />
      <meta property="og:url" content={outfitState.url} />
      <meta property="og:site_name" content="Dress to Impress" />
      <meta
        property="og:description"
        content="A custom Neopets outfit, designed on Dress to Impress!"
      />
    </>
  );
}

/**
 * Prompt blocks client-side navigation via Next.js when the `when` prop is
 * true. This is our attempt at a drop-in replacement for the Prompt component
 * offered by react-router!
 *
 * Adapted from https://github.com/vercel/next.js/issues/2694#issuecomment-778225625
 */
function Prompt({ when, message }) {
  const router = useRouter();
  React.useEffect(() => {
    const handleWindowClose = (e) => {
      if (!when) return;
      e.preventDefault();
      return (e.returnValue = message);
    };
    const handleBrowseAway = () => {
      if (!when) return;
      if (window.confirm(message)) return;
      router.events.emit("routeChangeError");
      throw "routeChange aborted by <Prompt>.";
    };
    window.addEventListener("beforeunload", handleWindowClose);
    router.events.on("routeChangeStart", handleBrowseAway);
    return () => {
      window.removeEventListener("beforeunload", handleWindowClose);
      router.events.off("routeChangeStart", handleBrowseAway);
    };
  }, [when, message, router]);

  return null;
}

export default WardrobePage;
