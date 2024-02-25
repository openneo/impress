import React from "react";
import gql from "graphql-tag";
import { useQuery } from "@apollo/client";
import { useDebounce, useLocalStorage } from "../util";
import { useItemSearch } from "../loaders/items";
import { emptySearchQuery, searchQueryIsEmpty } from "./SearchToolbar";
import { itemAppearanceFragment } from "../components/useOutfitAppearance";
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

  // NOTE: This query should always load ~instantly, from the client cache.
  const { data: zoneData } = useQuery(gql`
    query SearchPanelZones {
      allZones {
        id
        label
      }
    }
  `);
  const allZones = zoneData?.allZones || [];
  const filterToZones = query.filterToZoneLabel
    ? allZones.filter((z) => z.label === query.filterToZoneLabel)
    : [];
  const filterToZoneIds = filterToZones.map((z) => z.id);

  const currentPageIndex = currentPageNumber - 1;
  const offset = currentPageIndex * SEARCH_PER_PAGE;

  // Until the new item search is ready, we can toggle between them! Use
  // `setItemSearchQueryMode` in the JS console to choose "gql" or "new".
  const [queryMode, setQueryMode] = useLocalStorage(
    "DTIItemSearchQueryMode",
    "gql",
  );
  React.useEffect(() => {
    window.setItemSearchQueryMode = setQueryMode;
  }, [setQueryMode]);

  const {
    loading: loadingGQL,
    error: errorGQL,
    data: dataGQL,
  } = useQuery(
    gql`
      query SearchPanel(
        $query: String!
        $fitsPet: FitsPetSearchFilter
        $itemKind: ItemKindSearchFilter
        $currentUserOwnsOrWants: OwnsOrWants
        $zoneIds: [ID!]!
        $speciesId: ID!
        $colorId: ID!
        $altStyleId: ID
        $offset: Int!
        $perPage: Int!
      ) {
        itemSearch: itemSearchV2(
          query: $query
          fitsPet: $fitsPet
          itemKind: $itemKind
          currentUserOwnsOrWants: $currentUserOwnsOrWants
          zoneIds: $zoneIds
        ) {
          id
          numTotalItems
          items(offset: $offset, limit: $perPage) {
            # TODO: De-dupe this from useOutfitState?
            id
            name
            thumbnailUrl
            isNc
            isPb
            currentUserOwnsThis
            currentUserWantsThis

            appearanceOn(
              speciesId: $speciesId
              colorId: $colorId
              altStyleId: $altStyleId
            ) {
              # This enables us to quickly show the item when the user clicks it!
              ...ItemAppearanceForOutfitPreview

              # This is used to group items by zone, and to detect conflicts when
              # wearing a new item.
              layers {
                zone {
                  id
                  label
                }
              }
              restrictedZones {
                id
                label
                isCommonlyUsedByItems
              }
            }
          }
        }
      }
      ${itemAppearanceFragment}
    `,
    {
      variables: {
        query: debouncedQuery.value,
        fitsPet: { speciesId, colorId, altStyleId },
        itemKind: debouncedQuery.filterToItemKind,
        currentUserOwnsOrWants: debouncedQuery.filterToCurrentUserOwnsOrWants,
        zoneIds: filterToZoneIds,
        speciesId,
        colorId,
        altStyleId,
        offset,
        perPage: SEARCH_PER_PAGE,
      },
      context: { sendAuth: true },
      skip:
        skip ||
        queryMode !== "gql" ||
        (!debouncedQuery.value &&
          !debouncedQuery.filterToItemKind &&
          !debouncedQuery.filterToZoneLabel &&
          !debouncedQuery.filterToCurrentUserOwnsOrWants),
      onError: (e) => {
        console.error("Error loading search results", e);
      },
      // Return `numTotalItems` from the GQL cache while waiting for next page!
      returnPartialData: true,
    },
  );

  const {
    isLoading: loadingQuery,
    error: errorQuery,
    data: dataQuery,
  } = useItemSearch(
    {
      filters: buildSearchFilters(debouncedQuery, outfitState),
      withAppearancesFor: { speciesId, colorId, altStyleId },
      page: currentPageIndex + 1,
      perPage: SEARCH_PER_PAGE,
    },
    {
      enabled:
        !skip && queryMode === "new" && !searchQueryIsEmpty(debouncedQuery),
    },
  );

  const loading =
    debouncedQuery !== query ||
    (queryMode === "gql" ? loadingGQL : loadingQuery);
  const error = queryMode === "gql" ? errorGQL : errorQuery;
  const items =
    (queryMode === "gql" ? dataGQL?.itemSearch?.items : dataQuery?.items) ?? [];
  const numTotalPages =
    (queryMode === "gql"
      ? Math.ceil((dataGQL?.itemSearch?.numTotalItems ?? 0) / SEARCH_PER_PAGE)
      : dataQuery?.numTotalPages) ?? 0;

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
