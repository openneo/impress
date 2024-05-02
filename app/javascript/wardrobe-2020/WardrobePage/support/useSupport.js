import { getSupportSecret } from "../../impress-2020-config";

/**
 * useSupport returns the Support secret that the server requires for Support
 * actions... if the user has it set. For most users, this returns nothing!
 *
 * This is specifically for communications for Impress 2020, which authorizes
 * support requests using a shared support secret instead of user accounts.
 * (This isn't a great model, we should abandon it in favor of true authorized
 * requests as we deprecate Impress 2020!)
 *
 * Specifically, we return an object of:
 *   - isSupportUser: true iff the `supportSecret` is set
 *   - supportSecret: the secret saved to this device, or null if not set
 *
 * To become a Support user, get the `support_staff` flag set on your user
 * account. Then, `getSupportSecret` will read the support secret from the HTML
 * document. (If the flag is off, the HTML document does not contain the
 * secret.)
 *
 * Note that this hook doesn't check that the secret is *correct*, so it's
 * possible that it will return an invalid secret. That's okay, because
 * the server checks the provided secret for each Support request.
 */
function useSupport() {
  const supportSecret = getSupportSecret();

  const isSupportUser = supportSecret != null;

  return { isSupportUser, supportSecret };
}

export default useSupport;
