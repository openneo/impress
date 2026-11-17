import React from "react";
import { ClassNames } from "@emotion/react";
import {
	Box,
	Flex,
	VisuallyHidden,
	useColorModeValue,
	useTheme,
	useToken,
} from "@chakra-ui/react";

import { safeImageUrl } from "../util";

// From https://twemoji.twitter.com/, thank you!
import twemojiSmile from "../images/twemoji/smile.svg";

/**
 * StyleTiles holds the pieces for showing NC Pet Styles as pictures: the tile
 * itself, the grid of tiles grouped by color, the hover-to-preview behavior,
 * and the helpers for naming, matching, and grouping styles.
 *
 * The PosePicker's Styles tab uses these today, and the wardrobe's search
 * panel can use them too. Nothing in here assumes it's inside a popover.
 */

// How long the mouse rests on a style before we preview it on the pet. Short
// enough to feel live, long enough that sweeping across the grid doesn't load
// every style along the way.
export const STYLE_PREVIEW_DELAY_MS = 200;

/**
 * useStyleHoverPreview manages previewing a style on the pet while the mouse
 * rests on its tile. The rule is simple: the preview follows the mouse, and
 * *anything else* the user does (picking a style, typing a filter, leaving
 * the grid, hiding it) ends it. Callers handle the "anything else" by calling
 * `endHover`; we handle hiding and unmounting ourselves.
 *
 * `onPreview` is called with the style ID to preview, `null` to preview no
 * style, or `undefined` to end the preview. `isShowing` should be false while
 * the tiles are on their way out (e.g. during a popover's fade), so that we
 * stop previewing.
 *
 * Returns `hoveredStyleId` (to name the style in a caption: `undefined` for
 * none, `null` for the "Default" option), and the `startHover` and `endHover`
 * callbacks, which are stable as long as `onPreview` is.
 */
export function useStyleHoverPreview({ isShowing = true, onPreview }) {
	const [hoveredStyleId, setHoveredStyleId] = React.useState(undefined);

	const previewTimeoutRef = React.useRef(null);
	const isShowingRef = React.useRef(isShowing);
	isShowingRef.current = isShowing;

	const endHover = React.useCallback(() => {
		setHoveredStyleId(undefined);
		clearTimeout(previewTimeoutRef.current);
		onPreview?.(undefined);
	}, [onPreview]);

	const startHover = React.useCallback(
		(e, altStyleId) => {
			// Touch devices fire these too, but there the "hover" would stick after
			// the tap. Tapping selects the style anyway, so skip it. (We also skip
			// it if we're on our way out, e.g. during the popover's fade.)
			if (e.pointerType !== "mouse" || !isShowingRef.current) {
				return;
			}

			// Previewing a style can mean loading new item layers, so we wait for
			// the mouse to settle before asking for it.
			setHoveredStyleId(altStyleId);
			clearTimeout(previewTimeoutRef.current);
			previewTimeoutRef.current = setTimeout(() => {
				if (isShowingRef.current) {
					onPreview?.(altStyleId);
				}
			}, STYLE_PREVIEW_DELAY_MS);
		},
		[onPreview],
	);

	// We won't get a pointer event if the grid goes away under the mouse (it's
	// hidden, or we unmount), so end the preview ourselves.
	React.useEffect(() => {
		if (!isShowing) {
			endHover();
		}
	}, [isShowing, endHover]);
	React.useEffect(() => endHover, [endHover]);

	return { hoveredStyleId, startHover, endHover };
}

/**
 * StyleTileGroups renders style tiles in a grid per color group, each with a
 * sticky header naming the color and its style count. Get `groups` from
 * `groupAltStylesByColor`.
 *
 * The tiles are radios named "style", so the whole set is one group for the
 * arrow keys. Put this inside a scrolling box marked with
 * `data-style-scroll-container`: that's what tiles watch to lazy-load their
 * images, and what the headers stick to.
 *
 * - `tileSize` is the smallest a tile can be; the grid stretches tiles to
 *   fill each row. It can be responsive, like `{ base: "64px", md: "72px" }`.
 * - `showLabels` puts two short lines under each tile, naming it.
 * - `stickyTop` is where the headers stick, relative to the scroll box. (Use
 *   a negative value to cover the box's own padding.)
 * - `onDeselect`, if given, is called when the user clicks the style that's
 *   already selected, to take it off. Without it, that click does nothing.
 * - `initialFocusRef` goes on the tile for `focusStyleId`, which is the
 *   selected style unless you say otherwise.
 * - `scrollMarginBottom` is how much room to leave below a tile when the
 *   keyboard scrolls it into view, e.g. to clear a sticky bar at the bottom.
 *   (The radio is pinned to the tile's top-left corner, so include the
 *   tile's own height too.)
 */
