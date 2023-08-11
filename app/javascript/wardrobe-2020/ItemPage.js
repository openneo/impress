import React from "react";
import { ClassNames } from "@emotion/react";
import {
  AspectRatio,
  Button,
  Box,
  HStack,
  IconButton,
  SkeletonText,
  Tooltip,
  VisuallyHidden,
  VStack,
  useBreakpointValue,
  useColorModeValue,
  useTheme,
  useToast,
  Flex,
  usePrefersReducedMotion,
  Grid,
  Popover,
  PopoverContent,
  PopoverTrigger,
  Checkbox,
} from "@chakra-ui/react";
import {
  CheckIcon,
  ChevronDownIcon,
  ChevronRightIcon,
  EditIcon,
  StarIcon,
  WarningIcon,
} from "@chakra-ui/icons";
import { MdPause, MdPlayArrow } from "react-icons/md";
import gql from "graphql-tag";
import { useQuery, useMutation } from "@apollo/client";

import ItemPageLayout, { SubtleSkeleton } from "./ItemPageLayout";
import {
  Delay,
  logAndCapture,
  MajorErrorMessage,
  useLocalStorage,
} from "./util";
import HTML5Badge, { layerUsesHTML5 } from "./components/HTML5Badge";
import {
  itemAppearanceFragment,
  petAppearanceFragment,
} from "./components/useOutfitAppearance";
import { useOutfitPreview } from "./components/OutfitPreview";
import SpeciesColorPicker, {
  useAllValidPetPoses,
  getValidPoses,
  getClosestPose,
} from "./components/SpeciesColorPicker";
import useCurrentUser from "./components/useCurrentUser";
import SpeciesFacesPicker, {
  colorIsBasic,
} from "./ItemPage/SpeciesFacesPicker";

// Removed for the wardrobe-2020 case.
// TODO: Refactor this stuff, do we even need ItemPageContent really?
// function ItemPage() {
//   const { query } = useRouter();
//   return <ItemPageContent itemId={query.itemId} />;
// }

/**
 * ItemPageContent is the content of ItemPage, but we also use it as the
 * entry point for ItemPageDrawer! When embedded in ItemPageDrawer, the
 * `isEmbedded` prop is true, so we know not to e.g. set the page title.
 */
export function ItemPageContent({ itemId, isEmbedded = false }) {
  const { isLoggedIn } = useCurrentUser();

  const { error, data } = useQuery(
    gql`
      query ItemPage($itemId: ID!) {
        item(id: $itemId) {
          id
          name
          isNc
          isPb
          thumbnailUrl
          description
          createdAt
          ncTradeValueText

          # For Support users.
          rarityIndex
          isManuallyNc
        }
      }
    `,
    { variables: { itemId }, returnPartialData: true }
  );

  if (error) {
    return <MajorErrorMessage error={error} />;
  }

  const item = data?.item;

  return (
    <>
      <ItemPageLayout item={item} isEmbedded={isEmbedded}>
        <VStack spacing="8" marginTop="4">
          <ItemPageDescription
            description={item?.description}
            isEmbedded={isEmbedded}
          />
          <VStack spacing="4">
            <ItemPageTradeLinks itemId={itemId} isEmbedded={isEmbedded} />
            {isLoggedIn && <ItemPageOwnWantButtons itemId={itemId} />}
          </VStack>
          {!isEmbedded && <ItemPageOutfitPreview itemId={itemId} />}
        </VStack>
      </ItemPageLayout>
    </>
  );
}

function ItemPageDescription({ description, isEmbedded }) {
  // Show 2 lines of description text placeholder on small screens, or when
  // embedded in the wardrobe page's narrow drawer. In larger contexts, show
  // just 1 line.
  const viewportNumDescriptionLines = useBreakpointValue({ base: 2, md: 1 });
  const numDescriptionLines = isEmbedded ? 2 : viewportNumDescriptionLines;

  return (
    <Box width="100%" alignSelf="flex-start">
      {description ? (
        description
      ) : description === "" ? (
        <i>(This item has no description.)</i>
      ) : (
        <Box
          maxWidth="40em"
          minHeight={numDescriptionLines * 1.5 + "em"}
          display="flex"
          flexDirection="column"
          alignItems="stretch"
          justifyContent="center"
        >
          <Delay ms={500}>
            <SkeletonText noOfLines={numDescriptionLines} spacing="4" />
          </Delay>
        </Box>
      )}
    </Box>
  );
}

const ITEM_PAGE_OWN_WANT_BUTTONS_QUERY = gql`
  query ItemPageOwnWantButtons($itemId: ID!) {
    item(id: $itemId) {
      id
      name
      currentUserOwnsThis
      currentUserWantsThis
    }
    currentUser {
      closetLists {
        id
        name
        isDefaultList
        ownsOrWantsItems
        hasItem(itemId: $itemId)
      }
    }
  }
`;

