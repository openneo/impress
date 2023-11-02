import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";

export function useSavedOutfit(id, options) {
	return useQuery({
		...options,
		queryKey: ["outfits", String(id)],
		queryFn: () => loadSavedOutfit(id),
	});
}

export function useSaveOutfitMutation(options) {
	const queryClient = useQueryClient();

	return useMutation({
		...options,
		mutationFn: saveOutfit,
		onSuccess: (outfit) => {
			queryClient.setQueryData(["outfits", String(outfit.id)], outfit);
			options.onSuccess(outfit);
		},
	});
}

async function loadSavedOutfit(id) {
	const res = await fetch(`/outfits/${encodeURIComponent(id)}.json`);

	if (!res.ok) {
		throw new Error(`loading outfit failed: ${res.status} ${res.statusText}`);
	}

	return res.json();
}

async function saveOutfit({
	id, // optional, null when creating a new outfit
	name, // optional, server may fill in a placeholder
	speciesId,
	colorId,
	pose,
	wornItemIds,
	closetedItemIds,
}) {
	const params = {
		outfit: {
			name: name,
			biology: {
				species_id: speciesId,
				color_id: colorId,
				pose: pose,
			},
			item_ids: { worn: wornItemIds, closeted: closetedItemIds },
		},
	};

	let res;
	if (id == null) {
		res = await fetch(`/outfits.json`, {
			method: "POST",
			body: JSON.stringify(params),
			headers: {
				"Content-Type": "application/json",
				"X-CSRF-Token": getCSRFToken(),
			},
		});
	} else {
		res = await fetch(`/outfits/${encodeURIComponent(id)}.json`, {
			method: "PUT",
			body: JSON.stringify(params),
			headers: {
				"Content-Type": "application/json",
				"X-CSRF-Token": getCSRFToken(),
			},
		});
	}

	if (!res.ok) {
		throw new Error(`saving outfit failed: ${res.status} ${res.statusText}`);
	}

	return res.json();
}

function getCSRFToken() {
	return document.querySelector("meta[name=csrf-token]")?.content;
}
