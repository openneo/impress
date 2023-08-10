import React from "react";
import { ClassNames } from "@emotion/react";
import {
  Box,
  Flex,
  IconButton,
  Skeleton,
  Tooltip,
  useColorModeValue,
  useTheme,
} from "@chakra-ui/react";
import { EditIcon, DeleteIcon, InfoIcon } from "@chakra-ui/icons";
import Link from "next/link";
import { loadable } from "../util";

import {
  ItemCardContent,
  ItemBadgeList,
  ItemKindBadge,
  MaybeAnimatedBadge,
  YouOwnThisBadge,
  YouWantThisBadge,
  getZoneBadges,
} from "../components/ItemCard";
import SupportOnly from "./support/SupportOnly";
import useSupport from "./support/useSupport";

const LoadableItemPageDrawer = loadable(() => import("../ItemPageDrawer"));
const LoadableItemSupportDrawer = loadable(() =>
  import("./support/ItemSupportDrawer")
);

/**
 * Item show a basic summary of an item, in the context of the current outfit!
 *
 * It also responds to the focus state of an `input` as its previous sibling.
 * This will be an invisible radio/checkbox that controls the actual wear
 * state.
 *
 * In fact, this component can't trigger wear or unwear events! When you click
 * it in the app, you're actually clicking a <label> that wraps the radio or
 * checkbox. Similarly, the parent provides the `onRemove` callback for the
 * Remove button.
 *
 * NOTE: This component is memoized with React.memo. It's surpisingly expensive
 *       to re-render, because Chakra components are a lil bit expensive from
 *       their internal complexity, and we have a lot of them here. And it can
 *       add up when there's a lot of Items in the list. This contributes to
 *       wearing/unwearing items being noticeably slower on lower-power
 *       devices.
 */
function Item({
  item,
  itemNameId,
  isWorn,
  isInOutfit,
  onRemove,
  isDisabled = false,
}) {
  const [infoDrawerIsOpen, setInfoDrawerIsOpen] = React.useState(false);
  const [supportDrawerIsOpen, setSupportDrawerIsOpen] = React.useState(false);

  return (
    <>
      <ItemContainer isDisabled={isDisabled}>
        <Box flex="1 1 0" minWidth="0">
          <ItemCardContent
            item={item}
            badges={<ItemBadges item={item} />}
            itemNameId={itemNameId}
            isWorn={isWorn}
            isDiabled={isDisabled}
            focusSelector={containerHasFocus}
          />
        </Box>
        <Box flex="0 0 auto" marginTop="5px">
          {isInOutfit && (
            <ItemActionButton
              icon={<DeleteIcon />}
              label="Remove"
              onClick={(e) => {
                onRemove(item.id);
                e.preventDefault();
              }}
            />
          )}
          <SupportOnly>
            <ItemActionButton
              icon={<EditIcon />}
              label="Support"
              onClick={(e) => {
                setSupportDrawerIsOpen(true);
                e.preventDefault();
              }}
            />
          </SupportOnly>
          <ItemActionButton
            icon={<InfoIcon />}
            label="More info"
            to={`/items/${item.id}`}
            onClick={(e) => {
              const willProbablyOpenInNewTab =
                e.metaKey || e.shiftKey || e.altKey || e.ctrlKey;
              if (willProbablyOpenInNewTab) {
                return;
              }

              setInfoDrawerIsOpen(true);
              e.preventDefault();
            }}
          />
        </Box>
      </ItemContainer>
      <LoadableItemPageDrawer
        item={item}
        isOpen={infoDrawerIsOpen}
        onClose={() => setInfoDrawerIsOpen(false)}
      />
      <SupportOnly>
        <LoadableItemSupportDrawer
          item={item}
          isOpen={supportDrawerIsOpen}
          onClose={() => setSupportDrawerIsOpen(false)}
        />
      </SupportOnly>
    </>
  );
}

/**
 * ItemSkeleton is a placeholder for when an Item is loading.
 */
function ItemSkeleton() {
  return (
    <ItemContainer isDisabled>
      <Skeleton width="50px" height="50px" />
      <Box width="3" />
      <Skeleton height="1.5rem" width="12rem" alignSelf="center" />
    </ItemContainer>
  );
}

/**
 * ItemContainer is the outermost element of an `Item`.
 *
 * It provides spacing, but also is responsible for a number of hover/focus/etc
 * styles - including for its children, who sometimes reference it as an
 * .item-container parent!
 */
