import gql from "graphql-tag";
import { useQuery } from "@tanstack/react-query";

import apolloClient from "../apolloClient";
import { normalizeSwfAssetToLayer, normalizeZone } from "./shared-types";

export function useItemAppearances(id, options = {}) {
	return useQuery({
		...options,
		queryKey: ["items", String(id)],
		queryFn: () => loadItemAppearancesData(id),
	});
}

async function loadItemAppearancesData(id) {
	const res = await fetch(
		`/items/${encodeURIComponent(id)}/appearances.json`,
	);

	if (!res.ok) {
		throw new Error(
			`loading item appearances failed: ${res.status} ${res.statusText}`,
		);
	}

	return res.json().then(normalizeItemAppearancesData);
}

export function useItemSearch(searchOptions, queryOptions = {}) {
	// Item searches are considered fresh for an hour, unless the search
	// includes user-specific filters, in which case React Query will pretty
	// aggressively reload it!
	const includesUserSpecificFilters = searchOptions.filters.some(
		(f) => f.key === "user_closet_hanger_ownership",
	);
	const staleTime = includesUserSpecificFilters ? 0 : 1000 * 60 * 5;

	return useQuery({
		...queryOptions,
		queryKey: ["itemSearch", buildItemSearchParams(searchOptions)],
		queryFn: () => loadItemSearch(searchOptions),
		staleTime,
	});
}

function buildItemSearchParams({
	filters = [],
	withAppearancesFor = null,
	page = 1,
	perPage = 30,
}) {
	const params = new URLSearchParams();
	for (const [i, { key, value, isPositive }] of filters.entries()) {
		params.append(`q[${i}][key]`, key);
		if (key === "fits") {
			params.append(`q[${i}][value][species_id]`, value.speciesId);
			params.append(`q[${i}][value][color_id]`, value.colorId);
			if (value.altStyleId != null) {
				params.append(`q[${i}][value][alt_style_id]`, value.altStyleId);
			}
		} else {
			params.append(`q[${i}][value]`, value);
		}
		if (isPositive == false) {
			params.append(`q[${i}][is_positive]`, "false");
		}
	}
	if (withAppearancesFor != null) {
		const { speciesId, colorId, altStyleId } = withAppearancesFor;
		params.append(`with_appearances_for[species_id]`, speciesId);
		params.append(`with_appearances_for[color_id]`, colorId);
		if (altStyleId != null) {
			params.append(`with_appearances_for[alt_style_id]`, altStyleId);
		}
	}
	params.append("page", page);
	params.append("per_page", perPage);
	return params.toString();
}

async function loadItemSearch(searchOptions) {
	const params = buildItemSearchParams(searchOptions);

	const res = await fetch(`/items.json?${params}`);

	if (!res.ok) {
		throw new Error(
			`loading item search failed: ${res.status} ${res.statusText}`,
		);
	}

	const data = await res.json();
	const result = normalizeItemSearchData(data, searchOptions);

	for (const item of result.items) {
		writeItemToApolloCache(item, searchOptions.withAppearancesFor);
	}

	return result;
}

/**
 * writeItemToApolloCache is one last important bridge between our loaders and
 * GQL! In `useOutfitState`, we consult the GraphQL cache to look up basic item
 * info like zones, to decide when wearing an item would trigger a conflict
 * with another.
 */
function writeItemToApolloCache(item, { speciesId, colorId, altStyleId }) {
	apolloClient.writeQuery({
		query: gql`
			query WriteItemFromLoader(
				$itemId: ID!
				$speciesId: ID!
				$colorId: ID!
				$altStyleId: ID
			) {
				item(id: $itemId) {
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
						id
						layers {
							id
							remoteId
							bodyId
							knownGlitches
							svgUrl
							canvasMovieLibraryUrl
							imageUrl: imageUrlV2(idealSize: SIZE_600)
							swfUrl
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
			itemId: item.id,
			speciesId,
			colorId,
			altStyleId,
		},
		data: { item },
	});
}

function normalizeItemAppearancesData(data) {
	return {
		name: data.name,
		appearances: data.appearances.map((appearance) => ({
			body: normalizeBody(appearance.body),
			swfAssets: appearance.swf_assets.map(normalizeSwfAssetToLayer),
		})),
		restrictedZones: data.restricted_zones.map((z) => normalizeZone(z)),
	};
}

function normalizeItemSearchData(data, searchOptions) {
	return {
		__typename: "ItemSearchResultV2",
		id: buildItemSearchParams(searchOptions),
		numTotalPages: data.total_pages,
		items: data.items.map((item) => ({
			__typename: "Item",
			id: String(item.id),
			name: item.name,
			thumbnailUrl: item.thumbnail_url,
			isNc: item["nc?"],
			isPb: item["pb?"],
			currentUserOwnsThis: item["owned?"],
			currentUserWantsThis: item["wanted?"],
			appearanceOn: normalizeItemSearchAppearance(
				data.appearances[item.id],
				item,
			),
		})),
	};
}

function normalizeItemSearchAppearance(data, item) {
	if (data == null) {
		return null;
	}

	return {
		__typename: "ItemAppearance",
		id: `item-${item.id}-body-${data.body.id}`,
		layers: data.swf_assets.map(normalizeSwfAssetToLayer),
		restrictedZones: [
			...item.restricted_zones,
			...data.swf_assets.map((a) => a.restricted_zones).flat(),
		].map(normalizeZone),
	};
}

function normalizeBody(body) {
	if (String(body.id) === "0") {
		return { id: "0" };
	}

	return {
		__typename: "Body",
		id: String(body.id),
		species: {
			id: String(body.species.id),
			name: body.species.name,
			humanName: body.species.human_name,
		},
	};
}
