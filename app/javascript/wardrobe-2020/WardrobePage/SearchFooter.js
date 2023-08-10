import React from "react";
import * as Sentry from "@sentry/react";
import { Box, Flex } from "@chakra-ui/react";
import SearchToolbar from "./SearchToolbar";
import { MajorErrorMessage, TestErrorSender, useLocalStorage } from "../util";
import PaginationToolbar from "../components/PaginationToolbar";
import { useSearchResults } from "./useSearchResults";

/**
 * SearchFooter appears on large screens only, to let you search for new items
 * while still keeping the rest of the item screen open!
 */
function SearchFooter({ searchQuery, onChangeSearchQuery, outfitState }) {
  const [canUseSearchFooter, setCanUseSearchFooter] = useLocalStorage(
    "DTIFeatureFlagCanUseSearchFooter",
    false
  );

  const { items, numTotalPages } = useSearchResults(
    searchQuery,
    outfitState,
    1
  );

  React.useEffect(() => {
    if (window.location.search.includes("feature-flag-can-use-search-footer")) {
      setCanUseSearchFooter(true);
    }
  }, [setCanUseSearchFooter]);

  // TODO: Show the new footer to other users, too!
  if (!canUseSearchFooter) {
    return null;
  }

  return (
    <Sentry.ErrorBoundary fallback={MajorErrorMessage}>
      <TestErrorSender />
      <Box>
        <Box paddingX="4" paddingY="4">
          <Flex as="label" align="center">
            <Box fontWeight="600" flex="0 0 auto">
              Add new items:
            </Box>
            <Box width="8" />
            <SearchToolbar
              query={searchQuery}
              onChange={onChangeSearchQuery}
              flex="0 1 100%"
              suggestionsPlacement="top"
            />
            <Box width="8" />
            {numTotalPages != null && (
              <Box flex="0 0 auto">
                <PaginationToolbar
                  numTotalPages={numTotalPages}
                  currentPageNumber={1}
                  goToPageNumber={() => alert("TODO")}
                  buildPageUrl={() => null}
                  size="sm"
                />
              </Box>
            )}
          </Flex>
        </Box>
        <Box maxHeight="32" overflow="auto">
          <Box as="ul" listStyleType="disc" paddingLeft="8">
            {items.map((item) => (
              <Box key={item.id} as="li">
                {item.name}
              </Box>
            ))}
          </Box>
        </Box>
      </Box>
    </Sentry.ErrorBoundary>
  );
}

export default SearchFooter;