export function StyleTileGroups({
	groups,
	selectedStyleId,
	onChange,
	onDeselect = null,
	onHover,
	initialFocusRef = null,
	focusStyleId = selectedStyleId,
	scrollMarginBottom = null,
	tileSize = "48px",
	showLabels = false,
	stickyTop = "0",
	tileGap = "1",
	groupHeaderBackground,
	groupHeaderPaddingX = "0",
}) {
	const defaultGroupHeaderBackground = useColorModeValue("white", "gray.700");
	const gridTemplateColumns = mapResponsive(
		tileSize,
		(size) => `repeat(auto-fill, minmax(${size}, 1fr))`,
	);

	return groups.map((group) => (
		<Box key={group.colorId} role="group" aria-label={group.colorName}>
			<Flex
				position="sticky"
				top={stickyTop}
				zIndex="1"
				background={groupHeaderBackground ?? defaultGroupHeaderBackground}
				align="baseline"
				justify="space-between"
				gap="2"
				fontSize="xs"
				paddingY="1"
				paddingX={groupHeaderPaddingX}
			>
				<Box fontWeight="bold">
					{group.colorName}
					{group.isPetColor && (
						<Box as="span" fontWeight="normal" opacity="0.7">
							{" "}
							· your pet's color
						</Box>
					)}
				</Box>
				<Box flex="0 0 auto" opacity="0.7">
					{group.altStyles.length}{" "}
					{group.altStyles.length === 1 ? "style" : "styles"}
				</Box>
			</Flex>
			<Box
				display="grid"
				gridTemplateColumns={gridTemplateColumns}
				gap={tileGap}
				marginBottom="2"
			>
				{group.altStyles.map((altStyle) => (
					<StyleTile
						key={altStyle.id}
						altStyle={altStyle}
						checked={selectedStyleId === altStyle.id}
						onChange={onChange}
						onDeselect={onDeselect}
						onHover={onHover}
						inputRef={focusStyleId === altStyle.id ? initialFocusRef : null}
						showLabels={showLabels}
						scrollMarginBottom={scrollMarginBottom}
					/>
				))}
			</Box>
		</Box>
	));
}

// Apply `fn` to a Chakra style value, which might be responsive (an object
// of breakpoint values) or just one value.
function mapResponsive(value, fn) {
	if (value != null && typeof value === "object") {
		return Object.fromEntries(
			Object.entries(value).map(([key, v]) => [key, fn(v)]),
		);
	}
	return fn(value);
}

/**
 * StyleTile is a picture of the pet in this style, backed by a radio input.
 * Pass `altStyle={null}` for the "Default" (no style) option.
 *
 * If `description` is given, the tile is laid out as a row instead, with the
 * picture on the left and its name and description beside it. If
 * `showLabels` is set, two short lines under the picture name it instead.
 *
 * NOTE: This is memoized, because there can be 100+ of these, and the grid
 *       re-renders whenever the mouse moves from one to the next. Keep its
 *       props stable!
 */