function ItemPageOwnWantButtons({ itemId }) {
  const { loading, error, data } = useQuery(ITEM_PAGE_OWN_WANT_BUTTONS_QUERY, {
    variables: { itemId },
    context: { sendAuth: true },
  });

  if (error) {
    return <Box color="red.400">{error.message}</Box>;
  }

  const closetLists = data?.currentUser?.closetLists || [];
  const realLists = closetLists.filter((cl) => !cl.isDefaultList);
  const ownedLists = realLists.filter((cl) => cl.ownsOrWantsItems === "OWNS");
  const wantedLists = realLists.filter((cl) => cl.ownsOrWantsItems === "WANTS");

  return (
    <Grid
      templateRows="auto auto"
      templateColumns="160px 160px"
      gridAutoFlow="column"
      rowGap="0.5"
      columnGap="4"
      justifyItems="center"
    >
      <SubtleSkeleton isLoaded={!loading}>
        <ItemPageOwnButton
          itemId={itemId}
          isChecked={data?.item?.currentUserOwnsThis}
        />
      </SubtleSkeleton>
      <ItemPageOwnWantListsDropdown
        closetLists={ownedLists}
        item={data?.item}
        // Show the dropdown if the user owns this, and has at least one custom
        // list it could belong to.
        isVisible={data?.item?.currentUserOwnsThis && ownedLists.length >= 1}
        popoverPlacement="bottom-end"
      />

      <SubtleSkeleton isLoaded={!loading}>
        <ItemPageWantButton
          itemId={itemId}
          isChecked={data?.item?.currentUserWantsThis}
        />
      </SubtleSkeleton>
      <ItemPageOwnWantListsDropdown
        closetLists={wantedLists}
        item={data?.item}
        // Show the dropdown if the user wants this, and has at least one
        // custom list it could belong to.
        isVisible={data?.item?.currentUserWantsThis && wantedLists.length >= 1}
        popoverPlacement="bottom-start"
      />
    </Grid>
  );
}

function ItemPageOwnWantListsDropdown({
  closetLists,
  item,
  isVisible,
  popoverPlacement,
}) {
  return (
    <Popover placement={popoverPlacement}>
      <PopoverTrigger>
        <ItemPageOwnWantListsDropdownButton
          closetLists={closetLists}
          isVisible={isVisible}
        />
      </PopoverTrigger>
      <PopoverContent padding="2" width="64">
        <ItemPageOwnWantListsDropdownContent
          closetLists={closetLists}
          item={item}
        />
      </PopoverContent>
    </Popover>
  );
}

const ItemPageOwnWantListsDropdownButton = React.forwardRef(
  ({ closetLists, isVisible, ...props }, ref) => {
    const listsToShow = closetLists.filter((cl) => cl.hasItem);

    let buttonText;
    if (listsToShow.length === 1) {
      buttonText = `In list: "${listsToShow[0].name}"`;
    } else if (listsToShow.length > 1) {
      const listNames = listsToShow.map((cl) => `"${cl.name}"`).join(", ");
      buttonText = `${listsToShow.length} lists: ${listNames}`;
    } else {
      buttonText = "Add to list";
    }

    return (
      <Flex
        ref={ref}
        as="button"
        fontSize="xs"
        alignItems="center"
        borderRadius="sm"
        width="100%"
        _hover={{ textDecoration: "underline" }}
        _focus={{
          textDecoration: "underline",
          outline: "0",
          boxShadow: "outline",
        }}
        // Even when the button isn't visible, we still render it for layout
        // purposes, but hidden and disabled.
        opacity={isVisible ? 1 : 0}
        aria-hidden={!isVisible}
        disabled={!isVisible}
        {...props}
      >
        {/* Flex tricks to center the text, ignoring the caret */}
        <Box flex="1 0 0" />
        <Box textOverflow="ellipsis" overflow="hidden" whiteSpace="nowrap">
          {buttonText}
        </Box>
        <Flex flex="1 0 0">
          <ChevronDownIcon marginLeft="1" />
        </Flex>
      </Flex>
    );
  }
);

function ItemPageOwnWantListsDropdownContent({ closetLists, item }) {
  return (
    <Box as="ul" listStyleType="none">
      {closetLists.map((closetList) => (
        <Box key={closetList.id} as="li">
          <ItemPageOwnWantsListsDropdownRow
            closetList={closetList}
            item={item}
          />
        </Box>
      ))}
    </Box>
  );
}

