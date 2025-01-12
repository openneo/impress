import { useQuery } from "@tanstack/react-query";

import { normalizeSwfAssetToLayer } from "./shared-types";

export function useAltStylesForSpecies(speciesId, options = {}) {
	return useQuery({
		...options,
		queryKey: ["altStylesForSpecies", String(speciesId)],
		queryFn: () => loadAltStylesForSpecies(speciesId),
		enabled: (options.enabled ?? true) && speciesId != null,
	});
}

// NOTE: This is actually just a wrapper for `useAltStylesForSpecies`, to share
// the same cache key!
export function useAltStyle(id, speciesId, options = {}) {
	const query = useAltStylesForSpecies(speciesId, {
		...options,
		enabled: (options.enabled ?? true) && id != null,
	});

	return {
		...query,
		data: query.data?.find((s) => s.id === id) ?? null,
	};
}

async function loadAltStylesForSpecies(speciesId) {
	const res = await fetch(
		`/species/${encodeURIComponent(speciesId)}/alt-styles.json`,
	);

	if (!res.ok) {
		throw new Error(
			`loading alt styles failed: ${res.status} ${res.statusText}`,
		);
	}

	return res.json().then(normalizeAltStyles);
}

function normalizeAltStyles(altStylesData) {
	return altStylesData.map(normalizeAltStyle);
}

function normalizeAltStyle(altStyleData) {
	return {
		id: String(altStyleData.id),
		speciesId: String(altStyleData.species_id),
		colorId: String(altStyleData.color_id),
		bodyId: String(altStyleData.body_id),
		seriesMainName: altStyleData.series_main_name,
		adjectiveName: altStyleData.adjective_name,
		thumbnailUrl: altStyleData.thumbnail_url,

		// This matches the PetAppearanceForOutfitPreview GQL fragment!
		appearance: {
			bodyId: String(altStyleData.body_id),
			pose: "UNKNOWN",
			isGlitched: false,
			species: { id: String(altStyleData.species_id) },
			color: { id: String(altStyleData.species_id) },
			layers: altStyleData.swf_assets.map(normalizeSwfAssetToLayer),
			restrictedZones: [],
		},
	};
}
