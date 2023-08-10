import React from "react";
import gql from "graphql-tag";
import produce, { enableMapSet } from "immer";
import { useQuery, useApolloClient } from "@apollo/client";

import { itemAppearanceFragment } from "../components/useOutfitAppearance";
import { useRouter } from "next/router";

enableMapSet();

export const OutfitStateContext = React.createContext(null);

function useOutfitState() {
  const apolloClient = useApolloClient();
  const urlOutfitState = useParseOutfitUrl();
  const [localOutfitState, dispatchToOutfit] = React.useReducer(
    outfitStateReducer(apolloClient),
    urlOutfitState
  );

  // If there's an outfit ID (i.e. we're on /outfits/:id), load basic data
  // about the outfit. We'll use it to initialize the local state.
  const {
    loading: outfitLoading,
    error: outfitError,
    data: outfitData,
  } = useQuery(
    gql`
      query OutfitStateSavedOutfit($id: ID!) {
        outfit(id: $id) {
          id
          name
          updatedAt
          creator {
            id
          }
          petAppearance {
            id
            species {
              id
            }
            color {
              id
            }
            pose
          }
          wornItems {
            id
          }
          closetedItems {
            id
          }

          # TODO: Consider pre-loading some fields, instead of doing them in
          #       follow-up queries?
        }
      }
    `,
    {
      variables: { id: urlOutfitState.id },
      skip: urlOutfitState.id == null,
      returnPartialData: true,
      onCompleted: (outfitData) => {
        dispatchToOutfit({
          type: "resetToSavedOutfitData",
          savedOutfitData: outfitData.outfit,
        });
      },
    }
  );

  const creator = outfitData?.outfit?.creator;
  const updatedAt = outfitData?.outfit?.updatedAt;

  // We memoize this to make `outfitStateWithoutExtras` an even more reliable
  // stable object!
  const savedOutfitState = React.useMemo(
    () => getOutfitStateFromOutfitData(outfitData?.outfit),
    [outfitData?.outfit]
  );

  // Choose which customization state to use. We want it to match the outfit in
  // the URL immediately, without having to wait for any effects, to avoid race
  // conditions!
  //
  // The reducer is generally the main source of truth for live changes!
  //
  // But if:
  //   - it's not initialized yet (e.g. the first frame of navigating to an
  //     outfit from Your Outfits), or
  //   - it's for a different outfit than the URL says (e.g. clicking Back
  //     or Forward to switch between saved outfits),
  //
  // Then use saved outfit data or the URL query string instead, because that's
  // a better representation of the outfit in the URL. (If the saved outfit
  // data isn't loaded yet, then this will be a customization state with
  // partial data, and that's okay.)
  let outfitState;
  if (
    urlOutfitState.id === localOutfitState.id &&
    localOutfitState.speciesId != null &&
    localOutfitState.colorId != null
  ) {
    // Use the reducer state: they're both for the same saved outfit, or both
    // for an unsaved outfit (null === null). But we don't use it when it's
    // *only* got the ID, and no other fields yet.
    console.debug("[useOutfitState] Choosing local outfit state");
    outfitState = localOutfitState;
  } else if (urlOutfitState.id && urlOutfitState.id === savedOutfitState.id) {
    // Use the saved outfit state: it's for the saved outfit the URL points to.
    console.debug("[useOutfitState] Choosing saved outfit state");
    outfitState = savedOutfitState;
  } else {
    // Use the URL state: it's more up-to-date than any of the others. (Worst
    // case, it's empty except for ID, which is fine while the saved outfit
    // data loads!)
    console.debug("[useOutfitState] Choosing URL outfit state");
    outfitState = urlOutfitState;
  }

  // When unpacking the customization state, we call `Array.from` on our item
  // IDs. It's more convenient to manage them as a Set in state, but most
  // callers will find it more convenient to access them as arrays! e.g. for
  // `.map()`.
  const { id, name, speciesId, colorId, pose, appearanceId } = outfitState;
  const wornItemIds = Array.from(outfitState.wornItemIds);
  const closetedItemIds = Array.from(outfitState.closetedItemIds);
  const allItemIds = [...wornItemIds, ...closetedItemIds];

  const {
    loading: itemsLoading,
    error: itemsError,
    data: itemsData,
  } = useQuery(
    gql`
      query OutfitStateItems(
        $allItemIds: [ID!]!
        $speciesId: ID!
        $colorId: ID!
      ) {
        items(ids: $allItemIds) {
          # TODO: De-dupe this from SearchPanel?
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

        # NOTE: We skip this query if items is empty for perf reasons. If
        #       you're adding more fields, consider changing that condition!
      }
      ${itemAppearanceFragment}
    `,
    {
      variables: { allItemIds, speciesId, colorId },
      context: { sendAuth: true },
      // Skip if this outfit has no items, as an optimization; or if we don't
      // have the species/color ID loaded yet because we're waiting on the
      // saved outfit to load.
      skip: allItemIds.length === 0 || speciesId == null || colorId == null,
    }
  );

  const resultItems = itemsData?.items || [];

  // Okay, time for some big perf hacks! Lower down in the app, we use
  // React.memo to avoid re-rendering Item components if the items haven't
  // updated. In simpler cases, we just make the component take the individual
  // item fields as props... but items are complex and that makes it annoying
  // :p Instead, we do these tricks to reuse physical item objects if they're
  // still deep-equal to the previous version. This is because React.memo uses
  // object identity to compare its props, so now when it checks whether
  // `oldItem === newItem`, the answer will be `true`, unless the item really
  // _did_ change!
  const [cachedItemObjects, setCachedItemObjects] = React.useState([]);
  let items = resultItems.map((item) => {
    const cachedItemObject = cachedItemObjects.find((i) => i.id === item.id);
    if (
      cachedItemObject &&
      JSON.stringify(cachedItemObject) === JSON.stringify(item)
    ) {
      return cachedItemObject;
    }
    return item;
  });
  if (
    items.length === cachedItemObjects.length &&
    items.every((_, index) => items[index] === cachedItemObjects[index])
  ) {
    // Even reuse the entire array if none of the items changed!
    items = cachedItemObjects;
  }
  React.useEffect(() => {
    setCachedItemObjects(items);
  }, [items, setCachedItemObjects]);

  const itemsById = {};
  for (const item of items) {
    itemsById[item.id] = item;
  }

  const zonesAndItems = getZonesAndItems(
    itemsById,
    wornItemIds,
    closetedItemIds
  );
  const incompatibleItems = items
    .filter((i) => i.appearanceOn.layers.length === 0)
    .sort((a, b) => a.name.localeCompare(b.name));

  const url = buildOutfitUrl(outfitState);

  const outfitStateWithExtras = {
    id,
    creator,
    updatedAt,
    zonesAndItems,
    incompatibleItems,
    name,
    wornItemIds,
    closetedItemIds,
    allItemIds,
    speciesId,
    colorId,
    pose,
    appearanceId,
    url,

    // We use this plain outfit state objects in `useOutfitSaving`! Unlike the
    // full `outfitState` object, which we rebuild each render,
    // `outfitStateWithoutExtras` will mostly only change when there is an
    // actual change to outfit state.
    outfitStateWithoutExtras: outfitState,
    savedOutfitState,
  };

  // Keep the URL up-to-date. (We don't listen to it, though 😅)
  // TODO: Seems like we should hook this in with the actual router... I'm
  //       avoiding it rn, but I'm worried Next.js won't necessarily play nice
  //       with this hack, even though react-router did. Hard to predict!
  React.useEffect(() => {
    if (typeof history !== "undefined") {
      history.replaceState(null, "", url);
    }
  }, [url]);

  return {
    loading: outfitLoading || itemsLoading,
    error: outfitError || itemsError,
    outfitState: outfitStateWithExtras,
    dispatchToOutfit,
  };
}

