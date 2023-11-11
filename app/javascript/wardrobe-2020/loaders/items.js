import { useQuery } from "@tanstack/react-query";

export function useItemAppearances(id, options = {}) {
	return useQuery({
		...options,
		queryKey: ["items", String(id)],
		queryFn: () => loadItemAppearancesData(id),
	});
}

async function loadItemAppearancesData(id) {
	const res = await fetch(`/items/${encodeURIComponent(id)}/appearances.json`);

	if (!res.ok) {
		throw new Error(
			`loading item appearances failed: ${res.status} ${res.statusText}`,
		);
	}

	return res.json().then(normalizeItemAppearancesData);
}

function normalizeItemAppearancesData(data) {
	return {
		appearances: data.appearances.map((appearance) => ({
			body: normalizeBody(appearance.body),
			swfAssets: appearance.swf_assets.map((asset) => ({
				id: String(asset.id),
				knownGlitches: asset.known_glitches,
				zone: normalizeZone(asset.zone),
				restrictedZones: asset.restricted_zones.map((z) => normalizeZone(z)),
				urls: {
					swf: asset.urls.swf,
					png: asset.urls.png,
					manifest: asset.urls.manifest,
				},
			})),
		})),
		restrictedZones: data.restricted_zones.map((z) => normalizeZone(z)),
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
			humanName: body.species.humanName,
		},
	};
}

function normalizeZone(zone) {
	return { id: String(zone.id), label: zone.label, depth: zone.depth };
}