function ItemContainer({ children, isDisabled = false }) {
  const theme = useTheme();

  const focusBackgroundColor = useColorModeValue(
    theme.colors.gray["100"],
    theme.colors.gray["700"]
  );

  const activeBorderColor = useColorModeValue(
    theme.colors.green["400"],
    theme.colors.green["500"]
  );

  const focusCheckedBorderColor = useColorModeValue(
    theme.colors.green["800"],
    theme.colors.green["300"]
  );

  return (
    <ClassNames>
      {({ css, cx }) => (
        <Box
          p="1"
          my="1"
          borderRadius="lg"
          d="flex"
          cursor={isDisabled ? undefined : "pointer"}
          border="1px"
          borderColor="transparent"
          className={cx([
            "item-container",
            !isDisabled &&
              css`
                &:hover,
                input:focus + & {
                  background-color: ${focusBackgroundColor};
                }

                input:active + & {
                  border-color: ${activeBorderColor};
                }

                input:checked:focus + & {
                  border-color: ${focusCheckedBorderColor};
                }
              `,
          ])}
        >
          {children}
        </Box>
      )}
    </ClassNames>
  );
}

function ItemBadges({ item }) {
  const { isSupportUser } = useSupport();
  const occupiedZones = item.appearanceOn.layers.map((l) => l.zone);
  const restrictedZones = item.appearanceOn.restrictedZones.filter(
    (z) => z.isCommonlyUsedByItems
  );
  const isMaybeAnimated = item.appearanceOn.layers.some(
    (l) => l.canvasMovieLibraryUrl
  );

  return (
    <ItemBadgeList>
      <ItemKindBadge isNc={item.isNc} isPb={item.isPb} />
      {
        // This badge is unreliable, but it's helpful for looking for animated
        // items to test, so we show it only to support. We use this form
        // instead of <SupportOnly />, to avoid adding extra badge list spacing
        // on the additional empty child.
        isMaybeAnimated && isSupportUser && <MaybeAnimatedBadge />
      }
      {getZoneBadges(occupiedZones, { variant: "occupies" })}
      {getZoneBadges(restrictedZones, { variant: "restricts" })}
      {item.currentUserOwnsThis && <YouOwnThisBadge variant="medium" />}
      {item.currentUserWantsThis && <YouWantThisBadge variant="medium" />}
    </ItemBadgeList>
  );
}

/**
 * ItemActionButton is one of a list of actions a user can take for this item.
 */
function ItemActionButton({ icon, label, to, onClick }) {
  const theme = useTheme();

  const focusBackgroundColor = useColorModeValue(
    theme.colors.gray["300"],
    theme.colors.gray["800"]
  );
  const focusColor = useColorModeValue(
    theme.colors.gray["700"],
    theme.colors.gray["200"]
  );

  return (
    <ClassNames>
      {({ css }) => (
        <Tooltip label={label} placement="top">
          <LinkOrButton
            component={IconButton}
            href={to}
            icon={icon}
            aria-label={label}
            variant="ghost"
            color="gray.400"
            onClick={onClick}
            className={css`
              opacity: 0;
              transition: all 0.2s;

              ${containerHasFocus} {
                opacity: 1;
              }

              &:focus,
              &:hover {
                opacity: 1;
                background-color: ${focusBackgroundColor};
                color: ${focusColor};
              }

              /* On touch devices, always show the buttons! This avoids having to
           * tap to reveal them (which toggles the item), or worse,
           * accidentally tapping a hidden button without realizing! */
              @media (hover: none) {
                opacity: 1;
              }
            `}
          />
        </Tooltip>
      )}
    </ClassNames>
  );
}

function LinkOrButton({ href, component = Button, ...props }) {
  const ButtonComponent = component;
  if (href != null) {
    return (
      <Link href={href} passHref>
        <ButtonComponent as="a" {...props} />
      </Link>
    );
  } else {
    return <ButtonComponent {...props} />;
  }
}

/**
 * ItemListContainer is a container for Item components! Wrap your Item
 * components in this to ensure a consistent list layout.
 */
export function ItemListContainer({ children, ...props }) {
  return (
    <Flex direction="column" {...props}>
      {children}
    </Flex>
  );
}

/**
 * ItemListSkeleton is a placeholder for when an ItemListContainer and its
 * Items are loading.
 */
export function ItemListSkeleton({ count, ...props }) {
  return (
    <ItemListContainer {...props}>
      {Array.from({ length: count }).map((_, i) => (
        <ItemSkeleton key={i} />
      ))}
    </ItemListContainer>
  );
}

/**
 * containerHasFocus is a common CSS selector, for the case where our parent
 * .item-container is hovered or the adjacent hidden radio/checkbox is
 * focused.
 */
const containerHasFocus =
  ".item-container:hover &, input:focus + .item-container &";

export default React.memo(Item);
