export function normalizeSwfAssetToLayer(swfAssetData) {
	return {
		id: String(swfAssetData.id),
		remoteId: String(swfAssetData.remote_id),
		zone: {
			id: String(swfAssetData.zone.id),
			depth: swfAssetData.zone.depth,
			label: swfAssetData.zone.label,
			isCommonlyUsedByItems: swfAssetData.zone.is_commonly_used_by_items,
		},
		bodyId: swfAssetData.body_id,
		knownGlitches: swfAssetData.known_glitches,

		svgUrl: swfAssetData.urls.svg,
		canvasMovieLibraryUrl: swfAssetData.urls.canvas_library,
		imageUrl: swfAssetData.urls.png,
		swfUrl: swfAssetData.urls.swf,
	};
}
