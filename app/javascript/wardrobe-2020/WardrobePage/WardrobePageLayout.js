import React from "react";
import { Box, Grid, useColorModeValue } from "@chakra-ui/react";

function WardrobePageLayout({
	previewAndControls = null,
	itemsAndMaybeSearchPanel = null,
}) {
	const itemsAndSearchBackground = useColorModeValue("white", "gray.900");

	return (
		<Box
			position="absolute"
			top="0"
			bottom="0"
			left="0"
			right="0"
			// Create a stacking context, so that our drawers and modals don't fight
			// with the z-indexes in here!
			zIndex="0"
		>
			<Grid
				templateAreas={{
					base: `"previewAndControls"
                 "itemsAndMaybeSearchPanel"`,
					md: `"previewAndControls itemsAndMaybeSearchPanel"`,
				}}
				templateRows={{
					base: "minmax(100px, 45%) minmax(300px, 55%)",
					md: "100%",
				}}
				templateColumns={{
					base: "100%",
					md: "50% 50%",
				}}
				height="100%"
				width="100%"
			>
				<Box
					gridArea="previewAndControls"
					bg="gray.900"
					color="gray.50"
					position="relative"
				>
					{previewAndControls}
				</Box>
				<Box gridArea="itemsAndMaybeSearchPanel" bg={itemsAndSearchBackground}>
					{itemsAndMaybeSearchPanel}
				</Box>
			</Grid>
		</Box>
	);
}

export default WardrobePageLayout;
