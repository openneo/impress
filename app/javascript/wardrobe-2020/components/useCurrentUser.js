import { gql, useMutation, useQuery } from "@apollo/client";
import { useAuth0 } from "@auth0/auth0-react";
import { useLocalStorage } from "../util";

const NOT_LOGGED_IN_USER = {
  isLoading: false,
  isLoggedIn: false,
  id: null,
  username: null,
};

function useCurrentUser() {
  const [authMode] = useAuthModeFeatureFlag();
  const currentUserViaAuth0 = useCurrentUserViaAuth0({
    isEnabled: authMode === "auth0",
  });
  const currentUserViaDb = useCurrentUserViaDb({
    isEnabled: authMode === "db",
  });

  // In development, you can start the server with
  // `IMPRESS_LOG_IN_AS=12345 vc dev` to simulate logging in as user 12345.
  //
  // This flag shouldn't be present in prod anyway, but the dev check is an
  // extra safety precaution!
  //
  // NOTE: In package.json, we forward the flag to REACT_APP_IMPRESS_LOG_IN_AS,
  //       because create-react-app only forwards flags with that prefix.
  if (
    process.env["NODE_ENV"] === "development" &&
    process.env["REACT_APP_IMPRESS_LOG_IN_AS"]
  ) {
    const id = process.env["REACT_APP_IMPRESS_LOG_IN_AS"];
    return {
      isLoading: false,
      isLoggedIn: true,
      id,
      username: `<Simulated User ${id}>`,
    };
  }

  if (authMode === "auth0") {
    return currentUserViaAuth0;
  } else if (authMode === "db") {
    return currentUserViaDb;
  } else {
    console.error(`Unexpected auth mode: ${JSON.stringify(authMode)}`);
    return NOT_LOGGED_IN_USER;
  }
}

function useCurrentUserViaAuth0({ isEnabled }) {
  // NOTE: I don't think we can actually, by the rule of hooks, *not* ask for
  //       Auth0 login state when `isEnabled` is false, because `useAuth0`
  //       doesn't accept a similar parameter to disable itself. We'll just
  //       accept the redundant network effort during rollout, then delete it
  //       when we're done. (So, the param isn't actually doing a whole lot; I
  //       mostly have it for consistency with `useCurrentUserViaDb`, to make
  //       it clear where the real difference is.)
  const { isLoading, isAuthenticated, user } = useAuth0();

  if (!isEnabled) {
    return NOT_LOGGED_IN_USER;
  } else if (isLoading) {
    return { ...NOT_LOGGED_IN_USER, isLoading: true };
  } else if (!isAuthenticated) {
    return NOT_LOGGED_IN_USER;
  } else {
    return {
      isLoading: false,
      isLoggedIn: true,
      ...getUserInfoFromAuth0Data(user),
    };
  }
}

function useCurrentUserViaDb({ isEnabled }) {
  const { loading, data } = useQuery(
    gql`
      query useCurrentUser {
        currentUser {
          id
          username
        }
      }
    `,
    {
      skip: !isEnabled,
      onError: (error) => {
        // On error, we don't report anything to the user, but we do keep a
        // record in the console. We figure that most errors are likely to be
        // solvable by retrying the login button and creating a new session,
        // which the user would do without an error prompt anyway; and if not,
        // they'll either get an error when they try, or they'll see their
        // login state continue to not work, which should be a clear hint that
        // something is wrong and they need to reach out.
        console.error("[useCurrentUser] Couldn't get current user:", error);
      },
    }
  );

  if (!isEnabled) {
    return NOT_LOGGED_IN_USER;
  } else if (loading) {
    return { ...NOT_LOGGED_IN_USER, isLoading: true };
  } else if (data?.currentUser == null) {
    return NOT_LOGGED_IN_USER;
  } else {
    return {
      isLoading: false,
      isLoggedIn: true,
      id: data.currentUser.id,
      username: data.currentUser.username,
    };
  }
}

