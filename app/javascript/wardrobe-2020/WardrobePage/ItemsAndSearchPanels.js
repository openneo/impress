import React from "react";
import { Box, Flex, useBreakpointValue } from "@chakra-ui/react";
import * as Sentry from "@sentry/react";

import ItemsPanel from "./ItemsPanel";
import SearchToolbar, { searchQueryIsEmpty } from "./SearchToolbar";
import SearchPanel from "./SearchPanel";
import { MajorErrorMessage, TestErrorSender, useLocalStorage } from "../util";

/**
 * ItemsAndSearchPanels manages the shared layout and state for:
 *   - ItemsPanel, which shows the items in the outfit now, and
 *   - SearchPanel, which helps you find new items to add.
 *
 * These panels don't share a _lot_ of concerns; they're mainly intertwined by
 * the fact that they share the SearchToolbar at the top!
 *
 * We try to keep the search concerns in the search components, by avoiding
 * letting any actual _logic_ live at the root here; and instead just
 * performing some wiring to help them interact with each other via simple
 * state and refs.
 */
function ItemsAndSearchPanels({
  loading,
  searchQuery,
  onChangeSearchQuery,
  outfitState,
  outfitSaving,
  dispatchToOutfit,
}) {
  const scrollContainerRef = React.useRef();
  const searchQueryRef = React.useRef();
  const firstSearchResultRef = React.useRef();

  const hasRoomForSearchFooter = useBreakpointValue({ base: false, md: true });
  const [canUseSearchFooter] = useLocalStorage(
    "DTIFeatureFlagCanUseSearchFooter",
    false
  );
  const isShowingSearchFooter = canUseSearchFooter && hasRoomForSearchFooter;

  return (
    <Sentry.ErrorBoundary fallback={MajorErrorMessage}>
      <TestErrorSender />
      <Flex direction="column" height="100%">
        {isShowingSearchFooter && <Box height="2" />}
        {!isShowingSearchFooter && (
          <Box paddingX="5" paddingTop="3" paddingBottom="2" boxShadow="sm">
            <SearchToolbar
              query={searchQuery}
              searchQueryRef={searchQueryRef}
              firstSearchResultRef={firstSearchResultRef}
              onChange={onChangeSearchQuery}
            />
          </Box>
        )}
        {!isShowingSearchFooter && !searchQueryIsEmpty(searchQuery) ? (
          <Box
            key="search-panel"
            flex="1 0 0"
            position="relative"
            overflowY="scroll"
            ref={scrollContainerRef}
            data-test-id="search-panel-scroll-container"
          >
            <SearchPanel
              query={searchQuery}
              outfitState={outfitState}
              dispatchToOutfit={dispatchToOutfit}
              scrollContainerRef={scrollContainerRef}
              searchQueryRef={searchQueryRef}
              firstSearchResultRef={firstSearchResultRef}
            />
          </Box>
        ) : (
          <Box position="relative" overflow="auto" key="items-panel">
            <Box px="4" py="2">
              <ItemsPanel
                loading={loading}
                outfitState={outfitState}
                outfitSaving={outfitSaving}
                dispatchToOutfit={dispatchToOutfit}
              />
            </Box>
          </Box>
        )}
      </Flex>
    </Sentry.ErrorBoundary>
  );
}

export default ItemsAndSearchPanels;