export const StyleTile = React.memo(function StyleTile({
	altStyle,
	checked,
	onChange,
	onDeselect = null,
	onHover,
	inputRef,
	description = null,
	showLabels = false,
	scrollMarginBottom = null,
}) {
	const theme = useTheme();
	const selectedBorderColor = useColorModeValue(
		theme.colors.green["600"],
		theme.colors.green["300"],
	);
	const hoverBorderColor = theme.colors.gray["400"];
	const unlabeledBorderColor = useColorModeValue(
		theme.colors.gray["300"],
		theme.colors.gray["500"],
	);
	const tileBackground = useColorModeValue(
		theme.colors.gray["100"],
		theme.colors.whiteAlpha["200"],
	);
	const outlineShadow = useToken("shadows", "outline");

	const tileRef = React.useRef(null);
	const didDeselectBySpaceRef = React.useRef(false);
	const shouldLoadImage = useHasBeenNearView(tileRef);

	const id = altStyle?.id ?? null;
	const name = getStyleName(altStyle);
	const imageUrl = getStyleImageUrl(altStyle);
	const isLabeled = altStyle == null || altStyle.isLabeled;

	return (
		<ClassNames>
			{({ css }) => (
				<Box
					as="label"
					display={description != null ? "flex" : "block"}
					alignItems="center"
					gap="3"
					position="relative"
					cursor="pointer"
					onPointerEnter={(e) => onHover(e, id)}
					onClick={(e) => {
						// HACK: We need the timeout to beat the popover's focus stealing!
						const input = e.currentTarget.querySelector("input");
						setTimeout(() => input.focus(), 0);
					}}
				>
					<VisuallyHidden
						as="input"
						type="radio"
						name="style"
						aria-label={name}
						value={id ?? ""}
						checked={checked}
						onChange={() => onChange(id)}
						onClick={() => {
							// Clicking the radio that's already selected doesn't fire
							// `onChange`, so this is how you take a style off. (We check the
							// `checked` prop, not the input: by now, the browser has already
							// checked it either way.) We wait for the click to finish, so
							// that the radio's own state change doesn't undo ours.
							if (checked && onDeselect != null) {
								setTimeout(() => onDeselect(id), 0);
							}
						}}
						onKeyDown={(e) => {
							// Space on the selected radio doesn't click it, either, so we
							// handle that ourselves too.
							if (e.key === " " && checked && onDeselect != null) {
								e.preventDefault();
								didDeselectBySpaceRef.current = true;
								onDeselect(id);
							}
						}}
						onKeyUp={(e) => {
							// Some browsers click on Space's keyup even if we prevented its
							// keydown, which would put the style right back on. Block that.
							if (e.key === " " && didDeselectBySpaceRef.current) {
								e.preventDefault();
								didDeselectBySpaceRef.current = false;
							}
						}}
						ref={inputRef}
						// HACK: Without this, the page extends super long. I think this is
						//       because the VisuallyHidden just uses `position: absolute`,
						//       which makes it float invisibly *beyond* the scrolling
						//       container it's in, extending the page? But if we put it at
						//       the top-left corner instead, it doesn't.
						left="0"
						top="0"
						// When the keyboard scrolls this into view, don't leave it
						// hidden under the sticky group heading.
						style={{
							scrollMarginTop: "2rem",
							scrollMarginBottom: scrollMarginBottom ?? undefined,
						}}
					/>
					<Box
						ref={tileRef}
						flex="0 0 auto"
						width={description != null ? "52px" : "auto"}
						borderRadius="md"
						overflow="hidden"
						className={css`
							aspect-ratio: 1;
							background: ${tileBackground};
							border: 2px ${isLabeled ? "solid" : "dashed"}
								${isLabeled ? "transparent" : unlabeledBorderColor};
							transition:
								border-color 0.2s,
								box-shadow 0.2s;

							label:hover > & {
								border-color: ${hoverBorderColor};
							}

							input:focus + & {
								box-shadow: ${outlineShadow};
							}

							input:checked + & {
								border: 2px solid ${selectedBorderColor};
							}
						`}
					>
						{imageUrl != null ? (
							<img
								// The grid can hold 100+ of these, and they're the full-size
								// pet layers (~50kb each), so we only load the ones scrolled
								// near view. (It's the same file the outfit preview uses, so
								// it's often already in the browser's cache by then.)
								src={shouldLoadImage ? imageUrl : undefined}
								alt=""
								loading="lazy"
								decoding="async"
								// The image's own size, so the browser can lay it out before
								// it loads.
								width="600"
								height="600"
								// The pet only fills the middle of its 600x600 canvas, so
								// zoom in. (This crops the very largest pets a little.)
								className={css`
									display: block;
									width: 100%;
									height: 100%;
									object-fit: contain;
									transform: scale(1.7);
								`}
							/>
						) : (
							<Flex align="center" justify="center" height="100%">
								<img src={twemojiSmile} alt="" width={20} height={20} />
							</Flex>
						)}
					</Box>
					{description != null && (
						<Box fontSize="sm" lineHeight="short">
							<Box fontWeight={checked ? "bold" : "normal"}>{name}</Box>
							<Box fontSize="xs" opacity="0.7">
								{description}
							</Box>
						</Box>
					)}
					{showLabels && description == null && (
						<StyleTileLabels altStyle={altStyle} isChecked={checked} />
					)}
				</Box>
			)}
		</ClassNames>
	);
});

