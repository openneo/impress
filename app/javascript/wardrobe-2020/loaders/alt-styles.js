import { useQuery } from "@tanstack/react-query";

export function useAltStylesForSpecies(speciesId, options = {}) {
	return useQuery({
		...options,
		queryKey: ["altStylesForSpecies", String(speciesId)],
		queryFn: () => loadAltStylesForSpecies(speciesId),
	});
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
	};
}
