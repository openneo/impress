import gql from "graphql-tag";
import { useQuery } from "@apollo/client";
import { useDebounce } from "../util";
import { emptySearchQuery } from "./SearchToolbar";
import { itemAppearanceFragment } from "../components/useOutfitAppearance";
import { SEARCH_PER_PAGE } from "./SearchPanel";

/**
 * useSearchResults manages the actual querying and state management of search!
 */
export function useSearchResults(
  query,
  outfitState,
  currentPageNumber,
  { skip = false } = {}
) {
  const { speciesId, colorId } = outfitState;

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

  // Here's the actual GQL query! At the bottom we have more config than usual!
  const {
    loading: loadingGQL,
    error,
    data,
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

            appearanceOn(speciesId: $speciesId, colorId: $colorId) {
              # This enables us to quickly show the item when the user clicks it!
              ...ItemAppearanceForOutfitPreview

              # This is used to group items by zone, and to detect conflicts when
              # wearing a new item.
              layers {
                zone {
                  id
                  label @client
                }
              }
              restrictedZones {
                id
                label @client
                isCommonlyUsedByItems @client
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
        fitsPet: { speciesId, colorId },
        itemKind: debouncedQuery.filterToItemKind,
        currentUserOwnsOrWants: debouncedQuery.filterToCurrentUserOwnsOrWants,
        zoneIds: filterToZoneIds,
        speciesId,
        colorId,
        offset,
        perPage: SEARCH_PER_PAGE,
      },
      context: { sendAuth: true },
      skip:
        skip ||
        (!debouncedQuery.value &&
          !debouncedQuery.filterToItemKind &&
          !debouncedQuery.filterToZoneLabel &&
          !debouncedQuery.filterToCurrentUserOwnsOrWants),
      onError: (e) => {
        console.error("Error loading search results", e);
      },
      // Return `numTotalItems` from the GQL cache while waiting for next page!
      returnPartialData: true,
    }
  );

  const loading = debouncedQuery !== query || loadingGQL;
  const items = data?.itemSearch?.items ?? [];
  const numTotalItems = data?.itemSearch?.numTotalItems ?? null;
  const numTotalPages = Math.ceil(numTotalItems / SEARCH_PER_PAGE);

  return { loading, error, items, numTotalPages };
}