/**
 * StyleTileLabels is the two short lines under a tile: the series, like
 * "Nostalgic"; and the Prismatic variant, like "Pink", if any. They always
 * take up two lines, so the rows of the grid line up.
 */
function StyleTileLabels({ altStyle, isChecked }) {
	const { seriesLabel, variantLabel } = getStyleTileLabels(altStyle);

	return (
		<Box
			fontSize="xs"
			lineHeight="short"
			textAlign="center"
			marginTop="1"
			// Two lines, whether or not there's a variant.
			minHeight="2.5em"
		>
			<Box
				fontWeight={isChecked ? "bold" : "normal"}
				overflow="hidden"
				textOverflow="ellipsis"
				whiteSpace="nowrap"
			>
				{seriesLabel}
			</Box>
			<Box
				opacity="0.7"
				overflow="hidden"
				textOverflow="ellipsis"
				whiteSpace="nowrap"
			>
				{variantLabel}
			</Box>
		</Box>
	);
}

/**
 * useHasBeenNearView returns whether the element has ever been scrolled into
 * (or nearly into) view within its style grid's scrolling box, the nearest
 * `[data-style-scroll-container]`. Once true, it stays true.
 *
 * We use this instead of relying on `loading="lazy"` alone: browsers start
 * lazy images long before they're visible (Chrome: up to ~1250px away, even
 * inside a small scrolling box), which here meant fetching most of the grid
 * as soon as it opened.
 */
export function useHasBeenNearView(ref) {
	const [hasBeenNearView, setHasBeenNearView] = React.useState(false);

	React.useEffect(() => {
		const element = ref.current;
		if (hasBeenNearView || element == null) {
			return;
		}

		// If we can't observe, just load. (`loading="lazy"` is still on the image.)
		if (typeof IntersectionObserver === "undefined") {
			setHasBeenNearView(true);
			return;
		}

		const observer = new IntersectionObserver(
			(entries) => {
				if (entries.some((entry) => entry.isIntersecting)) {
					setHasBeenNearView(true);
				}
			},
			{
				root: element.closest("[data-style-scroll-container]"),
				// About two rows of tiles ahead, so normal scrolling stays filled in.
				rootMargin: "120px 0px",
			},
		);
		observer.observe(element);
		return () => observer.disconnect();
	}, [ref, hasBeenNearView]);

	return hasBeenNearView;
}

/**
 * StyleCaption names the style that's hovered or selected, since the grid
 * itself is pictures only. It always takes up two lines, so the layout
 * doesn't jump around as the mouse moves.
 */
export function StyleCaption({ altStyle }) {
	const { name, variantName } = getStyleNameParts(altStyle);

	return (
		<Box fontSize="sm" lineHeight="short" minHeight="2.75em">
			<Box fontWeight="bold">{name}</Box>
			<Box fontSize="xs" opacity="0.7">
				{variantName}
			</Box>
		</Box>
	);
}

/**
 * Split a style's name into its main name and its Prismatic variant, if any:
 * "Prismatic Cyan: Nostalgic Faerie" is "Nostalgic Faerie", in "Prismatic
 * Cyan".
 */
export function getStyleNameParts(altStyle) {
	if (altStyle == null) {
		return { name: "Default", variantName: "No style" };
	}

	if (!altStyle.isLabeled) {
		// The server names these for us, like "Unnamed Faerie style".
		return {
			name: altStyle.adjectiveName,
			variantName: "We haven't named this one yet",
		};
	}

	const [variantName, ...rest] = altStyle.adjectiveName.split(": ");
	if (rest.length === 0) {
		return { name: altStyle.adjectiveName, variantName: "" };
	}
	return { name: rest.join(": "), variantName };
}

