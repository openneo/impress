import React from "react";
import { ClassNames } from "@emotion/react";
import {
  Badge,
  Box,
  SimpleGrid,
  Tooltip,
  Wrap,
  WrapItem,
  useColorModeValue,
  useTheme,
} from "@chakra-ui/react";
import {
  CheckIcon,
  EditIcon,
  NotAllowedIcon,
  StarIcon,
} from "@chakra-ui/icons";
import { HiSparkles } from "react-icons/hi";
import Link from "next/link";

import SquareItemCard from "./SquareItemCard";
import { safeImageUrl, useCommonStyles } from "../util";
import usePreferArchive from "./usePreferArchive";

function ItemCard({ item, badges, variant = "list", ...props }) {
  const { brightBackground } = useCommonStyles();

  switch (variant) {
    case "grid":
      return <SquareItemCard item={item} {...props} />;
    case "list":
      return (
        <Link href={`/items/${item.id}`} passHref>
          <Box
            as="a"
            display="block"
            p="2"
            boxShadow="lg"
            borderRadius="lg"
            background={brightBackground}
            transition="all 0.2s"
            className="item-card"
            width="100%"
            minWidth="0"
            {...props}
          >
            <ItemCardContent
              item={item}
              badges={badges}
              focusSelector=".item-card:hover &, .item-card:focus &"
            />
          </Box>
        </Link>
      );
    default:
      throw new Error(`Unexpected ItemCard variant: ${variant}`);
  }
}

export function ItemCardContent({
  item,
  badges,
  isWorn,
  isDisabled,
  itemNameId,
  focusSelector,
}) {
  return (
    <Box display="flex">
      <Box>
        <Box flex="0 0 auto" marginRight="3">
          <ItemThumbnail
            item={item}
            isActive={isWorn}
            isDisabled={isDisabled}
            focusSelector={focusSelector}
          />
        </Box>
      </Box>
      <Box flex="1 1 0" minWidth="0" marginTop="1px">
        <ItemName
          id={itemNameId}
          isWorn={isWorn}
          isDisabled={isDisabled}
          focusSelector={focusSelector}
        >
          {item.name}
        </ItemName>

        {badges}
      </Box>
    </Box>
  );
}

/**
 * ItemThumbnail shows a small preview image for the item, including some
 * hover/focus and worn/unworn states.
 */
export function ItemThumbnail({
  item,
  size = "md",
  isActive,
  isDisabled,
  focusSelector,
  ...props
}) {
  const [preferArchive] = usePreferArchive();
  const theme = useTheme();

  const borderColor = useColorModeValue(
    theme.colors.green["700"],
    "transparent"
  );

  const focusBorderColor = useColorModeValue(
    theme.colors.green["600"],
    "transparent"
  );

  return (
    <ClassNames>
      {({ css }) => (
        <Box
          width={size === "lg" ? "80px" : "50px"}
          height={size === "lg" ? "80px" : "50px"}
          transition="all 0.15s"
          transformOrigin="center"
          position="relative"
          className={css([
            {
              transform: "scale(0.8)",
            },
            !isDisabled &&
              !isActive && {
                [focusSelector]: {
                  opacity: "0.9",
                  transform: "scale(0.9)",
                },
              },
            !isDisabled &&
              isActive && {
                opacity: 1,
                transform: "none",
              },
          ])}
          {...props}
        >
          <Box
            borderRadius="lg"
            boxShadow="md"
            border="1px"
            overflow="hidden"
            width="100%"
            height="100%"
            className={css([
              {
                borderColor: `${borderColor} !important`,
              },
              !isDisabled &&
                !isActive && {
                  [focusSelector]: {
                    borderColor: `${focusBorderColor} !important`,
                  },
                },
            ])}
          >
            {/* If the item is still loading, wait with an empty box. */}
            {item && (
              <Box
                as="img"
                width="100%"
                height="100%"
                src={safeImageUrl(item.thumbnailUrl, { preferArchive })}
                alt={`Thumbnail art for ${item.name}`}
              />
            )}
          </Box>
        </Box>
      )}
    </ClassNames>
  );
}

/**
 * ItemName shows the item's name, including some hover/focus and worn/unworn
 * states.
 */
function ItemName({ children, isDisabled, focusSelector, ...props }) {
  const theme = useTheme();

  return (
    <ClassNames>
      {({ css }) => (
        <Box
          fontSize="md"
          transition="all 0.15s"
          overflow="hidden"
          whiteSpace="nowrap"
          textOverflow="ellipsis"
          className={
            !isDisabled &&
            css`
              ${focusSelector} {
                opacity: 0.9;
                font-weight: ${theme.fontWeights.medium};
              }

              input:checked + .item-container & {
                opacity: 1;
                font-weight: ${theme.fontWeights.bold};
              }
            `
          }
          {...props}
        >
          {children}
        </Box>
      )}
    </ClassNames>
  );
}

export function ItemCardList({ children }) {
  return (
    <SimpleGrid columns={{ sm: 1, md: 2, lg: 3 }} spacing="6">
      {children}
    </SimpleGrid>
  );
}

export function ItemBadgeList({ children, ...props }) {
  return (
    <Wrap spacing="2" opacity="0.7" {...props}>
      {React.Children.map(
        children,
        (badge) => badge && <WrapItem>{badge}</WrapItem>
      )}
    </Wrap>
  );
}

