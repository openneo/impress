import { gql, useMutation, useQuery } from "@apollo/client";
import { useLocalStorage } from "../util";

const NOT_LOGGED_IN_USER = {
  isLoading: false,
  isLoggedIn: false,
  id: null,
  username: null,
};

function useCurrentUser() {
  const currentUser = useCurrentUserQuery();

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

  return currentUser;
}

function useCurrentUserQuery() {
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
    },
  );

  if (loading) {
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

export default useCurrentUser;