export function getStyleName(altStyle) {
	const { name, variantName } = getStyleNameParts(altStyle);
	return altStyle?.isLabeled && variantName ? `${variantName}: ${name}` : name;
}

/**
 * The short label for the PosePicker button: the first word of the style's
 * main name, like "Nostalgic".
 */
export function getStyleLabel(altStyle) {
	if (!altStyle.isLabeled) {
		return "Unnamed";
	}
	return getStyleNameParts(altStyle).name.split(/\s+/)[0];
}

/**
 * The two short labels under a tile, when it has them: the series, like
 * "Nostalgic", and the Prismatic variant without the word "Prismatic", like
 * "Pink". The color is left out, because the tiles are already grouped by it.
 */
export function getStyleTileLabels(altStyle) {
	if (altStyle == null) {
		return { seriesLabel: "Default", variantLabel: "" };
	}

	if (!altStyle.isLabeled) {
		return { seriesLabel: "Unnamed", variantLabel: "" };
	}

	// Some styles have a full name, but we don't know their series yet, so the
	// server sends a placeholder like "<New?>" as the series. Use the name.
	const { name, variantName } = getStyleNameParts(altStyle);
	const hasSeriesName =
		altStyle.seriesMainName != null && !altStyle.seriesMainName.startsWith("<");
	return {
		seriesLabel: hasSeriesName ? altStyle.seriesMainName : name,
		variantLabel: variantName.replace(/^Prismatic\s+/i, ""),
	};
}

/**
 * The picture for a style's tile: the pet layer itself. (Styles are almost
 * always a single layer. The NC item thumbnail is only a fallback, because
 * it's small, and new styles don't have one until we've labeled them.)
 */
export function getStyleImageUrl(altStyle) {
	if (altStyle == null) {
		return null;
	}

	const layerImageUrl = altStyle.appearance.layers[0]?.imageUrl;
	return safeImageUrl(layerImageUrl ?? altStyle.thumbnailUrl);
}

// Whether every word of the filter query appears somewhere in the text.
export function matchesQuery(text, query) {
	const lowerText = text.toLowerCase();
	const queryWords = query.toLowerCase().split(/\s+/).filter(Boolean);
	return queryWords.every((word) => lowerText.includes(word));
}

// Whether the "Default" option should show for this filter query. (It always
// shows when there's no query.)
export function matchesDefaultStyle(query) {
	return matchesQuery("default no style", query);
}

/**
 * The text a filter query matches a style against: its name, color, and
 * species, plus words people use for styles in general (like "token", as in
 * the NC item that unlocks it). Styles we haven't named yet only have a
 * color, plus "unnamed" and "new" as ways to find them.
 */
function getStyleSearchText(altStyle) {
	const name = altStyle.isLabeled ? altStyle.adjectiveName : "unnamed new";
	const speciesName = altStyle.speciesName ?? "";
	return `${name} ${altStyle.colorName} ${speciesName} nc pet style token`;
}

/**
 * Group styles by color for a style grid, keeping only the ones that match
 * the filter query. The pet's own color goes first, since those are the
 * styles people most often come looking for; then colors A-Z.
 */
export function groupAltStylesByColor(altStyles, { query = "", petColorId }) {
	const groupsByColorId = new Map();
	for (const altStyle of altStyles) {
		if (!matchesQuery(getStyleSearchText(altStyle), query)) {
			continue;
		}

		if (!groupsByColorId.has(altStyle.colorId)) {
			groupsByColorId.set(altStyle.colorId, {
				colorId: altStyle.colorId,
				colorName: altStyle.colorName ?? "Other",
				isPetColor: altStyle.colorId === String(petColorId),
				altStyles: [],
			});
		}
		groupsByColorId.get(altStyle.colorId).altStyles.push(altStyle);
	}

	const groups = [...groupsByColorId.values()];
	groups.sort(
		(a, b) =>
			b.isPetColor - a.isPetColor || a.colorName.localeCompare(b.colorName),
	);

	// Within a color, keep the order the server gave us (by series, then by
	// Prismatic variant), but with the styles we haven't named yet at the end.
	for (const group of groups) {
		group.altStyles.sort((a, b) => b.isLabeled - a.isLabeled);
	}

	return groups;
}
