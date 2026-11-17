import React from "react";
import { Box, Flex, Link, Skeleton, useColorModeValue } from "@chakra-ui/react";
import { ExternalLinkIcon } from "@chakra-ui/icons";

import { MajorErrorMessage } from "../util";
import { useAltStylesForSpecies } from "../loaders/alt-styles";
import {
	StyleTileGroups,
	getStyleNameParts,
	groupAltStylesByColor,
	useStyleHoverPreview,
} from "./StyleTiles";

/**
 * StyleSearchResults is what the search panel shows in NC Pet Styles mode: a
 * grid of the styles for this species, as pictures, filtered by the search
 * text and grouped by color.
 *
 * Clicking a style wears it, and clicking the worn style takes it off. With a
 * mouse, resting on a style previews it on the pet, via `onPreviewAltStyle`.
 * A caption bar at the bottom names the style being hovered, or else the one
 * being worn.
 *
 * We filter in the browser, because the wardrobe already loads every style for
 * the species (with its layers) for the PosePicker, so there's nothing more to
 * ask the server for.
 */
function StyleSearchResults({
	query,
	outfitState,
	dispatchToOutfit,
	firstSearchResultRef,
	onPreviewAltStyle,
	scrollToTop,
	onMoveFocusUpToQuery,
}) {
	const { speciesId, colorId, altStyleId } = outfitState;
	const { isLoading, error, data } = useAltStylesForSpecies(speciesId);
	const altStyles = React.useMemo(() => data ?? [], [data]);

	const groups = React.useMemo(
		() =>
			groupAltStylesByColor(altStyles, {
				query: query.value,
				petColorId: colorId,
			}),
		[altStyles, query.value, colorId],
	);

	const { hoveredStyleId, startHover, endHover } = useStyleHoverPreview({
		onPreview: onPreviewAltStyle,
	});

	// Typing can take the style under the mouse out of the grid, and changing
	// the pet replaces the grid entirely, so either one ends the preview.
	React.useEffect(() => {
		endHover();
	}, [query.value, speciesId, colorId, endHover]);

	// Start at the top of the grid when it opens, or when the results change.
	// (The scroll container is shared with item search, which might have been
	// scrolled down.)
	React.useEffect(() => {
		scrollToTop();
	}, [query.value, speciesId, scrollToTop]);

	// Picking a style ends the preview, so that the pet shows what's actually
	// worn. (This matters for the keyboard: arrow keys change the selection
	// while the mouse might still be resting on some other style.)
	// NOTE: These need to be stable, so the memoized tiles don't all re-render
	//       whenever we do.
	const wearStyle = React.useCallback(
		(altStyleId) => {
			endHover();
			dispatchToOutfit({ type: "setStyle", altStyleId });
		},
		[endHover, dispatchToOutfit],
	);
	const removeStyle = React.useCallback(() => {
		endHover();
		dispatchToOutfit({ type: "setStyle", altStyleId: null });
	}, [endHover, dispatchToOutfit]);

	// Pressing Down in the search field moves focus to the worn style, if it's
	// in the grid, or else the first style.
	const visibleStyleIds = groups.flatMap((g) => g.altStyles.map((s) => s.id));
	const focusStyleId = visibleStyleIds.includes(altStyleId)
		? altStyleId
		: visibleStyleIds[0];

	// The arrow keys move through the styles, like a radio group does. But
	// rather than wrapping around at the ends (and wearing whatever style is
	// at the other end!), Up from the first style goes back to the search
	// field, like it does in item search; and the last style stays put.
	const onKeyDown = (e) => {
		if (e.target.name !== "style") {
			return;
		}
		const index = visibleStyleIds.indexOf(e.target.value);
		if (index === 0 && ["ArrowUp", "ArrowLeft"].includes(e.key)) {
			onMoveFocusUpToQuery(e);
		} else if (
			index === visibleStyleIds.length - 1 &&
			["ArrowDown", "ArrowRight"].includes(e.key)
		) {
			e.preventDefault();
		}
	};

	const captionStyleId =
		hoveredStyleId !== undefined ? hoveredStyleId : altStyleId;
	const captionStyle = altStyles.find((s) => s.id === captionStyleId) ?? null;

	const background = useColorModeValue("white", "gray.900");

	if (error) {
		return <MajorErrorMessage error={error} variant="network" />;
	}

	return (
		<Flex
			as="form"
			direction="column"
			// Fill the scroll container, so the caption bar sits at the bottom even
			// when there are only a few styles.
			flex="1 0 auto"
			onSubmit={(e) => e.preventDefault()}
			onKeyDown={onKeyDown}
		>
			<Box
				flex="1 0 auto"
				paddingX="4"
				paddingTop="2"
				onPointerLeave={endHover}
			>
				{isLoading ? (
					<StyleSearchResultsSkeleton />
				) : groups.length > 0 ? (
					<StyleTileGroups
						groups={groups}
						selectedStyleId={altStyleId}
						onChange={wearStyle}
						onDeselect={removeStyle}
						onHover={startHover}
						initialFocusRef={firstSearchResultRef}
						focusStyleId={focusStyleId}
						// Clear the caption bar, plus the tile and its labels.
						scrollMarginBottom="calc(3.5rem + 7.5rem)"
						tileSize={{ base: "64px", md: "72px" }}
						tileGap="2"
						showLabels
						groupHeaderBackground={background}
					/>
				) : (
					<Box fontSize="sm" textAlign="center" opacity="0.7" paddingY="4">
						{query.value.trim()
							? `No styles match “${query.value.trim()}”.`
							: "We don't know of any styles for this pet yet."}
					</Box>
				)}
			</Box>
			<StyleSearchCaptionBar
				altStyle={captionStyle}
				isHovered={hoveredStyleId !== undefined}
				isWorn={captionStyleId != null && captionStyleId === altStyleId}
				background={background}
			/>
		</Flex>
	);
}

