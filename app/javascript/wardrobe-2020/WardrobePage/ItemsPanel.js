import React from "react";
import { ClassNames } from "@emotion/react";
import {
  Box,
  Editable,
  EditablePreview,
  EditableInput,
  Flex,
  IconButton,
  Skeleton,
  Tooltip,
  VisuallyHidden,
  Menu,
  MenuButton,
  MenuList,
  MenuItem,
  Portal,
  Button,
  Spinner,
  useColorModeValue,
  Modal,
  ModalContent,
  ModalOverlay,
  ModalHeader,
  ModalBody,
  ModalFooter,
  useDisclosure,
  ModalCloseButton,
} from "@chakra-ui/react";
import {
  CheckIcon,
  DeleteIcon,
  EditIcon,
  QuestionIcon,
  WarningTwoIcon,
} from "@chakra-ui/icons";
import { CSSTransition, TransitionGroup } from "react-transition-group";

import {
  Delay,
  ErrorMessage,
  getGraphQLErrorMessage,
  Heading1,
  Heading2,
} from "../util";
import Item, { ItemListContainer, ItemListSkeleton } from "./Item";
import { BiRename } from "react-icons/bi";
import { IoCloudUploadOutline } from "react-icons/io5";
import { MdMoreVert } from "react-icons/md";
import { buildOutfitUrl } from "./useOutfitState";
import { gql, useMutation } from "@apollo/client";
import { useRouter } from "next/router";

/**
 * ItemsPanel shows the items in the current outfit, and lets the user toggle
 * between them! It also shows an editable outfit name, to help set context.
 *
 * Note that this component provides an effective 1 unit of padding around
 * itself, which is uncommon in this app: we usually prefer to let parents
 * control the spacing!
 *
 * This is because Item has padding, but it's generally not visible; so, to
 * *look* aligned with the other elements like the headings, the headings need
 * to have extra padding. Essentially: while the Items _do_ stretch out the
 * full width of the container, it doesn't look like it!
 */
function ItemsPanel({ outfitState, outfitSaving, loading, dispatchToOutfit }) {
  const { zonesAndItems, incompatibleItems } = outfitState;

  return (
    <ClassNames>
      {({ css }) => (
        <Box>
          <Box px="1">
            <OutfitHeading
              outfitState={outfitState}
              outfitSaving={outfitSaving}
              dispatchToOutfit={dispatchToOutfit}
            />
          </Box>
          <Flex direction="column">
            {loading ? (
              <ItemZoneGroupsSkeleton
                itemCount={outfitState.allItemIds.length}
              />
            ) : (
              <TransitionGroup component={null}>
                {zonesAndItems.map(({ zoneLabel, items }) => (
                  <CSSTransition
                    key={zoneLabel}
                    {...fadeOutAndRollUpTransition(css)}
                  >
                    <ItemZoneGroup
                      zoneLabel={zoneLabel}
                      items={items}
                      outfitState={outfitState}
                      dispatchToOutfit={dispatchToOutfit}
                    />
                  </CSSTransition>
                ))}
                {incompatibleItems.length > 0 && (
                  <ItemZoneGroup
                    zoneLabel="Incompatible"
                    afterHeader={
                      <Tooltip
                        label="These items don't fit this pet"
                        placement="top"
                        openDelay={100}
                      >
                        <QuestionIcon fontSize="sm" />
                      </Tooltip>
                    }
                    items={incompatibleItems}
                    outfitState={outfitState}
                    dispatchToOutfit={dispatchToOutfit}
                    isDisabled
                  />
                )}
              </TransitionGroup>
            )}
          </Flex>
        </Box>
      )}
    </ClassNames>
  );
}

/**
 * ItemZoneGroup shows the items for a particular zone, and lets the user
 * toggle between them.
 *
 * For each item, it renders a <label> with a visually-hidden radio button and
 * the Item component (which will visually reflect the radio's state). This
 * makes the list screen-reader- and keyboard-accessible!
 */
