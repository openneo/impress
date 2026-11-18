import React from "react";
import { Box, Text, useColorModeValue, VisuallyHidden } from "@chakra-ui/react";

import Item, { ItemListContainer, ItemListSkeleton } from "./Item";
import PaginationToolbar from "../components/PaginationToolbar";
import { useSearchResults } from "./useSearchResults";
import { MajorErrorMessage, useDebounce } from "../util";
import StyleSearchResults from "./StyleSearchResults";
import StyleShelf from "./StyleShelf";
import { useAltStylesForSpecies } from "../loaders/alt-styles";
import { groupAltStylesByColor } from "./StyleTiles";

export const SEARCH_PER_PAGE = 30;

/**
 * SearchPanel shows item search results to the user, so they can preview them
 * and add them to their outfit!
 *
 * It's tightly coordinated with SearchToolbar, using refs to control special
 * keyboard and focus interactions.
 */
function SearchPanel({
	query,
	outfitState,
	dispatchToOutfit,
	scrollContainerRef,
	searchQueryRef,
	firstSearchResultRef,
	onPreviewAltStyle,
	onChangeQuery,
}) {
	const scrollToTop = React.useCallback(() => {
		if (scrollContainerRef.current) {
			scrollContainerRef.current.scrollTop = 0;
		}
	}, [scrollContainerRef]);

	// Sometimes we want to give focus back to the search field!
	const onMoveFocusUpToQuery = (e) => {
		if (searchQueryRef.current) {
			searchQueryRef.current.focus();
			e.preventDefault();
		}
	};

	return (
		<Box
			// Let NC Pet Styles mode fill the panel, so its caption bar can sit at
			// the bottom.
			minHeight="100%"
			display="flex"
			flexDirection="column"
			onKeyDown={(e) => {
				// This will catch any Escape presses when the user's focus is inside
				// the SearchPanel.
				if (e.key === "Escape") {
					onMoveFocusUpToQuery(e);
				}
			}}
		>
			{query.filterToItemKind === "STYLE" ? (
				<StyleSearchResults
					query={query}
					outfitState={outfitState}
					dispatchToOutfit={dispatchToOutfit}
					firstSearchResultRef={firstSearchResultRef}
					onPreviewAltStyle={onPreviewAltStyle}
					scrollToTop={scrollToTop}
					onMoveFocusUpToQuery={onMoveFocusUpToQuery}
				/>
			) : (
				<SearchResults
					// When the query changes, replace the SearchResults component with a
					// new instance. This resets both `currentPageNumber`, to take us back
					// to page 1; and also `itemIdsToReconsider`. That way, if you find an
					// item you like in one search, then immediately do a second search and
					// try a conflicting item, we'll restore the item you liked from your
					// first search!
					key={serializeQuery(query)}
					query={query}
					outfitState={outfitState}
					dispatchToOutfit={dispatchToOutfit}
					firstSearchResultRef={firstSearchResultRef}
					scrollToTop={scrollToTop}
					onMoveFocusUpToQuery={onMoveFocusUpToQuery}
					onPreviewAltStyle={onPreviewAltStyle}
					onSeeAllStyles={() => {
						onChangeQuery({ ...query, filterToItemKind: "STYLE" });
						// The "See all" button is about to go away, so put focus in the
						// search field, ready to narrow down the styles.
						searchQueryRef.current?.focus();
					}}
				/>
			)}
		</Box>
	);
}

/**
 * SearchResults loads the search results from the user's query, renders them,
 * and tracks the scroll container for infinite scrolling.
 *
 * For each item, we render a <label> with a visually-hidden checkbox and the
 * Item component (which will visually reflect the radio's state). This makes
 * the list screen-reader- and keyboard-accessible!
 */