function ItemPageOwnWantsListsDropdownRow({ closetList, item }) {
  const toast = useToast();

  const [sendAddToListMutation] = useMutation(
    gql`
      mutation ItemPage_AddToClosetList($listId: ID!, $itemId: ID!) {
        addItemToClosetList(
          listId: $listId
          itemId: $itemId
          removeFromDefaultList: true
        ) {
          id
          hasItem(itemId: $itemId)
        }
      }
    `,
    { context: { sendAuth: true } }
  );

  const [sendRemoveFromListMutation] = useMutation(
    gql`
      mutation ItemPage_RemoveFromClosetList($listId: ID!, $itemId: ID!) {
        removeItemFromClosetList(
          listId: $listId
          itemId: $itemId
          ensureInSomeList: true
        ) {
          id
          hasItem(itemId: $itemId)
        }
      }
    `,
    { context: { sendAuth: true } }
  );

  const onChange = React.useCallback(
    (e) => {
      if (e.target.checked) {
        sendAddToListMutation({
          variables: { listId: closetList.id, itemId: item.id },
          optimisticResponse: {
            addItemToClosetList: {
              __typename: "ClosetList",
              id: closetList.id,
              hasItem: true,
            },
          },
        }).catch((error) => {
          console.error(error);
          toast({
            status: "error",
            title: `Oops, error adding "${item.name}" to "${closetList.name}!"`,
            description:
              "Check your connection and try again? Sorry about this!",
          });
        });
      } else {
        sendRemoveFromListMutation({
          variables: { listId: closetList.id, itemId: item.id },
          optimisticResponse: {
            removeItemFromClosetList: {
              __typename: "ClosetList",
              id: closetList.id,
              hasItem: false,
            },
          },
        }).catch((error) => {
          console.error(error);
          toast({
            status: "error",
            title: `Oops, error removing "${item.name}" from "${closetList.name}!"`,
            description:
              "Check your connection and try again? Sorry about this!",
          });
        });
      }
    },
    [closetList, item, sendAddToListMutation, sendRemoveFromListMutation, toast]
  );

  return (
    <Checkbox
      size="sm"
      width="100%"
      value={closetList.id}
      isChecked={closetList.hasItem}
      onChange={onChange}
    >
      {closetList.name}
    </Checkbox>
  );
}

function ItemPageOwnButton({ itemId, isChecked }) {
  const theme = useTheme();
  const toast = useToast();

  const [sendAddMutation] = useMutation(
    gql`
      mutation ItemPageOwnButtonAdd($itemId: ID!) {
        addToItemsCurrentUserOwns(itemId: $itemId) {
          id
          currentUserOwnsThis
        }
      }
    `,
    {
      variables: { itemId },
      context: { sendAuth: true },
      optimisticResponse: {
        __typename: "Mutation",
        addToItemsCurrentUserOwns: {
          __typename: "Item",
          id: itemId,
          currentUserOwnsThis: true,
        },
      },
      // TODO: Refactor the mutation result to include closet lists
      refetchQueries: [
        {
          query: ITEM_PAGE_OWN_WANT_BUTTONS_QUERY,
          variables: { itemId },
          context: { sendAuth: true },
        },
      ],
    }
  );

  const [sendRemoveMutation] = useMutation(
    gql`
      mutation ItemPageOwnButtonRemove($itemId: ID!) {
        removeFromItemsCurrentUserOwns(itemId: $itemId) {
          id
          currentUserOwnsThis
        }
      }
    `,
    {
      variables: { itemId },
      context: { sendAuth: true },
      optimisticResponse: {
        __typename: "Mutation",
        removeFromItemsCurrentUserOwns: {
          __typename: "Item",
          id: itemId,
          currentUserOwnsThis: false,
        },
      },
      // TODO: Refactor the mutation result to include closet lists
      refetchQueries: [
        {
          query: ITEM_PAGE_OWN_WANT_BUTTONS_QUERY,
          variables: { itemId },
          context: { sendAuth: true },
        },
      ],
    }
  );

  return (
    <ClassNames>
      {({ css }) => (
        <Box as="label">
          <VisuallyHidden
            as="input"
            type="checkbox"
            checked={isChecked}
            onChange={(e) => {
              if (e.target.checked) {
                sendAddMutation().catch((e) => {
                  console.error(e);
                  toast({
                    title: "We had trouble adding this to the items you own.",
                    description:
                      "Check your internet connection, and try again.",
                    status: "error",
                    duration: 5000,
                  });
                });
              } else {
                sendRemoveMutation().catch((e) => {
                  console.error(e);
                  toast({
                    title:
                      "We had trouble removing this from the items you own.",
                    description:
                      "Check your internet connection, and try again.",
                    status: "error",
                    duration: 5000,
                  });
                });
              }
            }}
          />
          <Button
            as="div"
            colorScheme={isChecked ? "green" : "gray"}
            size="lg"
            cursor="pointer"
            transitionDuration="0.4s"
            className={css`
              input:focus + & {
                box-shadow: ${theme.shadows.outline};
              }
            `}
          >
            <IconCheckbox
              icon={<CheckIcon />}
              isChecked={isChecked}
              marginRight="0.5em"
            />
            I own this
          </Button>
        </Box>
      )}
    </ClassNames>
  );
}