function ItemZoneGroup({
  zoneLabel,
  items,
  outfitState,
  dispatchToOutfit,
  isDisabled = false,
  afterHeader = null,
}) {
  // onChange is fired when the radio button becomes checked, not unchecked!
  const onChange = (e) => {
    const itemId = e.target.value;
    dispatchToOutfit({ type: "wearItem", itemId });
  };

  // Clicking the radio button when already selected deselects it - this is how
  // you can select none!
  const onClick = (e) => {
    const itemId = e.target.value;
    if (outfitState.wornItemIds.includes(itemId)) {
      // We need the event handler to finish before this, so that simulated
      // events don't just come back around and undo it - but we can't just
      // solve that with `preventDefault`, because it breaks the radio's
      // intended visual updates when we unwear. So, we `setTimeout` to do it
      // after all event handlers resolve!
      setTimeout(() => dispatchToOutfit({ type: "unwearItem", itemId }), 0);
    }
  };

  const onRemove = React.useCallback(
    (itemId) => {
      dispatchToOutfit({ type: "removeItem", itemId });
    },
    [dispatchToOutfit]
  );

  return (
    <ClassNames>
      {({ css }) => (
        <Box mb="10">
          <Heading2 display="flex" alignItems="center" mx="1">
            {zoneLabel}
            {afterHeader && <Box marginLeft="2">{afterHeader}</Box>}
          </Heading2>
          <ItemListContainer>
            <TransitionGroup component={null}>
              {items.map((item) => {
                const itemNameId =
                  zoneLabel.replace(/ /g, "-") + `-item-${item.id}-name`;
                const itemNode = (
                  <Item
                    item={item}
                    itemNameId={itemNameId}
                    isWorn={
                      !isDisabled && outfitState.wornItemIds.includes(item.id)
                    }
                    isInOutfit={outfitState.allItemIds.includes(item.id)}
                    onRemove={onRemove}
                    isDisabled={isDisabled}
                  />
                );

                return (
                  <CSSTransition
                    key={item.id}
                    {...fadeOutAndRollUpTransition(css)}
                  >
                    {isDisabled ? (
                      itemNode
                    ) : (
                      <label>
                        <VisuallyHidden
                          as="input"
                          type="radio"
                          aria-labelledby={itemNameId}
                          name={zoneLabel}
                          value={item.id}
                          checked={outfitState.wornItemIds.includes(item.id)}
                          onChange={onChange}
                          onClick={onClick}
                          onKeyUp={(e) => {
                            if (e.key === " ") {
                              onClick(e);
                            }
                          }}
                        />
                        {itemNode}
                      </label>
                    )}
                  </CSSTransition>
                );
              })}
            </TransitionGroup>
          </ItemListContainer>
        </Box>
      )}
    </ClassNames>
  );
}

/**
 * ItemZoneGroupSkeletons is a placeholder for when the items are loading.
 *
 * We try to match the approximate size of the incoming data! This is
 * especially nice for when you start with a fresh pet from the homepage, so
 * we don't show skeleton items that just clear away!
 */
function ItemZoneGroupsSkeleton({ itemCount }) {
  const groups = [];
  for (let i = 0; i < itemCount; i++) {
    // NOTE: I initially wrote this to return groups of 3, which looks good for
    //     outfit shares I think, but looks bad for pet loading... once shares
    //     become a more common use case, it might be useful to figure out how
    //     to differentiate these cases and show 1-per-group for pets, but
    //     maybe more for built outfits?
    groups.push(<ItemZoneGroupSkeleton key={i} itemCount={1} />);
  }
  return groups;
}

/**
 * ItemZoneGroupSkeleton is a placeholder for when an ItemZoneGroup is loading.
 */
function ItemZoneGroupSkeleton({ itemCount }) {
  return (
    <Box mb="10">
      <Delay>
        <Skeleton
          mx="1"
          // 2.25rem font size, 1.25rem line height
          height={`${2.25 * 1.25}rem`}
          width="12rem"
        />
        <ItemListSkeleton count={itemCount} />
      </Delay>
    </Box>
  );
}

