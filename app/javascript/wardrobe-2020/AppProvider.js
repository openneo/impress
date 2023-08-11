import React from "react";
import * as Sentry from "@sentry/react";
import { Integrations } from "@sentry/tracing";
import { Auth0Provider } from "@auth0/auth0-react";
import { ChakraProvider, Box } from "@chakra-ui/react";
import { ApolloProvider } from "@apollo/client";
import { useAuth0 } from "@auth0/auth0-react";
import { BrowserRouter } from "react-router-dom";
import { Global } from "@emotion/react";

import buildApolloClient from "./apolloClient";

export default function AppProvider({ children }) {
  React.useEffect(() => setupLogging(), []);

  return (
    <BrowserRouter>
      <Auth0Provider
        domain="openneo.us.auth0.com"
        clientId="8LjFauVox7shDxVufQqnviUIywMuuC4r"
        redirectUri={
          process.env.NODE_ENV === "development"
            ? "http://localhost:3000"
            : "https://impress-2020.openneo.net"
        }
        audience="https://impress-2020.openneo.net/api"
        scope=""
      >
        <DTIApolloProvider>
          <ChakraProvider resetCSS={false}>
            <ScopedCSSReset>{children}</ScopedCSSReset>
          </ChakraProvider>
        </DTIApolloProvider>
      </Auth0Provider>
    </BrowserRouter>
  );
}

function DTIApolloProvider({ children, additionalCacheState = {} }) {
  const auth0 = useAuth0();
  const auth0Ref = React.useRef(auth0);

  React.useEffect(() => {
    auth0Ref.current = auth0;
  }, [auth0]);

  // Save the first `additionalCacheState` we get as our `initialCacheState`,
  // which we'll use to initialize the client without having to wait a tick.
  const [initialCacheState, unusedSetInitialCacheState] =
    React.useState(additionalCacheState);

  const client = React.useMemo(
    () =>
      buildApolloClient({
        getAuth0: () => auth0Ref.current,
        initialCacheState,
      }),
    [initialCacheState]
  );

  // When we get a new `additionalCacheState` object, merge it into the cache:
  // copy the previous cache state, merge the new cache state's entries in,
  // and "restore" the new merged cache state.
  //
  // HACK: Using `useMemo` for this is a dastardly trick!! What we want is the
  //       semantics of `useEffect` kinda, but we need to ensure it happens
  //       *before* all the children below get rendered, so they don't fire off
  //       unnecessary network requests. Using `useMemo` but throwing away the
  //       result kinda does that. It's evil! It's nasty! It's... perfect?
  //       (This operation is safe to run multiple times too, in case memo
  //       re-runs it. It's just, y'know, a performance loss. Maybe it's
  //       actually kinda perfect lol)
  //
  //       I feel like there's probably a better way to do this... like, I want
  //       the semantic of replacing this client with an updated client - but I
  //       don't want to actually replace the client, because that'll break
  //       other kinds of state, like requests loading in the shared layout.
  //       Idk! I'll see how it goes!
  React.useMemo(() => {
    const previousCacheState = client.cache.extract();
    const mergedCacheState = { ...previousCacheState };
    for (const key of Object.keys(additionalCacheState)) {
      mergedCacheState[key] = {
        ...mergedCacheState[key],
        ...additionalCacheState[key],
      };
    }
    console.debug(
      "Merging Apollo cache:",
      additionalCacheState,
      mergedCacheState
    );
    client.cache.restore(mergedCacheState);
  }, [client, additionalCacheState]);

  return <ApolloProvider client={client}>{children}</ApolloProvider>;
}

function setupLogging() {
  Sentry.init({
    dsn: "https://c55875c3b0904264a1a99e5b741a221e@o506079.ingest.sentry.io/5595379",
    autoSessionTracking: true,
    integrations: [
      new Integrations.BrowserTracing({
        beforeNavigate: (context) => ({
          ...context,
          // Assume any path segment starting with a digit is an ID, and replace
          // it with `:id`. This will help group related routes in Sentry stats.
          // NOTE: I'm a bit uncertain about the timing on this for tracking
          //       client-side navs... but we now only track first-time
          //       pageloads, and it definitely works correctly for them!
          name: window.location.pathname.replaceAll(/\/[0-9][^/]*/g, "/:id"),
        }),

        // We have a _lot_ of location changes that don't actually signify useful
        // navigations, like in the wardrobe page. It could be useful to trace
        // them with better filtering someday, but frankly we don't use the perf
        // features besides Web Vitals right now, and those only get tracked on
        // first-time pageloads, anyway. So, don't track client-side navs!
        startTransactionOnLocationChange: false,
      }),
    ],
    denyUrls: [
      // Don't log errors that were probably triggered by extensions and not by
      // our own app. (Apparently Sentry's setting to ignore browser extension
      // errors doesn't do this anywhere near as consistently as I'd expect?)
      //
      // Adapted from https://gist.github.com/impressiver/5092952, as linked in
      // https://docs.sentry.io/platforms/javascript/configuration/filtering/.
      /^chrome-extension:\/\//,
      /^moz-extension:\/\//,
    ],

    // Since we're only tracking first-page loads and not navigations, 100%
    // sampling isn't actually so much! Tune down if it becomes a problem, tho.
    tracesSampleRate: 1.0,
  });
}

/**
 * ScopedCSSReset applies a copy of Chakra UI's CSS reset, but only to its
 * children (or, well, any element with the chakra-css-reset class).
 *
 * TODO: What about Chakra's portal elements like toast messages, which are
 * intentionally mounted elsewhere in the document?
 *
 * NOTE: We use the `:where` CSS selector, instead of the .chakra-css-reset
 * selector directly, to avoid specificity conflicts. e.g. the selector
 * `.chakra-css-reset h1` is considered MORE specific than `.my-h1`, whereas
 * the selector `:where(.chakra-css-reset) h1` is lower specificity.
 */
function ScopedCSSReset({ children }) {
  return (
    <>
      <Box className="chakra-css-reset">{children}</Box>
      <Global
        styles={`
          :where(.chakra-css-reset) {
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