function ItemPageWantButton({ itemId, isChecked }) {
  const theme = useTheme();
  const toast = useToast();

  const [sendAddMutation] = useMutation(
    gql`
      mutation ItemPageWantButtonAdd($itemId: ID!) {
        addToItemsCurrentUserWants(itemId: $itemId) {
          id
          currentUserWantsThis
        }
      }
    `,
    {
      variables: { itemId },
      context: { sendAuth: true },
      optimisticResponse: {
        __typename: "Mutation",
        addToItemsCurrentUserWants: {
          __typename: "Item",
          id: itemId,
          currentUserWantsThis: true,
        },
      },
      // TODO: Refactor the mutation result to include closet lists
      refetchQueries: [
        {
          query: ITEM_PAGE_OWN_WANT_BUTTONS_QUERY,
          variables: { itemId },
          context: { sendAuth: true },
        },
      ],
    }
  );

  const [sendRemoveMutation] = useMutation(
    gql`
      mutation ItemPageWantButtonRemove($itemId: ID!) {
        removeFromItemsCurrentUserWants(itemId: $itemId) {
          id
          currentUserWantsThis
        }
      }
    `,
    {
      variables: { itemId },
      context: { sendAuth: true },
      optimisticResponse: {
        __typename: "Mutation",
        removeFromItemsCurrentUserWants: {
          __typename: "Item",
          id: itemId,
          currentUserWantsThis: false,
        },
      },
      // TODO: Refactor the mutation result to include closet lists
      refetchQueries: [
        {
          query: ITEM_PAGE_OWN_WANT_BUTTONS_QUERY,
          variables: { itemId },
          context: { sendAuth: true },
        },
      ],
    }
  );

  return (
    <ClassNames>
      {({ css }) => (
        <Box as="label">
          <VisuallyHidden
            as="input"
            type="checkbox"
            checked={isChecked}
            onChange={(e) => {
              if (e.target.checked) {
                sendAddMutation().catch((e) => {
                  console.error(e);
                  toast({
                    title: "We had trouble adding this to the items you want.",
                    description:
                      "Check your internet connection, and try again.",
                    status: "error",
                    duration: 5000,
                  });
                });
              } else {
                sendRemoveMutation().catch((e) => {
                  console.error(e);
                  toast({
                    title:
                      "We had trouble removing this from the items you want.",
                    description:
                      "Check your internet connection, and try again.",
                    status: "error",
                    duration: 5000,
                  });
                });
              }
            }}
          />
          <Button
            as="div"
            colorScheme={isChecked ? "blue" : "gray"}
            size="lg"
            cursor="pointer"
            transitionDuration="0.4s"
            className={css`
              input:focus + & {
                box-shadow: ${theme.shadows.outline};
              }
            `}
          >
            <IconCheckbox
              icon={<StarIcon />}
              isChecked={isChecked}
              marginRight="0.5em"
            />
            I want this
          </Button>
        </Box>
      )}
    </ClassNames>
  );
}

function ItemPageTradeLinks({ itemId, isEmbedded }) {
  const { data, loading, error } = useQuery(
    gql`
      query ItemPageTradeLinks($itemId: ID!) {
        item(id: $itemId) {
          id
          numUsersOfferingThis
          numUsersSeekingThis
        }
      }
    `,
    { variables: { itemId } }
  );

  if (error) {
    return <Box color="red.400">{error.message}</Box>;
  }

  return (
    <HStack spacing="2">
      <Box as="header" fontSize="sm" fontWeight="bold">
        Trading:
      </Box>
      <SubtleSkeleton isLoaded={!loading}>
        <ItemPageTradeLink
          href={`/items/${itemId}/trades/offering`}
          count={data?.item?.numUsersOfferingThis || 0}
          label="offering"
          colorScheme="green"
          isEmbedded={isEmbedded}
        />
      </SubtleSkeleton>
      <SubtleSkeleton isLoaded={!loading}>
        <ItemPageTradeLink
          href={`/items/${itemId}/trades/seeking`}
          count={data?.item?.numUsersSeekingThis || 0}
          label="seeking"
          colorScheme="blue"
          isEmbedded={isEmbedded}
        />
      </SubtleSkeleton>
    </HStack>
  );
}

function ItemPageTradeLink({ href, count, label, colorScheme, isEmbedded }) {
  return (
    <Button
      as="a"
      href={href}
      target={isEmbedded ? "_blank" : undefined}
      size="xs"
      variant="outline"
      colorScheme={colorScheme}
      borderRadius="full"
      paddingRight="1"
    >
      <Box display="grid" gridTemplateAreas="single-area">
        <Box gridArea="single-area" display="flex" justifyContent="center">
          {count} {label} <ChevronRightIcon minHeight="1.2em" />
        </Box>
        <Box
          gridArea="single-area"
          display="flex"
          justifyContent="center"
          visibility="hidden"
        >
          888 offering <ChevronRightIcon minHeight="1.2em" />
        </Box>
      </Box>
    </Button>
  );
}

function IconCheckbox({ icon, isChecked, ...props }) {
  return (
    <Box display="grid" gridTemplateAreas="the-same-area" {...props}>
      <Box
        gridArea="the-same-area"
        width="1em"
        height="1em"
        border="2px solid currentColor"
        borderRadius="md"
        opacity={isChecked ? "0" : "0.75"}
        transform={isChecked ? "scale(0.75)" : "none"}
        transition="all 0.4s"
      />
      <Box
        gridArea="the-same-area"
        display="flex"
        opacity={isChecked ? "1" : "0"}
        transform={isChecked ? "none" : "scale(0.1)"}
        transition="all 0.4s"
      >
        {icon}
      </Box>
    </Box>
  );
}