function getUserInfoFromAuth0Data(user) {
  return {
    id: user.sub?.match(/^auth0\|impress-([0-9]+)$/)?.[1],
    username: user["https://oauth.impress-2020.openneo.net/username"],
  };
}

/**
 * useLoginActions returns a `startLogin` function to start login with Auth0,
 * and a `logout` function to logout from whatever auth mode is in use.
 *
 * Note that `startLogin` is only supported with the Auth0 auto mode. In db
 * mode, you should open a `LoginModal` instead!
 */
export function useLogout() {
  const { logout: logoutWithAuth0 } = useAuth0();
  const [authMode] = useAuthModeFeatureFlag();

  const [sendLogoutMutation, { loading, error }] = useMutation(
    gql`
      mutation useLogout_Logout {
        logout {
          id
        }
      }
    `,
    {
      update: (cache, { data }) => {
        // Evict the `currentUser` from the cache, which will force all queries
        // on the page that depend on it to update. (This includes the
        // GlobalHeader that shows who you're logged in as!)
        //
        // We also evict the user themself, to force-update things that we're
        // allowed to see about this user (e.g. private lists).
        //
        // I don't do any optimistic UI here, because auth is complex enough
        // that I'd rather only show logout success after validating it through
        // an actual server round-trip.
        cache.evict({ id: "ROOT_QUERY", fieldName: "currentUser" });
        if (data.logout?.id != null) {
          cache.evict({ id: `User:${data.logout.id}` });
        }
        cache.gc();
      },
    }
  );

  const logoutWithDb = () => {
    sendLogoutMutation().catch((e) => {}); // handled in error UI
  };

  if (authMode === "auth0") {
    return [logoutWithAuth0, { loading: false, error: null }];
  } else if (authMode === "db") {
    return [logoutWithDb, { loading, error }];
  } else {
    console.error(`unexpected auth mode: ${JSON.stringify(authMode)}`);
    return [() => {}, { loading: false, error: null }];
  }
}

/**
 * useAuthModeFeatureFlag returns "db" by default, but "auto" if you're falling
 * back to the old auth0-backed login mode.
 *
 * To set this manually, click "Better login system" on the homepage in the
 * Coming Soon block, and switch the toggle.
 */
export function useAuthModeFeatureFlag() {
  // We'll probably add a like, experimental gradual rollout thing here too.
  // But for now we just check your device's local storage! (This is why we
  // default to `null` instead of "auth0", I want to be unambiguous that this
  // is the *absence* of a localStorage value, and not risk accidentally
  // setting this override value to auth0 on everyone's devices 😅)
  let [savedValue, setSavedValue] = useLocalStorage(
    "DTIAuthModeFeatureFlag",
    null
  );

  if (!["auth0", "db", null].includes(savedValue)) {
    console.warn(
      `Unexpected DTIAuthModeFeatureFlag value: %o. Ignoring.`,
      savedValue
    );
    savedValue = null;
  }

  const value = savedValue || "db";

  return [value, setSavedValue];
}

/**
 * getAuthModeFeatureFlag returns the authMode at the time it's called.
 * It's generally preferable to use `useAuthModeFeatureFlag` in a React
 * setting, but we use this instead for Apollo stuff!
 */
export function getAuthModeFeatureFlag() {
  const savedValueString = localStorage.getItem("DTIAuthModeFeatureFlag");

  let savedValue;
  try {
    savedValue = JSON.parse(savedValueString);
  } catch (error) {
    console.warn(`DTIAuthModeFeatureFlag was not valid JSON. Ignoring.`);
    savedValue = null;
  }

  if (!["auth0", "db", null].includes(savedValue)) {
    console.warn(
      `Unexpected DTIAuthModeFeatureFlag value: %o. Ignoring.`,
      savedValue
    );
    savedValue = null;
  }

  return savedValue || "db";
}

export default useCurrentUser;
