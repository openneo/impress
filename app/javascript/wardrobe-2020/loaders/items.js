import { useQuery } from "@tanstack/react-query";

import { normalizeSwfAssetToLayer } from "./shared-types";

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
	return useQuery({
		...queryOptions,
		queryKey: ["itemSearch", buildItemSearchParams(searchOptions)],
		queryFn: () => loadItemSearch(searchOptions),
	});
}

function buildItemSearchParams({
	filters = [],
	withAppearancesFor = null,
	page = 1,
	perPage = 30,
}) {
	const params = new URLSearchParams();
	for (const [i, filter] of filters.entries()) {
		params.append(`q[${i}][key]`, filter.key);
		params.append(`q[${i}][value]`, filter.value);
		if (params.isPositive == false) {
			params.append(`q[${i}][is_positive]`, "false");
		}
	}
	if (withAppearancesFor != null) {
		params.append("with_appearances_for", withAppearancesFor);
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

	return res
		.json()
		.then((data) => normalizeItemSearchData(data, searchOptions));
}
window.loadItemSearch = loadItemSearch;

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
		id: buildItemSearchParams(searchOptions),
		numTotalItems: data.total_count,
		items: data.items.map((item) => ({
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
		id: `item-${item.id}-body-${data.body.id}`,
		layers: data.swf_assets.map(normalizeSwfAssetToLayer),
	};
}

function normalizeBody(body) {
	if (String(body.id) === "0") {
		return { id: "0" };
	}

	return {
		id: String(body.id),
		species: {
			id: String(body.species.id),
			name: body.species.name,
			humanName: body.species.human_name,
		},
	};
}

function normalizeZone(zone) {
	return { id: String(zone.id), label: zone.label, depth: zone.depth };
}