function ItemPageOutfitPreview({ itemId }) {
  const idealPose = React.useMemo(
    () => (Math.random() > 0.5 ? "HAPPY_FEM" : "HAPPY_MASC"),
    []
  );
  const [petState, setPetState] = React.useState({
    // We'll fill these in once the canonical appearance data arrives.
    speciesId: null,
    colorId: null,
    pose: null,
    isValid: false,

    // We use appearance ID, in addition to the above, to give the Apollo cache
    // a really clear hint that the canonical pet appearance we preloaded is
    // the exact right one to show! But switching species/color will null this
    // out again, and that's okay. (We'll do an unnecessary reload if you
    // switch back to it though... we could maybe do something clever there!)
    appearanceId: null,
  });
  const [preferredSpeciesId, setPreferredSpeciesId] = useLocalStorage(
    "DTIItemPreviewPreferredSpeciesId",
    null
  );
  const [preferredColorId, setPreferredColorId] = useLocalStorage(
    "DTIItemPreviewPreferredColorId",
    null
  );

  const setPetStateFromUserAction = React.useCallback(
    (newPetState) =>
      setPetState((prevPetState) => {
        // When the user _intentionally_ chooses a species or color, save it in
        // local storage for next time. (This won't update when e.g. their
        // preferred species or color isn't available for this item, so we update
        // to the canonical species or color automatically.)
        //
        // Re the "ifs", I have no reason to expect null to come in here, but,
        // since this is touching client-persisted data, I want it to be even more
        // reliable than usual!
        if (
          newPetState.speciesId &&
          newPetState.speciesId !== prevPetState.speciesId
        ) {
          setPreferredSpeciesId(newPetState.speciesId);
        }
        if (
          newPetState.colorId &&
          newPetState.colorId !== prevPetState.colorId
        ) {
          if (colorIsBasic(newPetState.colorId)) {
            // When the user chooses a basic color, don't index on it specifically,
            // and instead reset to use default colors.
            setPreferredColorId(null);
          } else {
            setPreferredColorId(newPetState.colorId);
          }
        }

        return newPetState;
      }),
    [setPreferredColorId, setPreferredSpeciesId]
  );

  // We don't need to reload this query when preferred species/color change, so
  // cache their initial values here to use as query arguments.
  const [initialPreferredSpeciesId] = React.useState(preferredSpeciesId);
  const [initialPreferredColorId] = React.useState(preferredColorId);

  // Start by loading the "canonical" pet and item appearance for the outfit
  // preview. We'll use this to initialize both the preview and the picker.
  //
  // If the user has a preferred species saved from using the ItemPage in the
  // past, we'll send that instead. This will return the appearance on that
  // species if possible, or the default canonical species if not.
  //
  // TODO: If this is a non-standard pet color, like Mutant, we'll do an extra
  //       query after this loads, because our Apollo cache can't detect the
  //       shared item appearance. (For standard colors though, our logic to
  //       cover standard-color switches works for this preloading too.)
  const {
    loading: loadingGQL,
    error: errorGQL,
    data,
  } = useQuery(
    gql`
      query ItemPageOutfitPreview(
        $itemId: ID!
        $preferredSpeciesId: ID
        $preferredColorId: ID
      ) {
        item(id: $itemId) {
          id
          name
          restrictedZones {
            id
            label @client
          }
          compatibleBodiesAndTheirZones {
            body {
              id
              representsAllBodies
              species {
                id
                name
              }
            }
            zones {
              id
              label @client
            }
          }
          canonicalAppearance(
            preferredSpeciesId: $preferredSpeciesId
            preferredColorId: $preferredColorId
          ) {
            id
            ...ItemAppearanceForOutfitPreview
            body {
              id
              canonicalAppearance(preferredColorId: $preferredColorId) {
                id
                species {
                  id
                  name
                }
                color {
                  id
                }
                pose

                ...PetAppearanceForOutfitPreview
              }
            }
          }
        }
      }

      ${itemAppearanceFragment}
      ${petAppearanceFragment}
    `,
    {
      variables: {
        itemId,
        preferredSpeciesId: initialPreferredSpeciesId,
        preferredColorId: initialPreferredColorId,
      },
      onCompleted: (data) => {
        const canonicalBody = data?.item?.canonicalAppearance?.body;
        const canonicalPetAppearance = canonicalBody?.canonicalAppearance;

        setPetState({
          speciesId: canonicalPetAppearance?.species?.id,
          colorId: canonicalPetAppearance?.color?.id,
          pose: canonicalPetAppearance?.pose,
          isValid: true,
          appearanceId: canonicalPetAppearance?.id,
        });
      },
    }
  );

  const compatibleBodies =
    data?.item?.compatibleBodiesAndTheirZones?.map(({ body }) => body) || [];
  const compatibleBodiesAndTheirZones =
    data?.item?.compatibleBodiesAndTheirZones || [];

  // If there's only one compatible body, and the canonical species's name
  // appears in the item name, then this is probably a species-specific item,
  // and we should adjust the UI to avoid implying that other species could
  // model it.
  const isProbablySpeciesSpecific =
    compatibleBodies.length === 1 &&
    !compatibleBodies[0].representsAllBodies &&
    (data?.item?.name || "").includes(
      data?.item?.canonicalAppearance?.body?.canonicalAppearance?.species?.name
    );
  const couldProbablyModelMoreData = !isProbablySpeciesSpecific;

  // TODO: Does this double-trigger the HTTP request with SpeciesColorPicker?
  const {
    loading: loadingValids,
    error: errorValids,
    valids,
  } = useAllValidPetPoses();

  const [hasAnimations, setHasAnimations] = React.useState(false);
  const [isPaused, setIsPaused] = useLocalStorage("DTIOutfitIsPaused", true);

  // This is like <OutfitPreview />, but we can use the appearance data, too!
  const { appearance, preview } = useOutfitPreview({
    speciesId: petState.speciesId,
    colorId: petState.colorId,
    pose: petState.pose,
    appearanceId: petState.appearanceId,
    wornItemIds: [itemId],
    isLoading: loadingGQL || loadingValids,
    spinnerVariant: "corner",
    engine: "canvas",
    onChangeHasAnimations: setHasAnimations,
  });

  // If there's an appearance loaded for this item, but it's empty, then the
  // item is incompatible. (There should only be one item appearance: this one!)
  const itemAppearance = appearance?.itemAppearances?.[0];
  const itemLayers = itemAppearance?.layers || [];
  const isCompatible = itemLayers.length > 0;
  const usesHTML5 = itemLayers.every(layerUsesHTML5);

  const onChange = React.useCallback(
    ({ speciesId, colorId }) => {
      const validPoses = getValidPoses(valids, speciesId, colorId);
      const pose = getClosestPose(validPoses, idealPose);
      setPetStateFromUserAction({
        speciesId,
        colorId,
        pose,
        isValid: true,
        appearanceId: null,
      });
    },
    [valids, idealPose, setPetStateFromUserAction]
  );

  const borderColor = useColorModeValue("green.700", "green.400");
  const errorColor = useColorModeValue("red.600", "red.400");

  const error = errorGQL || errorValids;
  if (error) {
    return <Box color="red.400">{error.message}</Box>;
  }

  return (
    <Grid
      templateAreas={{
        base: `
          "preview"
          "speciesColorPicker"
          "speciesFacesPicker"
          "zones"
        `,
        md: `
          "preview             speciesFacesPicker"
          "speciesColorPicker  zones"
        `,
      }}
      // HACK: Really I wanted 400px to match the natural height of the
      //       preview in md, but in Chromium that creates a scrollbar and
      //       401px doesn't, not sure exactly why?
      templateRows={{
        base: "auto auto 200px auto",
        md: "401px auto",
      }}
      templateColumns={{
        base: "minmax(min-content, 400px)",
        md: "minmax(min-content, 400px) fit-content(480px)",
      }}
      rowGap="4"
      columnGap="6"
      justifyContent="center"
    >
      <AspectRatio
        gridArea="preview"
        maxWidth="400px"
        maxHeight="400px"
        ratio="1"
        border="1px"
        borderColor={borderColor}
        transition="border-color 0.2s"
        borderRadius="lg"
        boxShadow="lg"
        overflow="hidden"
      >
        <Box>
          {petState.isValid && preview}
          <CustomizeMoreButton
            speciesId={petState.speciesId}
            colorId={petState.colorId}
            pose={petState.pose}
            itemId={itemId}
            isDisabled={!petState.isValid}
          />
          {hasAnimations && (
            <PlayPauseButton
              isPaused={isPaused}
              onClick={() => setIsPaused(!isPaused)}
            />
          )}
        </Box>
      </AspectRatio>
      <Flex gridArea="speciesColorPicker" alignSelf="start" align="center">
        <Box
          // This box grows at the same rate as the box on the right, so the
          // middle box will be centered, if there's space!
          flex="1 0 0"
        />
        <SpeciesColorPicker
          speciesId={petState.speciesId}
          colorId={petState.colorId}
          pose={petState.pose}
          idealPose={idealPose}
          onChange={(species, color, isValid, closestPose) => {
            setPetStateFromUserAction({
              speciesId: species.id,
              colorId: color.id,
              pose: closestPose,
              isValid,
              appearanceId: null,
            });
          }}
          speciesIsDisabled={isProbablySpeciesSpecific}
          size="sm"
          showPlaceholders
        />
        <Box flex="1 0 0" lineHeight="1" paddingLeft="1">
          {
            // Wait for us to start _requesting_ the appearance, and _then_
            // for it to load, and _then_ check compatibility.
            !loadingGQL &&
              !appearance.loading &&
              petState.isValid &&
              !isCompatible && (
                <Tooltip
                  label={
                    couldProbablyModelMoreData
                      ? "Item needs models"
                      : "Not compatible"
                  }
                  placement="top"
                >
                  <WarningIcon
                    color={errorColor}
                    transition="color 0.2"
                    marginLeft="2"
                    borderRadius="full"
                    tabIndex="0"
                    _focus={{ outline: "none", boxShadow: "outline" }}
                  />
                </Tooltip>
              )
          }
        </Box>
      </Flex>
      <Box
        gridArea="speciesFacesPicker"
        paddingTop="2"
        overflow="auto"
        padding="8px"
      >
        <SpeciesFacesPicker
          selectedSpeciesId={petState.speciesId}
          selectedColorId={petState.colorId}
          compatibleBodies={compatibleBodies}
          couldProbablyModelMoreData={couldProbablyModelMoreData}
          onChange={onChange}
          isLoading={loadingGQL || loadingValids}
        />
      </Box>
      <Flex gridArea="zones" justifySelf="center" align="center">
        {compatibleBodiesAndTheirZones.length > 0 && (
          <ItemZonesInfo
            compatibleBodiesAndTheirZones={compatibleBodiesAndTheirZones}
            restrictedZones={data?.item?.restrictedZones || []}
          />
        )}
        <Box width="6" />
        <Flex
          // Avoid layout shift while loading
          minWidth="54px"
        >
          <HTML5Badge
            usesHTML5={usesHTML5}
            // If we're not compatible, act the same as if we're loading:
            // don't change the badge, but don't show one yet if we don't
            // have one yet.
            isLoading={appearance.loading || !isCompatible}
          />
        </Flex>
      </Flex>
    </Grid>
  );
}