const outfitStateReducer = (apolloClient) => (baseState, action) => {
  console.info("[useOutfitState] Action:", action);
  switch (action.type) {
    case "rename":
      return produce(baseState, (state) => {
        state.name = action.outfitName;
      });
    case "setSpeciesAndColor":
      return produce(baseState, (state) => {
        state.speciesId = action.speciesId;
        state.colorId = action.colorId;
        state.pose = action.pose;
        state.appearanceId = null;
      });
    case "wearItem":
      return produce(baseState, (state) => {
        const { wornItemIds, closetedItemIds } = state;
        const { itemId, itemIdsToReconsider = [] } = action;

        // Move conflicting items to the closet.
        //
        // We do this by looking them up in the Apollo Cache, which is going to
        // include the relevant item data because the `useOutfitState` hook
        // queries for it!
        //
        // (It could be possible to mess up the timing by taking an action
        // while worn items are still partially loading, but I think it would
        // require a pretty weird action sequence to make that happen... like,
        // doing a search and it loads before the worn item data does? Anyway,
        // Apollo will throw in that case, which should just essentially reject
        // the action.)
        let conflictingIds;
        try {
          conflictingIds = findItemConflicts(itemId, state, apolloClient);
        } catch (e) {
          console.error(e);
          return;
        }
        for (const conflictingId of conflictingIds) {
          wornItemIds.delete(conflictingId);
          closetedItemIds.add(conflictingId);
        }

        // Move this item from the closet to the worn set.
        closetedItemIds.delete(itemId);
        wornItemIds.add(itemId);

        reconsiderItems(itemIdsToReconsider, state, apolloClient);
      });
    case "unwearItem":
      return produce(baseState, (state) => {
        const { wornItemIds, closetedItemIds } = state;
        const { itemId, itemIdsToReconsider = [] } = action;

        // Move this item from the worn set to the closet.
        wornItemIds.delete(itemId);
        closetedItemIds.add(itemId);

        reconsiderItems(
          // Don't include the unworn item in items to reconsider!
          itemIdsToReconsider.filter((x) => x !== itemId),
          state,
          apolloClient
        );
      });
    case "removeItem":
      return produce(baseState, (state) => {
        const { wornItemIds, closetedItemIds } = state;
        const { itemId, itemIdsToReconsider = [] } = action;

        // Remove this item from both the worn set and the closet.
        wornItemIds.delete(itemId);
        closetedItemIds.delete(itemId);

        reconsiderItems(
          // Don't include the removed item in items to reconsider!
          itemIdsToReconsider.filter((x) => x !== itemId),
          state,
          apolloClient
        );
      });
    case "setPose":
      return produce(baseState, (state) => {
        state.pose = action.pose;
        // Usually only the `pose` is specified, but `PosePickerSupport` can
        // also specify a corresponding `appearanceId`, to get even more
        // particular about which version of the pose to show if more than one.
        state.appearanceId = action.appearanceId || null;
      });
    case "resetToSavedOutfitData":
      return getOutfitStateFromOutfitData(action.savedOutfitData);
    default:
      throw new Error(`unexpected action ${JSON.stringify(action)}`);
  }
};

