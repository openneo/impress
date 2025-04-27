import React from "react";
import {
	ChakraProvider,
	Box,
	css as resolveCSS,
	extendTheme,
	useColorMode,
	useTheme,
} from "@chakra-ui/react";
import { mode } from "@chakra-ui/theme-tools";
import { ApolloProvider } from "@apollo/client";
import { BrowserRouter } from "react-router-dom";
import { css, Global } from "@emotion/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";

import apolloClient from "./apolloClient";

const reactQueryClient = new QueryClient();

let theme = extendTheme({
	styles: {
		global: (props) => ({
			body: {
				background: mode("gray.50", "gray.800")(props),
				color: mode("green.800", "green.50")(props),
				transition: "all 0.25s",
			},
		}),
	},
});

// Capture the global styles function from our theme, but remove it from the
// theme's `styles.global` key. We don't actually want to apply these styles
// globally, because they conflict with the app's other styles when embedded in
// e.g. the item page! We'll apply them more carefully in `ScopedCSSReset`.
//
// NOTE: We get this from `theme`, instead of just declaring the function
// separately, because `extendTheme` returns a wrapped version of our function
// that also returns some of Chakra's own default global styles.
const globalStyles = theme.styles.global;
theme.styles.global = {};

export default function AppProvider({ children }) {
	return (
		<BrowserRouter>
			<QueryClientProvider client={reactQueryClient}>
				<ApolloProvider client={apolloClient}>
					<ChakraProvider resetCSS={false} theme={theme}>
						<ScopedCSSReset>{children}</ScopedCSSReset>
					</ChakraProvider>
				</ApolloProvider>
			</QueryClientProvider>
		</BrowserRouter>
	);
}

/**
 * ScopedCSSReset applies a copy of Chakra UI's CSS reset, but only to its
 * children (or, well, any element with the chakra-css-reset class). It also
 * applies to .chakra-portal elements mounted by <Portal> components.
 *
 * We also apply some base styles, like the default text color.
 *
 * NOTE: We use the `:where` CSS selector, instead of the .chakra-css-reset
 * selector directly, to avoid specificity conflicts. e.g. the selector
 * `.chakra-css-reset h1` is considered MORE specific than `.my-h1`, whereas
 * the selector `:where(.chakra-css-reset) h1` is lower specificity.
 */