function CustomizeMoreButton({ speciesId, colorId, pose, itemId, isDisabled }) {
  const url =
    `/outfits/new?species=${speciesId}&color=${colorId}&pose=${pose}&` +
    `objects[]=${itemId}`;

  // The default background is good in light mode, but in dark mode it's a
  // very subtle transparent white... make it a semi-transparent black, for
  // better contrast against light-colored background items!
  const backgroundColor = useColorModeValue(undefined, "blackAlpha.700");
  const backgroundColorHover = useColorModeValue(undefined, "blackAlpha.900");

  return (
    <LinkOrButton
      href={isDisabled ? null : url}
      role="group"
      position="absolute"
      top="2"
      right="2"
      size="sm"
      background={backgroundColor}
      _hover={{ backgroundColor: backgroundColorHover }}
      _focus={{ backgroundColor: backgroundColorHover, boxShadow: "outline" }}
      boxShadow="sm"
      isDisabled={isDisabled}
    >
      <ExpandOnGroupHover paddingRight="2">Customize more</ExpandOnGroupHover>
      <EditIcon />
    </LinkOrButton>
  );
}

function LinkOrButton({ href, ...props }) {
  if (href != null) {
    return <Button as="a" href={href} {...props} />;
  } else {
    return <Button {...props} />;
  }
}