const EMPTY_CUSTOMIZATION_STATE = {
  id: null,
  name: null,
  speciesId: null,
  colorId: null,
  pose: null,
  appearanceId: null,
  wornItemIds: [],
  closetedItemIds: [],
};

function useParseOutfitUrl() {
  const { query } = useRouter();

  // We memoize this to make `outfitStateWithoutExtras` an even more reliable
  // stable object!
  const memoizedOutfitState = React.useMemo(
    () => readOutfitStateFromQuery(query),
    [query]
  );

  return memoizedOutfitState;
}

export function readOutfitStateFromQuery(query) {
  // For the /outfits/:id page, ignore the query string, and just wait for the
  // outfit data to load in!
  if (query.outfitId != null) {
    return {
      ...EMPTY_CUSTOMIZATION_STATE,
      id: query.outfitId,
    };
  }

  // Otherwise, parse the query string, and fill in default values for anything
  // not specified.
  return {
    id: null,
    name: getValueFromQuery(query.name),
    speciesId: getValueFromQuery(query.species) || "1",
    colorId: getValueFromQuery(query.color) || "8",
    pose: getValueFromQuery(query.pose) || "HAPPY_FEM",
    appearanceId: getValueFromQuery(query.state) || null,
    wornItemIds: new Set(getListFromQuery(query["objects[]"])),
    closetedItemIds: new Set(getListFromQuery(query["closet[]"])),
  };
}

