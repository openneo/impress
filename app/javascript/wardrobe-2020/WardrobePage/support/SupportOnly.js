import useSupport from "./useSupport";

/**
 * SupportOnly only shows its contents to Support users. For most users, the
 * content will be hidden!
 *
 * To become a Support user, you visit /?supportSecret=..., which saves the
 * secret to your device.
 *
 * Note that this component doesn't check that the secret is *correct*, so it's
 * possible to view this UI by faking an invalid secret. That's okay, because
 * the server checks the provided secret for each Support request.
 */
function SupportOnly({ children }) {
  const { isSupportUser } = useSupport();
  return isSupportUser ? children : null;
}

export default SupportOnly;