/**
 * ExpandOnGroupHover starts at width=0, and expands to full width when a
 * parent with role="group" gains hover or focus state.
 */
function ExpandOnGroupHover({ children, ...props }) {
  const [measuredWidth, setMeasuredWidth] = React.useState(null);
  const measurerRef = React.useRef(null);
  const prefersReducedMotion = usePrefersReducedMotion();

  React.useLayoutEffect(() => {
    if (!measurerRef) {
      // I don't think this is possible, but I'd like to know if it happens!
      logAndCapture(
        new Error(
          `Measurer node not ready during effect. Transition won't be smooth.`
        )
      );
      return;
    }

    if (measuredWidth != null) {
      // Skip re-measuring when we already have a measured width. This is
      // mainly defensive, to prevent the possibility of loops, even though
      // this algorithm should be stable!
      return;
    }

    const newMeasuredWidth = measurerRef.current.offsetWidth;
    setMeasuredWidth(newMeasuredWidth);
  }, [measuredWidth]);

  return (
    <Flex
      // In block layout, the overflowing children would _also_ be constrained
      // to width 0. But in flex layout, overflowing children _keep_ their
      // natural size, so we can measure it even when not visible.
      width="0"
      overflow="hidden"
      // Right-align the children, to keep the text feeling right-aligned when
      // we expand. (To support left-side expansion, make this a prop!)
      justify="flex-end"
      // If the width somehow isn't measured yet, expand to width `auto`, which
      // won't transition smoothly but at least will work!
      _groupHover={{ width: measuredWidth ? measuredWidth + "px" : "auto" }}
      _groupFocus={{ width: measuredWidth ? measuredWidth + "px" : "auto" }}
      transition={!prefersReducedMotion && "width 0.2s"}
    >
      <Box ref={measurerRef} {...props}>
        {children}
      </Box>
    </Flex>
  );
}

function PlayPauseButton({ isPaused, onClick }) {
  return (
    <IconButton
      icon={isPaused ? <MdPlayArrow /> : <MdPause />}
      aria-label={isPaused ? "Play" : "Pause"}
      onClick={onClick}
      borderRadius="full"
      boxShadow="md"
      color="gray.50"
      backgroundColor="blackAlpha.700"
      position="absolute"
      bottom="2"
      left="2"
      _hover={{ backgroundColor: "blackAlpha.900" }}
      _focus={{ backgroundColor: "blackAlpha.900" }}
    />
  );
}