export function ItemBadgeTooltip({ label, children }) {
  return (
    <Tooltip
      label={<Box textAlign="center">{label}</Box>}
      placement="top"
      openDelay={400}
    >
      {children}
    </Tooltip>
  );
}

export const NcBadge = React.forwardRef(({ isEditButton, ...props }, ref) => {
  return (
    <ItemBadgeTooltip label="Neocash">
      <Badge
        ref={ref}
        as={isEditButton ? "button" : "span"}
        colorScheme="purple"
        display="flex"
        alignItems="center"
        _focus={{ outline: "none", boxShadow: "outline" }}
        {...props}
      >
        NC
        {isEditButton && <EditIcon fontSize="0.85em" marginLeft="1" />}
      </Badge>
    </ItemBadgeTooltip>
  );
});

export const NpBadge = React.forwardRef(({ isEditButton, ...props }, ref) => {
  return (
    <ItemBadgeTooltip label="Neopoints">
      <Badge
        ref={ref}
        as={isEditButton ? "button" : "span"}
        display="flex"
        alignItems="center"
        _focus={{ outline: "none", boxShadow: "outline" }}
        {...props}
      >
        NP
        {isEditButton && <EditIcon fontSize="0.85em" marginLeft="1" />}
      </Badge>
    </ItemBadgeTooltip>
  );
});

export const PbBadge = React.forwardRef(({ isEditButton, ...props }, ref) => {
  return (
    <ItemBadgeTooltip label="This item is only obtainable via paintbrush">
      <Badge
        ref={ref}
        as={isEditButton ? "button" : "span"}
        colorScheme="orange"
        display="flex"
        alignItems="center"
        _focus={{ outline: "none", boxShadow: "outline" }}
        {...props}
      >
        PB
        {isEditButton && <EditIcon fontSize="0.85em" marginLeft="1" />}
      </Badge>
    </ItemBadgeTooltip>
  );
});

export const ItemKindBadge = React.forwardRef(
  ({ isNc, isPb, isEditButton, ...props }, ref) => {
    if (isNc) {
      return <NcBadge ref={ref} isEditButton={isEditButton} {...props} />;
    } else if (isPb) {
      return <PbBadge ref={ref} isEditButton={isEditButton} {...props} />;
    } else {
      return <NpBadge ref={ref} isEditButton={isEditButton} {...props} />;
    }
  }
);

export function YouOwnThisBadge({ variant = "long" }) {
  let badge = (
    <Badge
      colorScheme="green"
      display="flex"
      alignItems="center"
      minHeight="1.5em"
    >
      <CheckIcon aria-label="Check" />
      {variant === "medium" && <Box marginLeft="1">Own</Box>}
      {variant === "long" && <Box marginLeft="1">You own this!</Box>}
    </Badge>
  );

  if (variant === "short" || variant === "medium") {
    badge = (
      <ItemBadgeTooltip label="You own this item">{badge}</ItemBadgeTooltip>
    );
  }

  return badge;
}

export function YouWantThisBadge({ variant = "long" }) {
  let badge = (
    <Badge
      colorScheme="blue"
      display="flex"
      alignItems="center"
      minHeight="1.5em"
    >
      <StarIcon aria-label="Star" />
      {variant === "medium" && <Box marginLeft="1">Want</Box>}
      {variant === "long" && <Box marginLeft="1">You want this!</Box>}
    </Badge>
  );

  if (variant === "short" || variant === "medium") {
    badge = (
      <ItemBadgeTooltip label="You want this item">{badge}</ItemBadgeTooltip>
    );
  }

  return badge;
}

function ZoneBadge({ variant, zoneLabel }) {
  // Shorten the label when necessary, to make the badges less bulky
  const shorthand = zoneLabel
    .replace("Background Item", "BG Item")
    .replace("Foreground Item", "FG Item")
    .replace("Lower-body", "Lower")
    .replace("Upper-body", "Upper")
    .replace("Transient", "Trans")
    .replace("Biology", "Bio");

  if (variant === "restricts") {
    return (
      <ItemBadgeTooltip
        label={`Restricted: This item can't be worn with ${zoneLabel} items`}
      >
        <Badge>
          <Box display="flex" alignItems="center">
            {shorthand} <NotAllowedIcon marginLeft="1" />
          </Box>
        </Badge>
      </ItemBadgeTooltip>
    );
  }

  if (shorthand !== zoneLabel) {
    return (
      <ItemBadgeTooltip label={zoneLabel}>
        <Badge>{shorthand}</Badge>
      </ItemBadgeTooltip>
    );
  }

  return <Badge>{shorthand}</Badge>;
}

export function getZoneBadges(zones, propsForAllBadges) {
  // Get the sorted zone labels. Sometimes an item occupies multiple zones of
  // the same name, so it's important to de-duplicate them!
  let labels = zones.map((z) => z.label);
  labels = new Set(labels);
  labels = [...labels].sort();

  return labels.map((label) => (
    <ZoneBadge key={label} zoneLabel={label} {...propsForAllBadges} />
  ));
}

export function MaybeAnimatedBadge() {
  return (
    <ItemBadgeTooltip label="Maybe animated? (Support only)">
      <Badge
        colorScheme="orange"
        display="flex"
        alignItems="center"
        minHeight="1.5em"
      >
        <Box as={HiSparkles} aria-label="Sparkles" />
      </Badge>
    </ItemBadgeTooltip>
  );
}

export default ItemCard;
