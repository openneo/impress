// Read the current user ID once from the <meta> tags, and use that forever!
const currentUserId = readCurrentUserId();

function useCurrentUser() {
  if (currentUserId == null) {
    return {
      isLoggedIn: false,
      id: null,
    };
  }

  return {
    isLoggedIn: true,
    id: currentUserId,
  };
}

function readCurrentUserId() {
  try {
    const element = document.querySelector("meta[name=dti-current-user-id]");
    return JSON.parse(element.getAttribute("content"));
  } catch (error) {
    console.error(
      `[readCurrentUserId] Couldn't read user ID, using null instead`,
      error,
    );
    return null;
  }
}

export default useCurrentUser;