export function ItemZonesInfo({
  compatibleBodiesAndTheirZones,
  restrictedZones,
}) {
  // Reorganize the body-and-zones data, into zone-and-bodies data. Also, we're
  // merging zones with the same label, because that's how user-facing zone UI
  // generally works!
  const zoneLabelsAndTheirBodiesMap = {};
  for (const { body, zones } of compatibleBodiesAndTheirZones) {
    for (const zone of zones) {
      if (!zoneLabelsAndTheirBodiesMap[zone.label]) {
        zoneLabelsAndTheirBodiesMap[zone.label] = {
          zoneLabel: zone.label,
          bodies: [],
        };
      }
      zoneLabelsAndTheirBodiesMap[zone.label].bodies.push(body);
    }
  }
  const zoneLabelsAndTheirBodies = Object.values(zoneLabelsAndTheirBodiesMap);

  const sortedZonesAndTheirBodies = [...zoneLabelsAndTheirBodies].sort((a, b) =>
    buildSortKeyForZoneLabelsAndTheirBodies(a).localeCompare(
      buildSortKeyForZoneLabelsAndTheirBodies(b)
    )
  );

  const restrictedZoneLabels = [
    ...new Set(restrictedZones.map((z) => z.label)),
  ].sort();

  // We only show body info if there's more than one group of bodies to talk
  // about. If they all have the same zones, it's clear from context that any
  // preview available in the list has the zones listed here.
  const bodyGroups = new Set(
    zoneLabelsAndTheirBodies.map(({ bodies }) =>
      bodies.map((b) => b.id).join(",")
    )
  );
  const showBodyInfo = bodyGroups.size > 1;

  return (
    <Flex
      fontSize="sm"
      textAlign="center"
      // If the text gets too long, wrap Restricts onto another line, and center
      // them relative to each other.
      wrap="wrap"
      justify="center"
      data-test-id="item-zones-info"
    >
      <Box flex="0 0 auto" maxWidth="100%">
        <Box as="header" fontWeight="bold" display="inline">
          Occupies:
        </Box>{" "}
        <Box as="ul" listStyleType="none" display="inline">
          {sortedZonesAndTheirBodies.map(({ zoneLabel, bodies }) => (
            <Box
              key={zoneLabel}
              as="li"
              display="inline"
              _notLast={{ _after: { content: '", "' } }}
            >
              <Box
                as="span"
                // Don't wrap any of the list item content. But, by putting
                // this in an extra container element, we _do_ allow wrapping
                // _between_ list items.
                whiteSpace="nowrap"
              >
                <ItemZonesInfoListItem
                  zoneLabel={zoneLabel}
                  bodies={bodies}
                  showBodyInfo={showBodyInfo}
                />
              </Box>
            </Box>
          ))}
        </Box>
      </Box>
      <Box width="4" flex="0 0 auto" />
      <Box flex="0 0 auto" maxWidth="100%">
        <Box as="header" fontWeight="bold" display="inline">
          Restricts:
        </Box>{" "}
        {restrictedZoneLabels.length > 0 ? (
          <Box as="ul" listStyleType="none" display="inline">
            {restrictedZoneLabels.map((zoneLabel) => (
              <Box
                key={zoneLabel}
                as="li"
                display="inline"
                _notLast={{ _after: { content: '", "' } }}
              >
                <Box
                  as="span"
                  // Don't wrap any of the list item content. But, by putting
                  // this in an extra container element, we _do_ allow wrapping
                  // _between_ list items.
                  whiteSpace="nowrap"
                >
                  {zoneLabel}
                </Box>
              </Box>
            ))}
          </Box>
        ) : (
          <Box as="span" fontStyle="italic" opacity="0.8">
            N/A
          </Box>
        )}
      </Box>
    </Flex>
  );
}

function ItemZonesInfoListItem({ zoneLabel, bodies, showBodyInfo }) {
  let content = zoneLabel;

  if (showBodyInfo) {
    if (bodies.some((b) => b.representsAllBodies)) {
      content = <>{content} (all species)</>;
    } else {
      // TODO: This is a bit reductive, if it's different for like special
      //       colors, e.g. Blue Acara vs Mutant Acara, this will just show
      //       "Acara" in either case! (We are at least gonna be defensive here
      //       and remove duplicates, though, in case both the Blue Acara and
      //       Mutant Acara body end up in the same list.)
      const speciesNames = new Set(bodies.map((b) => b.species.name));
      const speciesListString = [...speciesNames].sort().join(", ");

      content = (
        <>
          {content}{" "}
          <Tooltip
            label={speciesListString}
            textAlign="center"
            placement="bottom"
          >
            <Box
              as="span"
              tabIndex="0"
              _focus={{ outline: "none", boxShadow: "outline" }}
              fontStyle="italic"
              textDecoration="underline"
              style={{ textDecorationStyle: "dotted" }}
              opacity="0.8"
            >
              {/* Show the speciesNames count, even though it's less info,
               * because it's more important that the tooltip content matches
               * the count we show! */}
              ({speciesNames.size} species)
            </Box>
          </Tooltip>
        </>
      );
    }
  }

  return content;
}

function buildSortKeyForZoneLabelsAndTheirBodies({ zoneLabel, bodies }) {
  // Sort by "represents all bodies", then by body count descending, then
  // alphabetically.
  const representsAllBodies = bodies.some((body) => body.representsAllBodies);

  // To sort by body count _descending_, we subtract it from a large number.
  // Then, to make it work in string comparison, we pad it with leading zeroes.
  // Hacky but solid!
  const inverseBodyCount = (9999 - bodies.length).toString().padStart(4, "0");

  return `${representsAllBodies ? "A" : "Z"}-${inverseBodyCount}-${zoneLabel}`;
}

export default ItemPage;
