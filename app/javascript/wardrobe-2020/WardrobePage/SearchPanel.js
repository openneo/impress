import React from "react";
import { Box, Text, useColorModeValue, VisuallyHidden } from "@chakra-ui/react";

import Item, { ItemListContainer, ItemListSkeleton } from "./Item";
import PaginationToolbar from "../components/PaginationToolbar";
import { useSearchResults } from "./useSearchResults";

export const SEARCH_PER_PAGE = 30;

/**
 * SearchPanel shows item search results to the user, so they can preview them
 * and add them to their outfit!
 *
 * It's tightly coordinated with SearchToolbar, using refs to control special
 * keyboard and focus interactions.
 */
function SearchPanel({
  query,
  outfitState,
  dispatchToOutfit,
  scrollContainerRef,
  searchQueryRef,
  firstSearchResultRef,
}) {
  const scrollToTop = React.useCallback(() => {
    if (scrollContainerRef.current) {
      scrollContainerRef.current.scrollTop = 0;
    }
  }, [scrollContainerRef]);

  // Sometimes we want to give focus back to the search field!
  const onMoveFocusUpToQuery = (e) => {
    if (searchQueryRef.current) {
      searchQueryRef.current.focus();
      e.preventDefault();
    }
  };

  return (
    <Box
      onKeyDown={(e) => {
        // This will catch any Escape presses when the user's focus is inside
        // the SearchPanel.
        if (e.key === "Escape") {
          onMoveFocusUpToQuery(e);
        }
      }}
    >
      <SearchResults
        // When the query changes, replace the SearchResults component with a
        // new instance. This resets both `currentPageNumber`, to take us back
        // to page 1; and also `itemIdsToReconsider`. That way, if you find an
        // item you like in one search, then immediately do a second search and
        // try a conflicting item, we'll restore the item you liked from your
        // first search!
        key={serializeQuery(query)}
        query={query}
        outfitState={outfitState}
        dispatchToOutfit={dispatchToOutfit}
        firstSearchResultRef={firstSearchResultRef}
        scrollToTop={scrollToTop}
        onMoveFocusUpToQuery={onMoveFocusUpToQuery}
      />
    </Box>
  );
}

/**
 * SearchResults loads the search results from the user's query, renders them,
 * and tracks the scroll container for infinite scrolling.
 *
 * For each item, we render a <label> with a visually-hidden checkbox and the
 * Item component (which will visually reflect the radio's state). This makes
 * the list screen-reader- and keyboard-accessible!
 */