/**
 * OutfitSavingIndicator shows a Save button, or the "Saved" or "Saving" state,
 * if the user can save this outfit. If not, this is empty!
 */
function OutfitSavingIndicator({ outfitSaving }) {
  const {
    canSaveOutfit,
    isNewOutfit,
    isSaving,
    latestVersionIsSaved,
    saveError,
    saveOutfit,
  } = outfitSaving;

  const errorTextColor = useColorModeValue("red.600", "red.400");

  if (!canSaveOutfit) {
    return null;
  }

  if (isNewOutfit) {
    return (
      <Button
        variant="outline"
        size="sm"
        isLoading={isSaving}
        loadingText="Saving…"
        leftIcon={
          <Box
            // Adjust the visual balance toward the cloud
            marginBottom="-2px"
          >
            <IoCloudUploadOutline />
          </Box>
        }
        onClick={saveOutfit}
        data-test-id="wardrobe-save-outfit-button"
      >
        Save
      </Button>
    );
  }

  if (isSaving) {
    return (
      <Flex
        align="center"
        fontSize="xs"
        data-test-id="wardrobe-outfit-is-saving-indicator"
      >
        <Spinner
          size="xs"
          marginRight="1.5"
          // HACK: Not sure why my various centering things always feel wrong...
          marginBottom="-2px"
        />
        Saving…
      </Flex>
    );
  }

  if (latestVersionIsSaved) {
    return (
      <Flex
        align="center"
        fontSize="xs"
        data-test-id="wardrobe-outfit-is-saved-indicator"
      >
        <CheckIcon
          marginRight="1"
          // HACK: Not sure why my various centering things always feel wrong...
          marginBottom="-2px"
        />
        Saved
      </Flex>
    );
  }

  if (saveError) {
    return (
      <Flex
        align="center"
        fontSize="xs"
        data-test-id="wardrobe-outfit-save-error-indicator"
        color={errorTextColor}
      >
        <WarningTwoIcon
          marginRight="1"
          // HACK: Not sure why my various centering things always feel wrong...
          marginBottom="-2px"
        />
        Error saving
      </Flex>
    );
  }

  // The most common way we'll hit this null is when the outfit is changing,
  // but the debouncing isn't done yet, so it's not saving yet.
  return null;
}

/**
 * OutfitHeading is an editable outfit name, as a big pretty page heading!
 * It also contains the outfit menu, for saving etc.
 */
function OutfitHeading({ outfitState, outfitSaving, dispatchToOutfit }) {
  const { canDeleteOutfit } = outfitSaving;
  const outfitCopyUrl = buildOutfitUrl(outfitState, { withoutOutfitId: true });

  return (
    // The Editable wraps everything, including the menu, because the menu has
    // a Rename option.
    <Editable
      // Make sure not to ever pass `undefined` into here, or else the
      // component enters uncontrolled mode, and changing the value
      // later won't fix it!
      value={outfitState.name || ""}
      placeholder="Untitled outfit"
      onChange={(value) =>
        dispatchToOutfit({ type: "rename", outfitName: value })
      }
    >
      {({ onEdit }) => (
        <Flex align="center" marginBottom="6">
          <Box>
            <Box role="group" d="inline-block" position="relative" width="100%">
              <Heading1>
                <EditablePreview lineHeight="48px" data-test-id="outfit-name" />
                <EditableInput lineHeight="48px" />
              </Heading1>
            </Box>
          </Box>
          <Box width="4" flex="1 0 auto" />
          <Box flex="0 0 auto">
            <OutfitSavingIndicator outfitSaving={outfitSaving} />
          </Box>
          <Box width="2" />
          <Menu placement="bottom-end">
            <MenuButton
              as={IconButton}
              variant="ghost"
              icon={<MdMoreVert />}
              aria-label="Outfit menu"
              borderRadius="full"
              fontSize="24px"
              opacity="0.8"
            />
            <Portal>
              <MenuList>
                {outfitState.id && (
                  <MenuItem
                    icon={<EditIcon />}
                    as="a"
                    href={outfitCopyUrl}
                    target="_blank"
                  >
                    Edit a copy
                  </MenuItem>
                )}
                <MenuItem
                  icon={<BiRename />}
                  onClick={() => {
                    // Start the rename after a tick, so finishing up the click
                    // won't just immediately remove focus from the Editable.
                    setTimeout(onEdit, 0);
                  }}
                >
                  Rename
                </MenuItem>
                {canDeleteOutfit && (
                  <DeleteOutfitMenuItem outfitState={outfitState} />
                )}
              </MenuList>
            </Portal>
          </Menu>
        </Flex>
      )}
    </Editable>
  );
}

