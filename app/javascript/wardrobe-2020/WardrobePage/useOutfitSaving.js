import React from "react";
import { useToast } from "@chakra-ui/react";
import { useRouter } from "next/router";
import { useDebounce } from "../util";
import useCurrentUser from "../components/useCurrentUser";
import gql from "graphql-tag";
import { useMutation } from "@apollo/client";
import { outfitStatesAreEqual } from "./useOutfitState";

function useOutfitSaving(outfitState, dispatchToOutfit) {
  const { isLoggedIn, id: currentUserId } = useCurrentUser();
  const { pathname, push: pushHistory } = useRouter();
  const toast = useToast();

  // There's not a way to reset an Apollo mutation state to clear out the error
  // when the outfit changes… so we track the error state ourselves!
  const [saveError, setSaveError] = React.useState(null);

  // Whether this outfit is new, i.e. local-only, i.e. has _never_ been saved
  // to the server.
  const isNewOutfit = outfitState.id == null;

  // Whether this outfit's latest local changes have been saved to the server.
  // And log it to the console!
  const latestVersionIsSaved =
    outfitState.savedOutfitState &&
    outfitStatesAreEqual(
      outfitState.outfitStateWithoutExtras,
      outfitState.savedOutfitState
    );
  React.useEffect(() => {
    console.debug(
      "[useOutfitSaving] Latest version is saved? %s\nCurrent: %o\nSaved: %o",
      latestVersionIsSaved,
      outfitState.outfitStateWithoutExtras,
      outfitState.savedOutfitState
    );
  }, [
    latestVersionIsSaved,
    outfitState.outfitStateWithoutExtras,
    outfitState.savedOutfitState,
  ]);

  // Only logged-in users can save outfits - and they can only save new outfits,
  // or outfits they created.
  const canSaveOutfit =
    isLoggedIn && (isNewOutfit || outfitState.creator?.id === currentUserId);

  // Users can delete their own outfits too. The logic is slightly different
  // than for saving, because you can save an outfit that hasn't been saved
  // yet, but you can't delete it.
  const canDeleteOutfit = !isNewOutfit && canSaveOutfit;

  const [sendSaveOutfitMutation, { loading: isSaving }] = useMutation(
    gql`
      mutation UseOutfitSaving_SaveOutfit(
        $id: ID # Optional, is null when saving new outfits.
        $name: String # Optional, server may fill in a placeholder.
        $speciesId: ID!
        $colorId: ID!
        $pose: Pose!
        $wornItemIds: [ID!]!
        $closetedItemIds: [ID!]!
      ) {
        outfit: saveOutfit(
          id: $id
          name: $name
          speciesId: $speciesId
          colorId: $colorId
          pose: $pose
          wornItemIds: $wornItemIds
          closetedItemIds: $closetedItemIds
        ) {
          id
          name
          petAppearance {
            id
            species {
              id
            }
            color {
              id
            }
            pose
          }
          wornItems {
            id
          }
          closetedItems {
            id
          }
          creator {
            id
          }
        }
      }
    `,
    {
      context: { sendAuth: true },
      update: (cache, { data: { outfit } }) => {
        // After save, add this outfit to the current user's outfit list. This
        // will help when navigating back to Your Outfits, to force a refresh.
        // https://www.apollographql.com/docs/react/caching/cache-interaction/#example-updating-the-cache-after-a-mutation
        cache.modify({
          id: cache.identify(outfit.creator),
          fields: {
            outfits: (existingOutfitRefs = [], { readField }) => {
              const isAlreadyInList = existingOutfitRefs.some(
                (ref) => readField("id", ref) === outfit.id
              );
              if (isAlreadyInList) {
                return existingOutfitRefs;
              }

              const newOutfitRef = cache.writeFragment({
                data: outfit,
                fragment: gql`
                  fragment NewOutfit on Outfit {
                    id
                  }
                `,
              });

              return [...existingOutfitRefs, newOutfitRef];
            },
          },
        });

        // Also, send a `rename` action, if this is still the current outfit,
        // and the server renamed it (e.g. "Untitled outfit (1)"). (It's
        // tempting to do a full reset, in case the server knows something we
        // don't, but we don't want to clobber changes the user made since
        // starting the save!)
        if (outfit.id === outfitState.id && outfit.name !== outfitState.name) {
          dispatchToOutfit({
            type: "rename",
            outfitName: outfit.name,
          });
        }
      },
    }
  );

  const saveOutfitFromProvidedState = React.useCallback(
    (outfitState) => {
      sendSaveOutfitMutation({
        variables: {
          id: outfitState.id,
          name: outfitState.name,
          speciesId: outfitState.speciesId,
          colorId: outfitState.colorId,
          pose: outfitState.pose,
          wornItemIds: [...outfitState.wornItemIds],
          closetedItemIds: [...outfitState.closetedItemIds],
        },
      })
        .then(({ data: { outfit } }) => {
          // Navigate to the new saved outfit URL. Our Apollo cache should pick
          // up the data from this mutation response, and combine it with the
          // existing cached data, to make this smooth without any loading UI.
          if (pathname !== `/outfits/[outfitId]`) {
            pushHistory(`/outfits/${outfit.id}`);
          }
        })
        .catch((e) => {
          console.error(e);
          setSaveError(e);
          toast({
            status: "error",
            title: "Sorry, there was an error saving this outfit!",
            description: "Maybe check your connection and try again.",
          });
        });
    },
    // It's important that this callback _doesn't_ change when the outfit
    // changes, so that the auto-save effect is only responding to the
    // debounced state!
    [sendSaveOutfitMutation, pathname, pushHistory, toast]
  );

  const saveOutfit = React.useCallback(
    () => saveOutfitFromProvidedState(outfitState.outfitStateWithoutExtras),
    [saveOutfitFromProvidedState, outfitState.outfitStateWithoutExtras]
  );

  // Auto-saving! First, debounce the outfit state. Use `outfitStateWithoutExtras`,
  // which only contains the basic fields, and will keep a stable object
  // identity until actual changes occur. Then, save the outfit after the user
  // has left it alone for long enough, so long as it's actually different
  // than the saved state.
  const debouncedOutfitState = useDebounce(
    outfitState.outfitStateWithoutExtras,
    2000,
    {
      // When the outfit ID changes, update the debounced state immediately!
      forceReset: (debouncedOutfitState, newOutfitState) =>
        debouncedOutfitState.id !== newOutfitState.id,
    }
  );
  // HACK: This prevents us from auto-saving the outfit state that's still
  //       loading. I worry that this might not catch other loading scenarios
  //       though, like if the species/color/pose is in the GQL cache, but the
  //       items are still loading in... not sure where this would happen tho!
  const debouncedOutfitStateIsSaveable =
    debouncedOutfitState.speciesId &&
    debouncedOutfitState.colorId &&
    debouncedOutfitState.pose;
  React.useEffect(() => {
    if (
      !isNewOutfit &&
      canSaveOutfit &&
      debouncedOutfitStateIsSaveable &&
      !outfitStatesAreEqual(debouncedOutfitState, outfitState.savedOutfitState)
    ) {
      console.info(
        "[useOutfitSaving] Auto-saving outfit\nSaved: %o\nCurrent (debounced): %o",
        outfitState.savedOutfitState,
        debouncedOutfitState
      );
      saveOutfitFromProvidedState(debouncedOutfitState);
    }
  }, [
    isNewOutfit,
    canSaveOutfit,
    debouncedOutfitState,
    debouncedOutfitStateIsSaveable,
    outfitState.savedOutfitState,
    saveOutfitFromProvidedState,
  ]);

  // When the outfit changes, clear out the error state from previous saves.
  // We'll send the mutation again after the debounce, and we don't want to
  // show the error UI in the meantime!
  React.useEffect(() => {
    setSaveError(null);
  }, [outfitState.outfitStateWithoutExtras]);

  return {
    canSaveOutfit,
    canDeleteOutfit,
    isNewOutfit,
    isSaving,
    latestVersionIsSaved,
    saveError,
    saveOutfit,
  };
}

export default useOutfitSaving;