function SearchResults({
  query,
  outfitState,
  dispatchToOutfit,
  firstSearchResultRef,
  scrollToTop,
  onMoveFocusUpToQuery,
}) {
  const [currentPageNumber, setCurrentPageNumber] = React.useState(1);
  const { loading, error, items, numTotalPages } = useSearchResults(
    query,
    outfitState,
    currentPageNumber
  );

  // Preload the previous and next page of search results, with this quick
  // ~hacky trick: just `useSearchResults` two more times, with some extra
  // attention to skip the query when we don't know if it will exist!
  useSearchResults(query, outfitState, currentPageNumber - 1, {
    skip: currentPageNumber <= 1,
  });
  useSearchResults(query, outfitState, currentPageNumber + 1, {
    skip: numTotalPages == null || currentPageNumber >= numTotalPages,
  });

  // This will save the `wornItemIds` when the SearchResults first mounts, and
  // keep it saved even after the outfit changes. We use this to try to restore
  // these items after the user makes changes, e.g., after they try on another
  // Background we want to restore the previous one!
  const [itemIdsToReconsider] = React.useState(outfitState.wornItemIds);

  // Whenever the page number changes, scroll back to the top!
  React.useEffect(() => scrollToTop(), [currentPageNumber, scrollToTop]);

  // You can use UpArrow/DownArrow to navigate between items, and even back up
  // to the search field!
  const goToPrevItem = React.useCallback(
    (e) => {
      const prevLabel = e.target.closest("label").previousSibling;
      if (prevLabel) {
        prevLabel.querySelector("input[type=checkbox]").focus();
        prevLabel.scrollIntoView({ block: "center" });
        e.preventDefault();
      } else {
        // If we're at the top of the list, move back up to the search box!
        onMoveFocusUpToQuery(e);
      }
    },
    [onMoveFocusUpToQuery]
  );
  const goToNextItem = React.useCallback((e) => {
    const nextLabel = e.target.closest("label").nextSibling;
    if (nextLabel) {
      nextLabel.querySelector("input[type=checkbox]").focus();
      nextLabel.scrollIntoView({ block: "center" });
      e.preventDefault();
    }
  }, []);

  const searchPanelBackground = useColorModeValue("white", "gray.900");

  // If the results aren't ready, we have some special case UI!
  if (error) {
    return (
      <Text>
        We hit an error trying to load your search results{" "}
        <span role="img" aria-label="(sweat emoji)">
          😓
        </span>{" "}
        Try again?
      </Text>
    );
  }

  // Finally, render the item list, with checkboxes and Item components!
  // We also render some extra skeleton items at the bottom during infinite
  // scroll loading.
  return (
    <Box>
      <Box
        position="sticky"
        top="0"
        background={searchPanelBackground}
        zIndex="2"
        paddingX="5"
        paddingBottom="2"
        paddingTop="1"
      >
        <PaginationToolbar
          numTotalPages={numTotalPages}
          currentPageNumber={currentPageNumber}
          goToPageNumber={setCurrentPageNumber}
          buildPageUrl={() => null}
          size="sm"
        />
      </Box>
      <ItemListContainer paddingX="4" paddingBottom="2">
        {items.map((item, index) => (
          <SearchResultItem
            key={item.id}
            item={item}
            itemIdsToReconsider={itemIdsToReconsider}
            isWorn={outfitState.wornItemIds.includes(item.id)}
            isInOutfit={outfitState.allItemIds.includes(item.id)}
            dispatchToOutfit={dispatchToOutfit}
            checkboxRef={index === 0 ? firstSearchResultRef : null}
            goToPrevItem={goToPrevItem}
            goToNextItem={goToNextItem}
          />
        ))}
      </ItemListContainer>
      {loading && (
        <ItemListSkeleton
          count={SEARCH_PER_PAGE}
          paddingX="4"
          paddingBottom="2"
        />
      )}
      {!loading && items.length === 0 && (
        <Text paddingX="4">
          We couldn't find any matching items{" "}
          <span role="img" aria-label="(thinking emoji)">
            🤔
          </span>{" "}
          Try again?
        </Text>
      )}
    </Box>
  );
}

function SearchResultItem({
  item,
  itemIdsToReconsider,
  isWorn,
  isInOutfit,
  dispatchToOutfit,
  checkboxRef,
  goToPrevItem,
  goToNextItem,
}) {
  // It's important to use `useCallback` for `onRemove`, to avoid re-rendering
  // the whole list of <Item>s!
  const onRemove = React.useCallback(
    () =>
      dispatchToOutfit({
        type: "removeItem",
        itemId: item.id,
        itemIdsToReconsider,
      }),
    [item.id, itemIdsToReconsider, dispatchToOutfit]
  );

  return (
    <label>
      <VisuallyHidden
        as="input"
        type="checkbox"
        aria-label={`Wear "${item.name}"`}
        value={item.id}
        checked={isWorn}
        ref={checkboxRef}
        onChange={(e) => {
          const itemId = e.target.value;
          const willBeWorn = e.target.checked;
          if (willBeWorn) {
            dispatchToOutfit({ type: "wearItem", itemId, itemIdsToReconsider });
          } else {
            dispatchToOutfit({
              type: "unwearItem",
              itemId,
              itemIdsToReconsider,
            });
          }
        }}
        onKeyDown={(e) => {
          if (e.key === "Enter") {
            e.target.click();
          } else if (e.key === "ArrowUp") {
            goToPrevItem(e);
          } else if (e.key === "ArrowDown") {
            goToNextItem(e);
          }
        }}
      />
      <Item
        item={item}
        isWorn={isWorn}
        isInOutfit={isInOutfit}
        onRemove={onRemove}
      />
    </label>
  );
}

/**
 * serializeQuery stably converts a search query object to a string, for easier
 * JS comparison.
 */
function serializeQuery(query) {
  return `${JSON.stringify([
    query.value,
    query.filterToItemKind,
    query.filterToZoneLabel,
    query.filterToCurrentUserOwnsOrWants,
  ])}`;
}

export default SearchPanel;
