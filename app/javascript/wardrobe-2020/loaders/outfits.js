import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";

export function useSavedOutfit(id, options) {
	return useQuery({
		...options,
		queryKey: ["outfits", String(id)],
		queryFn: () => loadSavedOutfit(id),
	});
}

export function useSaveOutfitMutation(options = {}) {
	const queryClient = useQueryClient();

	return useMutation({
		...options,
		mutationFn: saveOutfit,
		onSuccess: (outfit) => {
			queryClient.setQueryData(["outfits", outfit.id], outfit);
			if (options.onSuccess) {
				options.onSuccess(outfit);
			}
		},
	});
}

export function useDeleteOutfitMutation(options = {}) {
	const queryClient = useQueryClient();

	return useMutation({
		...options,
		mutationFn: deleteOutfit,
		onSuccess: (emptyData, id, context) => {
			queryClient.invalidateQueries({ queryKey: ["outfits", String(id)] });
			if (options.onSuccess) {
				options.onSuccess(emptyData, id, context);
			}
		},
	});
}

async function loadSavedOutfit(id) {
	const res = await fetch(`/outfits/${encodeURIComponent(id)}.json`);

	if (!res.ok) {
		throw new Error(`loading outfit failed: ${res.status} ${res.statusText}`);
	}

	return res.json().then(normalizeOutfit);
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

	return res.json().then(normalizeOutfit);
}

async function deleteOutfit(id) {
	const res = await fetch(`/outfits/${encodeURIComponent(id)}.json`, {
		method: "DELETE",
		headers: {
			"X-CSRF-Token": getCSRFToken(),
		},
	});

	if (!res.ok) {
		throw new Error(`deleting outfit failed: ${res.status} ${res.statusText}`);
	}
}

function normalizeOutfit(outfit) {
	return {
		id: String(outfit.id),
		name: outfit.name,
		speciesId: String(outfit.species_id),
		colorId: String(outfit.color_id),
		pose: outfit.pose,
		wornItemIds: (outfit.item_ids?.worn || []).map((id) => String(id)),
		closetedItemIds: (outfit.item_ids?.closeted || []).map((id) => String(id)),
		creator: outfit.user ? { id: String(outfit.user.id) } : null,
		createdAt: outfit.created_at,
		updatedAt: outfit.updated_at,
	};
}

function getCSRFToken() {
	return document.querySelector("meta[name=csrf-token]")?.content;
}