function DeleteOutfitMenuItem({ outfitState }) {
  const { id, name } = outfitState;
  const { isOpen, onOpen, onClose } = useDisclosure();
  const { push: pushHistory } = useRouter();

  const [sendDeleteOutfitMutation, { loading, error }] = useMutation(
    gql`
      mutation DeleteOutfitMenuItem($id: ID!) {
        deleteOutfit(id: $id)
      }
    `,
    {
      context: { sendAuth: true },
      update(cache) {
        // Once this is deleted, evict it from the local cache, and "garbage
        // collect" to force all queries referencing this outfit to reload the
        // next time we see them. (This is especially important since we're
        // about to redirect to the user outfits page, which shouldn't show
        // the outfit anymore!)
        cache.evict(`Outfit:${id}`);
        cache.gc();
      },
    }
  );

  return (
    <>
      <MenuItem icon={<DeleteIcon />} onClick={onOpen}>
        Delete
      </MenuItem>
      <Modal isOpen={isOpen} onClose={onClose}>
        <ModalOverlay />
        <ModalContent>
          <ModalHeader>Delete outfit "{name}"?</ModalHeader>
          <ModalCloseButton />
          <ModalBody>
            We'll delete this data and remove it from your list of outfits.
            Links and image embeds pointing to this outfit will break. Is that
            okay?
            {error && (
              <ErrorMessage marginTop="1em">
                Error deleting outfit: "{getGraphQLErrorMessage(error)}". Try
                again?
              </ErrorMessage>
            )}
          </ModalBody>
          <ModalFooter>
            <Button onClick={onClose}>No, keep this outfit</Button>
            <Box flex="1 0 auto" width="2" />
            <Button
              colorScheme="red"
              onClick={() =>
                sendDeleteOutfitMutation({ variables: { id } })
                  .then(() => {
                    pushHistory(`/your-outfits`);
                  })
                  .catch((e) => {
                    /* handled in error UI */
                  })
              }
              isLoading={loading}
            >
              Delete
            </Button>
          </ModalFooter>
        </ModalContent>
      </Modal>
    </>
  );
}

/**
 * fadeOutAndRollUpTransition is the props for a CSSTransition, to manage the
 * fade-out and height decrease when an Item or ItemZoneGroup is removed.
 *
 * Note that this _cannot_ be implemented as a wrapper component that returns a
 * CSSTransition. This is because the CSSTransition must be the direct child of
 * the TransitionGroup, and a wrapper breaks the parent-child relationship.
 *
 * See react-transition-group docs for more info!
 */
const fadeOutAndRollUpTransition = (css) => ({
  classNames: css`
    &-exit {
      opacity: 1;
      height: auto;
    }

    &-exit-active {
      opacity: 0;
      height: 0 !important;
      margin-top: 0 !important;
      margin-bottom: 0 !important;
      transition: all 0.5s;
    }
  `,
  timeout: 500,
  onExit: (e) => {
    e.style.height = e.offsetHeight + "px";
  },
});

export default ItemsPanel;