/**
 * getValueFromQuery reads the given value from Next's `router.query` as a
 * single value. For example:
 *
 * ?foo=bar -> "bar" -> "bar"
 * ?foo=bar&foo=baz -> ["bar", "baz"] -> "bar"
 * ?lol=huh -> undefined -> null
 */
function getValueFromQuery(value) {
  if (Array.isArray(value)) {
    return value[0];
  } else if (value != null) {
    return value;
  } else {
    return null;
  }
}

/**
 * getListFromQuery reads the given value from Next's `router.query` as a list
 * of values. For example:
 *
 * ?foo=bar -> "bar" -> ["bar"]
 * ?foo=bar&foo=baz -> ["bar", "baz"] -> ["bar", "baz"]
 * ?lol=huh -> undefined -> []
 */
function getListFromQuery(value) {
  if (Array.isArray(value)) {
    return value;
  } else if (value != null) {
    return [value];
  } else {
    return [];
  }
}

function getOutfitStateFromOutfitData(outfit) {
  if (!outfit) {
    return EMPTY_CUSTOMIZATION_STATE;
  }

  return {
    id: outfit.id,
    name: outfit.name,
    // Note that these fields are intentionally null if loading, rather than
    // falling back to a default appearance like Blue Acara.
    speciesId: outfit.petAppearance?.species?.id,
    colorId: outfit.petAppearance?.color?.id,
    pose: outfit.petAppearance?.pose,
    // Whereas the items are more convenient to just leave as empty lists!
    wornItemIds: new Set((outfit.wornItems || []).map((item) => item.id)),
    closetedItemIds: new Set(
      (outfit.closetedItems || []).map((item) => item.id)
    ),
  };
}

function findItemConflicts(itemIdToAdd, state, apolloClient) {
  const { wornItemIds, speciesId, colorId } = state;

  const { items } = apolloClient.readQuery({
    query: gql`
      query OutfitStateItemConflicts(
        $itemIds: [ID!]!
        $speciesId: ID!
        $colorId: ID!
      ) {
        items(ids: $itemIds) {
          id
          appearanceOn(speciesId: $speciesId, colorId: $colorId) {
            layers {
              zone {
                id
              }
            }

            restrictedZones {
              id
            }
          }
        }
      }
    `,
    variables: {
      itemIds: [itemIdToAdd, ...wornItemIds],
      speciesId,
      colorId,
    },
  });
  const itemToAdd = items.find((i) => i.id === itemIdToAdd);
  if (!itemToAdd.appearanceOn) {
    return [];
  }
  const wornItems = Array.from(wornItemIds).map((id) =>
    items.find((i) => i.id === id)
  );

  const itemToAddZoneSets = getItemZones(itemToAdd);

  const conflictingIds = [];
  for (const wornItem of wornItems) {
    if (!wornItem.appearanceOn) {
      continue;
    }

    const wornItemZoneSets = getItemZones(wornItem);

    const itemsConflict =
      setsIntersect(
        itemToAddZoneSets.occupies,
        wornItemZoneSets.occupiesOrRestricts
      ) ||
      setsIntersect(
        wornItemZoneSets.occupies,
        itemToAddZoneSets.occupiesOrRestricts
      );

    if (itemsConflict) {
      conflictingIds.push(wornItem.id);
    }
  }

  return conflictingIds;
}

function getItemZones(item) {
  const occupies = new Set(item.appearanceOn.layers.map((l) => l.zone.id));
  const restricts = new Set(item.appearanceOn.restrictedZones.map((z) => z.id));
  const occupiesOrRestricts = new Set([...occupies, ...restricts]);
  return { occupies, occupiesOrRestricts };
}

function setsIntersect(a, b) {
  for (const el of a) {
    if (b.has(el)) {
      return true;
    }
  }
  return false;
}

/**
 * Try to add these items back to the outfit, if there would be no conflicts.
 * We use this in Search to try to restore these items after the user makes
 * changes, e.g., after they try on another Background we want to restore the
 * previous one!
 *
 * This mutates state.wornItemIds directly, on the assumption that we're in an
 * immer block, in which case mutation is the simplest API!
 */
