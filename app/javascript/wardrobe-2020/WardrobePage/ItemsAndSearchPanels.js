import React from "react";
import { Box, Flex } from "@chakra-ui/react";

import ItemsPanel from "./ItemsPanel";
import SearchToolbar, { searchQueryIsEmpty } from "./SearchToolbar";
import SearchPanel from "./SearchPanel";
import { ErrorBoundary, TestErrorSender } from "../util";

/**
 * ItemsAndSearchPanels manages the shared layout and state for:
 *   - ItemsPanel, which shows the items in the outfit now, and
 *   - SearchPanel, which helps you find new items to add.
 *
 * These panels don't share a _lot_ of concerns; they're mainly intertwined by
 * the fact that they share the SearchToolbar at the top!
 *
 * We try to keep the search concerns in the search components, by avoiding
 * letting any actual _logic_ live at the root here; and instead just
 * performing some wiring to help them interact with each other via simple
 * state and refs.
 */
function ItemsAndSearchPanels({
	loading,
	searchQuery,
	onChangeSearchQuery,
	outfitState,
	outfitSaving,
	dispatchToOutfit,
	onPreviewAltStyle,
	onBrowseStyles,
	searchFocusRequest,
}) {
	const scrollContainerRef = React.useRef();
	const searchQueryRef = React.useRef();
	const firstSearchResultRef = React.useRef();

	// When another part of the page sends us to search (e.g. the PosePicker
	// opening NC Pet Styles), put the cursor in the search field, ready to
	// type. (But not on touch devices, where the on-screen keyboard would
	// cover the results!)
	React.useEffect(() => {
		if (
			searchFocusRequest > 0 &&
			window.matchMedia?.("(hover: hover)").matches
		) {
			searchQueryRef.current?.focus();
		}
	}, [searchFocusRequest]);

	return (
		<ErrorBoundary>
			<TestErrorSender />
			<Flex direction="column" height="100%">
				<Box paddingX="5" paddingTop="3" paddingBottom="2" boxShadow="sm">
					<SearchToolbar
						query={searchQuery}
						searchQueryRef={searchQueryRef}
						firstSearchResultRef={firstSearchResultRef}
						onChange={onChangeSearchQuery}
					/>
				</Box>
				{!searchQueryIsEmpty(searchQuery) ? (
					<Box
						key="search-panel"
						flex="1 0 0"
						position="relative"
						overflowY="scroll"
						ref={scrollContainerRef}
						data-test-id="search-panel-scroll-container"
						// Style tiles lazy-load their images as they scroll near view.
						data-style-scroll-container="true"
					>
						<SearchPanel
							query={searchQuery}
							outfitState={outfitState}
							dispatchToOutfit={dispatchToOutfit}
							scrollContainerRef={scrollContainerRef}
							searchQueryRef={searchQueryRef}
							firstSearchResultRef={firstSearchResultRef}
							onPreviewAltStyle={onPreviewAltStyle}
							onChangeQuery={onChangeSearchQuery}
						/>
					</Box>
				) : (
					<Box position="relative" overflow="auto" key="items-panel">
						<Box px="4" py="2">
							<ItemsPanel
								loading={loading}
								outfitState={outfitState}
								outfitSaving={outfitSaving}
								dispatchToOutfit={dispatchToOutfit}
								onBrowseStyles={onBrowseStyles}
							/>
						</Box>
					</Box>
				)}
			</Flex>
		</ErrorBoundary>
	);
}

export default ItemsAndSearchPanels;