function SearchResults({
	query,
	outfitState,
	dispatchToOutfit,
	firstSearchResultRef,
	scrollToTop,
	onMoveFocusUpToQuery,
	onPreviewAltStyle,
	onSeeAllStyles,
}) {
	const [currentPageNumber, setCurrentPageNumber] = React.useState(1);
	const { loading, error, items, numTotalPages } = useSearchResults(
		query,
		outfitState,
		currentPageNumber,
	);

	// Preload the previous and next page of search results, with this quick
	// ~hacky trick: just `useSearchResults` two more times, with some extra
	// attention to skip the query when we don't know if it will exist!
	useSearchResults(query, outfitState, currentPageNumber - 1, {
		skip: currentPageNumber <= 1,
	});
	useSearchResults(query, outfitState, currentPageNumber + 1, {
		skip: numTotalPages == null || currentPageNumber >= numTotalPages,
	});

	// This will save the `wornItemIds` when the SearchResults first mounts, and
	// keep it saved even after the outfit changes. We use this to try to restore
	// these items after the user makes changes, e.g., after they try on another
	// Background we want to restore the previous one!
	const [itemIdsToReconsider] = React.useState(outfitState.wornItemIds);

	// Whenever the page number changes, scroll back to the top!
	React.useEffect(() => scrollToTop(), [currentPageNumber, scrollToTop]);

	// Wait for a pause in typing before showing the styles shelf, like the item
	// results do, so it doesn't flicker in and out with each keystroke.
	const debouncedQueryText = useDebounce(query.value, 300, {
		waitForFirstPause: true,
		initialValue: "",
	});

	// The NC Pet Styles that match this search, for the shelf above the items.
	const { data: speciesAltStyles } = useAltStylesForSpecies(
		outfitState.speciesId,
	);
	const shelfAltStyles = React.useMemo(() => {
		if (
			speciesAltStyles == null ||
			!debouncedQueryText.trim() ||
			!canMatchStyles(query)
		) {
			return [];
		}
		const groups = groupAltStylesByColor(speciesAltStyles, {
			query: debouncedQueryText,
			petColorId: outfitState.colorId,
		});
		return groups.flatMap((g) => g.altStyles);
	}, [speciesAltStyles, debouncedQueryText, query, outfitState.colorId]);
	const hasShelf = currentPageNumber === 1 && shelfAltStyles.length > 0;

	// The arrow keys go from the search field, to the shelf (if any), to the
	// items. So Down from the field goes to the shelf if it's there, and the
	// shelf and the first item point at each other.
	const shelfRef = React.useRef(null);
	const firstItemRef = React.useRef(null);

	// You can use UpArrow/DownArrow to navigate between items, and even back up
	// to the shelf or the search field!
	const goToPrevItem = React.useCallback(
		(e) => {
			const prevLabel = e.target.closest("label").previousSibling;
			if (prevLabel) {
				prevLabel.querySelector("input[type=checkbox]").focus();
				prevLabel.scrollIntoView({ block: "center" });
				e.preventDefault();
			} else if (shelfRef.current != null) {
				focusShelf(shelfRef.current);
				e.preventDefault();
			} else {
				// If we're at the top of the list, move back up to the search box!
				onMoveFocusUpToQuery(e);
			}
		},
		[onMoveFocusUpToQuery],
	);
	const goToNextItem = React.useCallback((e) => {
		const nextLabel = e.target.closest("label").nextSibling;
		if (nextLabel) {
			nextLabel.querySelector("input[type=checkbox]").focus();
			nextLabel.scrollIntoView({ block: "center" });
			e.preventDefault();
		}
	}, []);

	const searchPanelBackground = useColorModeValue("white", "gray.900");

	if (error) {
		return <MajorErrorMessage error={error} variant="network" />;
	}

	// Finally, render the item list, with checkboxes and Item components!
	// We also render some extra skeleton items at the bottom during infinite
	// scroll loading.
	return (
		<Box>
			<Box
				position="sticky"
				top="0"
				background={searchPanelBackground}
				zIndex="2"
				paddingX="5"
				paddingBottom="2"
				paddingTop="1"
			>
				<PaginationToolbar
					numTotalPages={numTotalPages}
					currentPageNumber={currentPageNumber}
					goToPageNumber={setCurrentPageNumber}
					buildPageUrl={() => null}
					size="sm"
				/>
			</Box>
			{hasShelf && (
				<StyleShelf
					ref={shelfRef}
					altStyles={shelfAltStyles}
					outfitState={outfitState}
					dispatchToOutfit={dispatchToOutfit}
					onPreviewAltStyle={onPreviewAltStyle}
					onSeeAll={onSeeAllStyles}
					firstTileRef={firstSearchResultRef}
					onMoveFocusUp={onMoveFocusUpToQuery}
					onMoveFocusDown={(e) => {
						if (firstItemRef.current != null) {
							firstItemRef.current.focus();
							e.preventDefault();
						}
					}}
				/>
			)}
			<ItemListContainer paddingX="4" paddingBottom="2">
				{items.map((item, index) => (
					<SearchResultItem
						key={item.id}
						item={item}
						itemIdsToReconsider={itemIdsToReconsider}
						isWorn={outfitState.wornItemIds.includes(item.id)}
						isInOutfit={outfitState.allItemIds.includes(item.id)}
						dispatchToOutfit={dispatchToOutfit}
						checkboxRef={
							index === 0
								? hasShelf
									? firstItemRef
									: firstSearchResultRef
								: null
						}
						goToPrevItem={goToPrevItem}
						goToNextItem={goToNextItem}
					/>
				))}
			</ItemListContainer>
			{loading && (
				<ItemListSkeleton
					count={SEARCH_PER_PAGE}
					paddingX="4"
					paddingBottom="2"
				/>
			)}
			{!loading && items.length === 0 && (
				<Text paddingX="4">
					We couldn't find any matching items{" "}
					<span role="img" aria-label="(thinking emoji)">
						🤔
					</span>{" "}
					Try again?
				</Text>
			)}
		</Box>
	);
}

