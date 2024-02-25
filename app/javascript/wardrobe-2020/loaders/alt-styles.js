import { useQuery } from "@tanstack/react-query";

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
	const query = useAltStylesForSpecies(speciesId, options);

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
		seriesName: altStyleData.series_name,
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

function normalizeSwfAssetToLayer(swfAssetData) {
	return {
		id: String(swfAssetData.id),
		zone: {
			id: String(swfAssetData.zone.id),
			depth: swfAssetData.zone.depth,
			label: swfAssetData.zone.label,
		},
		bodyId: swfAssetData.body_id,
		knownGlitches: swfAssetData.known_glitches,

		svgUrl: swfAssetData.urls.svg,
		canvasMovieLibraryUrl: swfAssetData.urls.canvas_library,
		imageUrl: swfAssetData.urls.png,
		swfUrl: swfAssetData.urls.swf,
	};
}
