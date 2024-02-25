export function normalizeSwfAssetToLayer(data) {
	return {
		id: String(data.id),
		remoteId: String(data.remote_id),
		zone: normalizeZone(data.zone),
		bodyId: data.body_id,
		knownGlitches: data.known_glitches,

		svgUrl: data.urls.svg,
		canvasMovieLibraryUrl: data.urls.canvas_library,
		imageUrl: data.urls.png,
		swfUrl: data.urls.swf,
	};
}

export function normalizeZone(data) {
	return {
		id: String(data.id),
		depth: data.depth,
		label: data.label,
		isCommonlyUsedByItems: data.is_commonly_used_by_items,
	};
}