function SearchResultItem({
	item,
	itemIdsToReconsider,
	isWorn,
	isInOutfit,
	dispatchToOutfit,
	checkboxRef,
	goToPrevItem,
	goToNextItem,
}) {
	// It's important to use `useCallback` for `onRemove`, to avoid re-rendering
	// the whole list of <Item>s!
	const onRemove = React.useCallback(
		() =>
			dispatchToOutfit({
				type: "removeItem",
				itemId: item.id,
				itemIdsToReconsider,
			}),
		[item.id, itemIdsToReconsider, dispatchToOutfit],
	);

	return (
		// We're wrapping the control inside the label, which works just fine!
		// eslint-disable-next-line jsx-a11y/label-has-associated-control
		<label>
			<VisuallyHidden
				as="input"
				type="checkbox"
				aria-label={`Wear "${item.name}"`}
				value={item.id}
				checked={isWorn}
				ref={checkboxRef}
				onChange={(e) => {
					const itemId = e.target.value;
					const willBeWorn = e.target.checked;
					if (willBeWorn) {
						dispatchToOutfit({ type: "wearItem", itemId, itemIdsToReconsider });
					} else {
						dispatchToOutfit({
							type: "unwearItem",
							itemId,
							itemIdsToReconsider,
						});
					}
				}}
				onKeyDown={(e) => {
					if (e.key === "Enter") {
						e.target.click();
					} else if (e.key === "ArrowUp") {
						goToPrevItem(e);
					} else if (e.key === "ArrowDown") {
						goToNextItem(e);
					}
				}}
			/>
			<Item
				item={item}
				isWorn={isWorn}
				isInOutfit={isInOutfit}
				onRemove={onRemove}
			/>
		</label>
	);
}

// Focus the shelf's worn style, if it's there, or else its first style.
function focusShelf(shelf) {
	const input =
		shelf.querySelector("input[name=style]:checked") ??
		shelf.querySelector("input[name=style]");
	input?.focus();
	input?.closest("form")?.scrollIntoView({ block: "nearest" });
}

/**
 * Whether NC Pet Styles could match this item search, to show them in a shelf
 * above the results. Styles are NC and have no zone, so other kinds and zone
 * filters rule them out. So do the own/want filters, for now: you can own or
 * want a style's token item like any other item, but the wardrobe doesn't
 * load that for styles yet.
 */
function canMatchStyles(query) {
	return (
		(query.filterToItemKind == null || query.filterToItemKind === "NC") &&
		query.filterToZoneLabel == null &&
		query.filterToCurrentUserOwnsOrWants == null
	);
}

/**
 * serializeQuery stably converts a search query object to a string, for easier
 * JS comparison.
 */
function serializeQuery(query) {
	return `${JSON.stringify([
		query.value,
		query.filterToItemKind,
		query.filterToZoneLabel,
		query.filterToCurrentUserOwnsOrWants,
	])}`;
}

export default SearchPanel;
