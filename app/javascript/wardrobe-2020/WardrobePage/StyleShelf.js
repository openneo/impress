import React from "react";
import { Box, Button, Flex } from "@chakra-ui/react";
import { ChevronRightIcon } from "@chakra-ui/icons";

import { StyleTile, useStyleHoverPreview } from "./StyleTiles";

// The shelf's tiles are at least this wide, with this gap between them. We
// show as many as fit in one row.
const TILE_MIN_WIDTH_PX = 72;
const TILE_GAP_PX = 8;

/**
 * StyleShelf sits above ordinary item search results, when the search text
 * matches some NC Pet Styles for this pet: e.g. "nostalgic", "faerie", or
 * "token". It shows one row of them, and "See all", which switches to the NC
 * Pet Styles search with the same text.
 *
 * Like in the full grid, clicking a style wears it (or takes it off), and
 * resting the mouse on it previews it on the pet.
 *
 * For the keyboard, the shelf sits between the search field and the items:
 * `firstTileRef` goes on the tile that Down from the search field should
 * focus, and Up and Down from the shelf call `onMoveFocusUp` and
 * `onMoveFocusDown`. Left and Right move between styles, without wrapping
 * around at the ends. (The ref is for the shelf's <form> element, so the
 * items can find their way back up to it.)
 */
const StyleShelf = React.forwardRef(function StyleShelf(
	{
		altStyles,
		outfitState,
		dispatchToOutfit,
		onPreviewAltStyle,
		onSeeAll,
		firstTileRef,
		onMoveFocusUp,
		onMoveFocusDown,
	},
	ref,
) {
	const { altStyleId } = outfitState;

	const rowRef = React.useRef(null);
	const numColumns = useNumColumns(rowRef);
	const visibleAltStyles = altStyles.slice(0, numColumns);

	const { startHover, endHover } = useStyleHoverPreview({
		onPreview: onPreviewAltStyle,
	});

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

	const visibleStyleIds = visibleAltStyles.map((s) => s.id);
	const focusStyleId = visibleStyleIds.includes(altStyleId)
		? altStyleId
		: visibleStyleIds[0];

	// The tiles are a radio group, whose arrow keys would wrap around at the
	// ends, and wear every style along the way. Instead, Up and Down leave the
	// shelf, and Left and Right stop at the ends.
	const onKeyDown = (e) => {
		if (e.target.name !== "style") {
			return;
		}
		const index = visibleStyleIds.indexOf(e.target.value);
		if (e.key === "ArrowUp") {
			onMoveFocusUp(e);
		} else if (e.key === "ArrowDown") {
			onMoveFocusDown(e);
		} else if (
			(e.key === "ArrowLeft" && index === 0) ||
			(e.key === "ArrowRight" && index === visibleStyleIds.length - 1)
		) {
			e.preventDefault();
		}
	};

	return (
		<Box
			as="form"
			ref={ref}
			paddingX="4"
			paddingTop="2"
			paddingBottom="3"
			onSubmit={(e) => e.preventDefault()}
			onKeyDown={onKeyDown}
			aria-label="NC Pet Styles"
		>
			<Flex align="baseline" justify="space-between" gap="2" marginBottom="1">
				<Box fontSize="sm">
					<Box as="span" fontWeight="bold">
						NC Pet Styles
					</Box>
					<Box as="span" opacity="0.7">
						{" · "}
						{altStyles.length} {altStyles.length === 1 ? "match" : "matches"}
					</Box>
				</Box>
				<Button
					size="xs"
					variant="ghost"
					rightIcon={<ChevronRightIcon />}
					onClick={() => {
						endHover();
						onSeeAll();
					}}
				>
					See all {altStyles.length}
				</Button>
			</Flex>
			<Box
				ref={rowRef}
				display="grid"
				gridTemplateColumns={`repeat(${numColumns}, 1fr)`}
				columnGap={`${TILE_GAP_PX}px`}
				onPointerLeave={endHover}
			>
				{visibleAltStyles.map((altStyle) => (
					<StyleTile
						key={altStyle.id}
						altStyle={altStyle}
						checked={altStyle.id === altStyleId}
						onChange={wearStyle}
						onDeselect={removeStyle}
						onHover={startHover}
						inputRef={altStyle.id === focusStyleId ? firstTileRef : null}
						showLabels
					/>
				))}
			</Box>
		</Box>
	);
});

/**
 * useNumColumns returns how many shelf tiles fit across the element, and
 * keeps it up to date as the element resizes. We measure before the first
 * paint, so we don't flash the wrong number of tiles.
 */
function useNumColumns(ref) {
	const [numColumns, setNumColumns] = React.useState(1);

	React.useLayoutEffect(() => {
		const element = ref.current;
		if (element == null) {
			return;
		}

		const update = (width) =>
			setNumColumns(
				Math.max(
					1,
					Math.floor((width + TILE_GAP_PX) / (TILE_MIN_WIDTH_PX + TILE_GAP_PX)),
				),
			);
		update(element.getBoundingClientRect().width);

		if (typeof ResizeObserver === "undefined") {
			return;
		}
		const observer = new ResizeObserver(([entry]) =>
			update(entry.contentRect.width),
		);
		observer.observe(element);
		return () => observer.disconnect();
	}, [ref]);

	return numColumns;
}

export default StyleShelf;
