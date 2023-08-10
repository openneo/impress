import * as React from "react";

/**
 * useSupport returns the Support secret that the server requires for Support
 * actions... if the user has it set. For most users, this returns nothing!
 *
 * Specifically, we return an object of:
 *   - isSupportUser: true iff the `supportSecret` is set
 *   - supportSecret: the secret saved to this device, or null if not set
 *
 * To become a Support user, you visit /?supportSecret=..., which saves the
 * secret to your device.
 *
 * Note that this hook doesn't check that the secret is *correct*, so it's
 * possible that it will return an invalid secret. That's okay, because
 * the server checks the provided secret for each Support request.
 */
function useSupport() {
  const supportSecret = React.useMemo(
    () =>
      typeof localStorage !== "undefined"
        ? localStorage.getItem("supportSecret")
        : null,
    []
  );

  const isSupportUser = supportSecret != null;

  return { isSupportUser, supportSecret };
}

export default useSupport;