function reconsiderItems(itemIdsToReconsider, state, apolloClient) {
  for (const itemIdToReconsider of itemIdsToReconsider) {
    const conflictingIds = findItemConflicts(
      itemIdToReconsider,
      state,
      apolloClient
    );
    if (conflictingIds.length === 0) {
      state.wornItemIds.add(itemIdToReconsider);
    }
  }
}

// TODO: Get this out of here, tbh...
function getZonesAndItems(itemsById, wornItemIds, closetedItemIds) {
  const wornItems = wornItemIds.map((id) => itemsById[id]).filter((i) => i);
  const closetedItems = closetedItemIds
    .map((id) => itemsById[id])
    .filter((i) => i);

  // We use zone label here, rather than ID, because some zones have the same
  // label and we *want* to over-simplify that in this UI. (e.g. there are
  // multiple Hat zones, and some items occupy different ones, but mostly let's
  // just group them and if they don't conflict then all the better!)
  const allItems = [...wornItems, ...closetedItems];
  const itemsByZoneLabel = new Map();
  for (const item of allItems) {
    if (!item.appearanceOn) {
      continue;
    }

    for (const layer of item.appearanceOn.layers) {
      const zoneLabel = layer.zone.label;

      if (!itemsByZoneLabel.has(zoneLabel)) {
        itemsByZoneLabel.set(zoneLabel, []);
      }
      itemsByZoneLabel.get(zoneLabel).push(item);
    }
  }

  let zonesAndItems = Array.from(itemsByZoneLabel.entries()).map(
    ([zoneLabel, items]) => ({
      zoneLabel: zoneLabel,
      items: [...items].sort((a, b) => a.name.localeCompare(b.name)),
    })
  );
  zonesAndItems.sort((a, b) => a.zoneLabel.localeCompare(b.zoneLabel));

  // As one last step, try to remove zone groups that aren't helpful.
  const groupsWithConflicts = zonesAndItems.filter(
    ({ items }) => items.length > 1
  );
  const itemIdsWithConflicts = new Set(
    groupsWithConflicts
      .map(({ items }) => items)
      .flat()
      .map((item) => item.id)
  );
  const itemIdsWeHaveSeen = new Set();
  zonesAndItems = zonesAndItems.filter(({ items }) => {
    // We need all groups with more than one item. If there's only one, we get
    // to think harder :)
    if (items.length > 1) {
      items.forEach((item) => itemIdsWeHaveSeen.add(item.id));
      return true;
    }

    const item = items[0];

    // Has the item been seen a group we kept, or an upcoming group with
    // multiple conflicting items? If so, skip this group. If not, keep it.
    if (itemIdsWeHaveSeen.has(item.id) || itemIdsWithConflicts.has(item.id)) {
      return false;
    } else {
      itemIdsWeHaveSeen.add(item.id);
      return true;
    }
  });

  return zonesAndItems;
}

export function buildOutfitUrl(outfitState, { withoutOutfitId = false } = {}) {
  const { id } = outfitState;

  const origin =
    typeof window !== "undefined"
      ? window.location.origin
      : "https://impress-2020.openneo.net";

  if (id && !withoutOutfitId) {
    return origin + `/outfits/${id}`;
  }

  return origin + "/outfits/new?" + buildOutfitQueryString(outfitState);
}

function buildOutfitQueryString(outfitState) {
  const {
    name,
    speciesId,
    colorId,
    pose,
    appearanceId,
    wornItemIds,
    closetedItemIds,
  } = outfitState;

  const params = new URLSearchParams({
    name: name || "",
    species: speciesId || "",
    color: colorId || "",
    pose: pose || "",
  });
  for (const itemId of wornItemIds) {
    params.append("objects[]", itemId);
  }
  for (const itemId of closetedItemIds) {
    params.append("closet[]", itemId);
  }
  if (appearanceId != null) {
    // `state` is an old name for compatibility with old-style DTI URLs. It
    // refers to "PetState", the database table name for pet appearances.
    params.append("state", appearanceId);
  }

  return params.toString();
}

/**
 * Whether the two given outfit states represent identical customizations.
 */
export function outfitStatesAreEqual(a, b) {
  return buildOutfitQueryString(a) === buildOutfitQueryString(b);
}

export default useOutfitState;
