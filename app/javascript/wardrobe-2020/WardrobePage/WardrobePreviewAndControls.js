import React from "react";
import { Box, Center, DarkMode } from "@chakra-ui/react";
import gql from "graphql-tag";
import { useQuery } from "@apollo/client";
import * as Sentry from "@sentry/react";

import OutfitThumbnail from "../components/OutfitThumbnail";
import { useOutfitPreview } from "../components/OutfitPreview";
import { loadable, MajorErrorMessage, TestErrorSender } from "../util";

const OutfitControls = loadable(() => import("./OutfitControls"));

function WardrobePreviewAndControls({
  isLoading,
  outfitState,
  dispatchToOutfit,
}) {
  // Whether the current outfit preview has animations. Determines whether we
  // show the play/pause button.
  const [hasAnimations, setHasAnimations] = React.useState(false);

  const { appearance, preview } = useOutfitPreview({
    isLoading: isLoading,
    speciesId: outfitState.speciesId,
    colorId: outfitState.colorId,
    pose: outfitState.pose,
    appearanceId: outfitState.appearanceId,
    wornItemIds: outfitState.wornItemIds,
    onChangeHasAnimations: setHasAnimations,
    placeholder: <OutfitThumbnailIfCached outfitId={outfitState.id} />,
    "data-test-id": "wardrobe-outfit-preview",
  });

  return (
    <Sentry.ErrorBoundary fallback={MajorErrorMessage}>
      <TestErrorSender />
      <Center position="absolute" top="0" bottom="0" left="0" right="0">
        <DarkMode>{preview}</DarkMode>
      </Center>
      <Box position="absolute" top="0" bottom="0" left="0" right="0">
        <OutfitControls
          outfitState={outfitState}
          dispatchToOutfit={dispatchToOutfit}
          showAnimationControls={hasAnimations}
          appearance={appearance}
        />
      </Box>
    </Sentry.ErrorBoundary>
  );
}

/**
 * OutfitThumbnailIfCached will render an OutfitThumbnail as a placeholder for
 * the outfit preview... but only if we already have the data to generate the
 * thumbnail stored in our local Apollo GraphQL cache.
 *
 * This means that, when you come from the Your Outfits page, we can show the
 * outfit thumbnail instantly while everything else loads. But on direct
 * navigation, this does nothing, and we just wait for the preview to load in
 * like usual!
 */
function OutfitThumbnailIfCached({ outfitId }) {
  const { data } = useQuery(
    gql`
      query OutfitThumbnailIfCached($outfitId: ID!) {
        outfit(id: $outfitId) {
          id
          updatedAt
        }
      }
    `,
    {
      variables: {
        outfitId,
      },
      skip: outfitId == null,
      fetchPolicy: "cache-only",
      onError: (e) => console.error(e),
    }
  );

  if (!data?.outfit) {
    return null;
  }

  return (
    <OutfitThumbnail
      outfitId={data.outfit.id}
      updatedAt={data.outfit.updatedAt}
      alt=""
      objectFit="contain"
      width="100%"
      height="100%"
      filter="blur(2px)"
    />
  );
}

export default WardrobePreviewAndControls;
