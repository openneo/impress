import React from "react";
import { Box, Center, DarkMode, Flex } from "@chakra-ui/react";
import gql from "graphql-tag";
import { useQuery } from "@apollo/client";

import OutfitThumbnail from "../components/OutfitThumbnail";
import { useOutfitPreview } from "../components/OutfitPreview";
import { loadable, ErrorBoundary, TestErrorSender } from "../util";
import { useAltStyle } from "../loaders/alt-styles";
import { getStyleName } from "./StyleTiles";

const OutfitControls = loadable(() => import("./OutfitControls"));

function WardrobePreviewAndControls({
	isLoading,
	outfitState,
	dispatchToOutfit,
	previewAltStyleId,
	onPreviewAltStyle,
}) {
	// Whether the current outfit preview has animations. Determines whether we
	// show the play/pause button.
	const [hasAnimations, setHasAnimations] = React.useState(false);

	const { appearance, preview } = useOutfitPreview({
		isLoading: isLoading,
		speciesId: outfitState.speciesId,
		colorId: outfitState.colorId,
		pose: outfitState.pose,
		altStyleId:
			previewAltStyleId !== undefined
				? previewAltStyleId
				: outfitState.altStyleId,
		appearanceId: outfitState.appearanceId,
		wornItemIds: outfitState.wornItemIds,
		onChangeHasAnimations: setHasAnimations,
		placeholder: <OutfitThumbnailIfCached outfitId={outfitState.id} />,
		"data-test-id": "wardrobe-outfit-preview",
	});

	return (
		<ErrorBoundary>
			<TestErrorSender />
			<Center position="absolute" top="0" bottom="0" left="0" right="0">
				<DarkMode>{preview}</DarkMode>
			</Center>
			{/* No pill if we're "previewing" what's already worn: nothing changes! */}
			{previewAltStyleId !== undefined &&
				previewAltStyleId !== outfitState.altStyleId && (
					<StylePreviewPill
						altStyleId={previewAltStyleId}
						speciesId={outfitState.speciesId}
					/>
				)}
			<Box position="absolute" top="0" bottom="0" left="0" right="0">
				<OutfitControls
					outfitState={outfitState}
					dispatchToOutfit={dispatchToOutfit}
					showAnimationControls={hasAnimations}
					appearance={appearance}
					onPreviewAltStyle={onPreviewAltStyle}
				/>
			</Box>
		</ErrorBoundary>
	);
}

/**
 * StylePreviewPill floats over the top of the outfit preview while we're
 * previewing a style, so it's clear the outfit itself hasn't changed.
 */
function StylePreviewPill({ altStyleId, speciesId }) {
	const { data: altStyle } = useAltStyle(altStyleId, speciesId);
	const name =
		altStyleId == null
			? "No style"
			: altStyle != null
				? getStyleName(altStyle)
				: null;

	return (
		<Flex
			position="absolute"
			top={{ base: "2", md: "20" }}
			left="0"
			right="0"
			justify="center"
			paddingX="4"
			// Stay out of the way of the outfit controls underneath.
			pointerEvents="none"
			zIndex="1"
		>
			<Box
				background="blackAlpha.700"
				color="white"
				borderRadius="full"
				paddingX="3"
				paddingY="1"
				fontSize="sm"
				boxShadow="md"
				maxWidth="100%"
				overflow="hidden"
				textOverflow="ellipsis"
				whiteSpace="nowrap"
				role="status"
			>
				<Box as="span" opacity="0.8">
					Previewing
				</Box>
				{name && (
					<>
						{" · "}
						<Box as="span" fontWeight="bold">
							{name}
						</Box>
					</>
				)}
			</Box>
		</Flex>
	);
}

/**
 * OutfitThumbnailIfCached will render an OutfitThumbnail as a placeholder for
 * the outfit preview... but only if we already have the data to generate the
 * thumbnail stored in our local Apollo GraphQL cache.
 *
 * This means that, when you come from the Your Outfits page, we can show the
 * outfit thumbnail instantly while everything else loads. But on direct
 * navigation, this does nothing, and we just wait for the preview to load in
 * like usual!
 */
function OutfitThumbnailIfCached({ outfitId }) {
	const { data } = useQuery(
		gql`
			query OutfitThumbnailIfCached($outfitId: ID!) {
				outfit(id: $outfitId) {
					id
					updatedAt
				}
			}
		`,
		{
			variables: {
				outfitId,
			},
			skip: outfitId == null,
			fetchPolicy: "cache-only",
			onError: (e) => console.error(e),
		},
	);

	if (!data?.outfit) {
		return null;
	}

	return (
		<OutfitThumbnail
			outfitId={data.outfit.id}
			updatedAt={data.outfit.updatedAt}
			alt=""
			objectFit="contain"
			width="100%"
			height="100%"
			filter="blur(2px)"
		/>
	);
}

export default WardrobePreviewAndControls;
