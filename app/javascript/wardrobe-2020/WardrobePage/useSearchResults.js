import { useDebounce } from "../util";
import { useItemSearch } from "../loaders/items";
import { emptySearchQuery, searchQueryIsEmpty } from "./SearchToolbar";
import { SEARCH_PER_PAGE } from "./SearchPanel";

/**
 * useSearchResults manages the actual querying and state management of search!
 */
export function useSearchResults(
  query,
  outfitState,
  currentPageNumber,
  { skip = false } = {},
) {
  const { speciesId, colorId, altStyleId } = outfitState;

  // We debounce the search query, so that we don't resend a new query whenever
  // the user types anything.
  const debouncedQuery = useDebounce(query, 300, {
    waitForFirstPause: true,
    initialValue: emptySearchQuery,
  });

  const { isLoading, error, data } = useItemSearch(
    {
      filters: buildSearchFilters(debouncedQuery, outfitState),
      withAppearancesFor: { speciesId, colorId, altStyleId },
      page: currentPageNumber,
      perPage: SEARCH_PER_PAGE,
    },
    {
      enabled: !skip && !searchQueryIsEmpty(debouncedQuery),
    },
  );

  const loading = debouncedQuery !== query || isLoading;
  const items = data?.items ?? [];
  const numTotalPages = data?.numTotalPages ?? 0;

  return { loading, error, items, numTotalPages };
}

function buildSearchFilters(query, { speciesId, colorId, altStyleId }) {
  const filters = [];

  if (query.value) {
    filters.push({ key: "name", value: query.value });
  }

  if (query.filterToItemKind === "NC") {
    filters.push({ key: "is_nc" });
  } else if (query.filterToItemKind === "PB") {
    filters.push({ key: "is_pb" });
  } else if (query.filterToItemKind === "NP") {
    filters.push({ key: "is_np" });
  }

  if (query.filterToZoneLabel != null) {
    filters.push({
      key: "occupied_zone_set_name",
      value: query.filterToZoneLabel,
    });
  }

  if (query.filterToCurrentUserOwnsOrWants === "OWNS") {
    filters.push({ key: "user_closet_hanger_ownership", value: "true" });
  } else if (query.filterToCurrentUserOwnsOrWants === "WANTS") {
    filters.push({ key: "user_closet_hanger_ownership", value: "false" });
  }

  filters.push({
    key: "fits",
    value: { speciesId, colorId, altStyleId },
  });

  return filters;
}
