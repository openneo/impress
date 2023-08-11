import React from "react";
import * as Sentry from "@sentry/react";
import { Integrations } from "@sentry/tracing";
import { Auth0Provider } from "@auth0/auth0-react";
import { CSSReset, ChakraProvider, extendTheme } from "@chakra-ui/react";
import { ApolloProvider } from "@apollo/client";
import { useAuth0 } from "@auth0/auth0-react";
import { mode } from "@chakra-ui/theme-tools";
import { BrowserRouter } from "react-router-dom";

import buildApolloClient from "./apolloClient";

const theme = extendTheme({
  styles: {
    global: (props) => ({
      html: {
        // HACK: Chakra sets body as the relative position element, which is
        //       fine, except its `min-height: 100%` doesn't actually work
        //       unless paired with height on the root element too!
        height: "100%",
      },
      body: {
        background: mode("gray.50", "gray.800")(props),
        color: mode("green.800", "green.50")(props),
        transition: "all 0.25s",
      },
    }),
  },
});

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
          <ChakraProvider theme={theme}>
            <CSSReset />
            {children}
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