/**
 * StyleSearchCaptionBar is pinned to the bottom of the results, and names the
 * style that's hovered, or else the one that's worn. For a worn style that
 * we've named, it links to the style's token item page, for more info.
 *
 * (We don't link the hovered style: moving the mouse down to the link would
 * leave the grid, which ends the hover, which would swap the link for the
 * worn style's, right as you go to click it!)
 */
function StyleSearchCaptionBar({ altStyle, isHovered, isWorn, background }) {
	const borderColor = useColorModeValue("gray.200", "whiteAlpha.300");

	let content;
	if (altStyle == null) {
		content = (
			<Box fontSize="sm" opacity="0.7">
				No style worn yet. Pick one to try it on!
			</Box>
		);
	} else {
		const { name, variantName } = getStyleNameParts(altStyle);
		content = (
			<>
				<Box fontSize="sm" lineHeight="short" minWidth="0">
					<Box fontSize="xs" opacity="0.7">
						{isHovered ? "Previewing" : "Wearing"}
					</Box>
					<Box overflow="hidden" textOverflow="ellipsis" whiteSpace="nowrap">
						<Box as="span" fontWeight="bold">
							{name}
						</Box>
						{variantName && (
							<Box as="span" opacity="0.7">
								{" · "}
								{variantName}
							</Box>
						)}
					</Box>
				</Box>
				{isHovered ? (
					<Box fontSize="xs" opacity="0.7" flex="0 0 auto">
						{isWorn ? "Click to take it off" : "Click to wear"}
					</Box>
				) : (
					altStyle.isLabeled && (
						<Link
							href={`/items/${altStyle.id}`}
							isExternal
							fontSize="sm"
							flex="0 0 auto"
						>
							More info <ExternalLinkIcon marginTop="-2px" />
						</Link>
					)
				)}
			</>
		);
	}

	return (
		<Flex
			position="sticky"
			bottom="0"
			zIndex="2"
			background={background}
			borderTopWidth="1px"
			borderColor={borderColor}
			paddingX="5"
			paddingY="2"
			minHeight="3.5rem"
			align="center"
			justify="space-between"
			gap="3"
		>
			{content}
		</Flex>
	);
}

function StyleSearchResultsSkeleton() {
	return (
		<Box>
			<Skeleton height="1rem" width="8rem" marginY="1" />
			<Box
				display="grid"
				gridTemplateColumns={{
					base: "repeat(auto-fill, minmax(64px, 1fr))",
					md: "repeat(auto-fill, minmax(72px, 1fr))",
				}}
				gap="2"
			>
				{Array.from({ length: 12 }, (_, i) => (
					<Skeleton key={i} borderRadius="md" style={{ aspectRatio: "1" }} />
				))}
			</Box>
		</Box>
	);
}

export default StyleSearchResults;