function ScopedCSSReset({ children }) {
	// Get the current theme and color mode.
	//
	// NOTE: The theme object returned by `useTheme` has some extensions that are
	// necessary for the code below, but aren't present in the theme config
	// returned by `extendTheme`! That's why we use this here instead of `theme`.
	const liveTheme = useTheme();
	const colorMode = useColorMode();

	// Resolve the theme's global styles into CSS objects for Emotion.
	const globalStylesCSS = resolveCSS(
		globalStyles({ theme: liveTheme, colorMode }),
	)(liveTheme);

	// Prepend our special scope selector to the global styles.
	const scopedGlobalStylesCSS = {};
	for (let [selector, rules] of Object.entries(globalStylesCSS)) {
		// The `body` selector is where typography etc rules go, but `body` isn't
		// actually *inside* our scoped element! Instead, ignore the `body` part,
		// and just apply it to the scoping element itself.
		if (selector.trim() === "body") {
			selector = "";
		}

		const scopedSelector =
			":where(.chakra-css-reset, .chakra-portal) " + selector;
		scopedGlobalStylesCSS[scopedSelector] = rules;
	}

	return (
		<>
			<Box className="chakra-css-reset">{children}</Box>
			<Global
				styles={css`
					/* Chakra's default global styles, placed here so we can override
           * the actual _global_ styles in the theme to be empty. That way,
           * it only affects Chakra stuff, not all elements! */
					${scopedGlobalStylesCSS}

					/* Chakra's CSS reset, copy-pasted and rescoped! */
          :where(.chakra-css-reset, .chakra-portal) {
						*,
						*::before,
						*::after {
							border-width: 0;
							border-style: solid;
							box-sizing: border-box;
						}

						main {
							display: block;
						}

						hr {
							border-top-width: 1px;
							box-sizing: content-box;
							height: 0;
							overflow: visible;
						}

						pre,
						code,
						kbd,
						samp {
							font-family: SFMono-Regular, Menlo, Monaco, Consolas, monospace;
							font-size: 1em;
						}

						a {
							background-color: transparent;
							color: inherit;
							text-decoration: inherit;
						}

						abbr[title] {
							border-bottom: none;
							text-decoration: underline;
							-webkit-text-decoration: underline dotted;
							text-decoration: underline dotted;
						}

						b,
						strong {
							font-weight: bold;
						}

						small {
							font-size: 80%;
						}

						sub,
						sup {
							font-size: 75%;
							line-height: 0;
							position: relative;
							vertical-align: baseline;
						}

						sub {
							bottom: -0.25em;
						}

						sup {
							top: -0.5em;
						}

						img {
							border-style: none;
						}

						button,
						input,
						optgroup,
						select,
						textarea {
							font-family: inherit;
							font-size: 100%;
							line-height: 1.15;
							margin: 0;
						}

						button,
						input {
							overflow: visible;
						}

						button,
						select {
							text-transform: none;
						}

						button::-moz-focus-inner,
						[type="button"]::-moz-focus-inner,
						[type="reset"]::-moz-focus-inner,
						[type="submit"]::-moz-focus-inner {
							border-style: none;
							padding: 0;
						}

						fieldset {
							padding: 0.35em 0.75em 0.625em;
						}

						legend {
							box-sizing: border-box;
							color: inherit;
							display: table;
							max-width: 100%;
							padding: 0;
							white-space: normal;
						}

						progress {
							vertical-align: baseline;
						}

						textarea {
							overflow: auto;
						}

						[type="checkbox"],
						[type="radio"] {
							box-sizing: border-box;
							padding: 0;
						}

						[type="number"]::-webkit-inner-spin-button,
						[type="number"]::-webkit-outer-spin-button {
							-webkit-appearance: none !important;
						}

						input[type="number"] {
							-moz-appearance: textfield;
						}

						[type="search"] {
							-webkit-appearance: textfield;
							outline-offset: -2px;
						}

						[type="search"]::-webkit-search-decoration {
							-webkit-appearance: none !important;
						}

						::-webkit-file-upload-button {
							-webkit-appearance: button;
							font: inherit;
						}

						details {
							display: block;
						}

						summary {
							display: list-item;
						}

						template {
							display: none;
						}

						[hidden] {
							display: none !important;
						}

						body,
						blockquote,
						dl,
						dd,
						h1,
						h2,
						h3,
						h4,
						h5,
						h6,
						hr,
						figure,
						p,
						pre {
							margin: 0;
						}

						button {
							background: transparent;
							padding: 0;
						}

						fieldset {
							margin: 0;
							padding: 0;
						}

						ol,
						ul {
							margin: 0;
							padding: 0;
						}

						textarea {
							resize: vertical;
						}

						button,
						[role="button"] {
							cursor: pointer;
						}

						button::-moz-focus-inner {
							border: 0 !important;
						}

						table {
							border-collapse: collapse;
						}

						h1,
						h2,
						h3,
						h4,
						h5,
						h6 {
							font-size: inherit;
							font-weight: inherit;
						}

						button,
						input,
						optgroup,
						select,
						textarea {
							padding: 0;
							line-height: inherit;
							color: inherit;
						}

						img,
						svg,
						video,
						canvas,
						audio,
						iframe,
						embed,
						object {
							display: block;
						}

						img,
						video {
							max-width: 100%;
							height: auto;
						}

						[data-js-focus-visible] :focus:not([data-focus-visible-added]) {
							outline: none;
							box-shadow: none;
						}

						select::-ms-expand {
							display: none;
						}
					}
				`}
			/>
		</>
	);
}
