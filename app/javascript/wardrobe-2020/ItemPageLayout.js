import React from "react";
import {
  Badge,
  Box,
  Flex,
  Popover,
  PopoverArrow,
  PopoverContent,
  PopoverTrigger,
  Portal,
  Select,
  Skeleton,
  Spinner,
  Tooltip,
  useToast,
  VStack,
} from "@chakra-ui/react";
import { ExternalLinkIcon, ChevronRightIcon } from "@chakra-ui/icons";
import { gql, useMutation } from "@apollo/client";

import {
  ItemBadgeList,
  ItemKindBadge,
  ItemThumbnail,
} from "./components/ItemCard";
import { Heading1 } from "./util";

import useSupport from "./WardrobePage/support/useSupport";

function ItemPageLayout({ children, item, isEmbedded }) {
  return (
    <Box>
      <ItemPageHeader item={item} isEmbedded={isEmbedded} />
      <Box>{children}</Box>
    </Box>
  );
}

function ItemPageHeader({ item, isEmbedded }) {
  return (
    <Box
      display="flex"
      alignItems="center"
      justifyContent="flex-start"
      width="100%"
    >
      <SubtleSkeleton isLoaded={item?.thumbnailUrl} marginRight="4">
        <ItemThumbnail item={item} size="lg" isActive flex="0 0 auto" />
      </SubtleSkeleton>
      <Box>
        <SubtleSkeleton isLoaded={item?.name}>
          <Heading1
            lineHeight="1.1"
            // Nudge down the size a bit in the embed case, to better fit the
            // tighter layout!
            size={isEmbedded ? "xl" : "2xl"}
          >
            {item?.name || "Item name here"}
          </Heading1>
        </SubtleSkeleton>
        <ItemPageBadges item={item} isEmbedded={isEmbedded} />
      </Box>
    </Box>
  );
}

/**
 * SubtleSkeleton hides the skeleton animation until a second has passed, and
 * doesn't fade in the content if it loads near-instantly. This helps avoid
 * flash-of-content stuff!
 *
 * For plain Skeletons, we often use <Delay><Skeleton /></Delay> instead. But
 * that pattern doesn't work as well for wrapper skeletons where we're using
 * placeholder content for layout: we don't want the delay if the content
 * really _is_ present!
 */
export function SubtleSkeleton({ isLoaded, ...props }) {
  const [shouldFadeIn, setShouldFadeIn] = React.useState(false);
  const [shouldShowSkeleton, setShouldShowSkeleton] = React.useState(false);

  React.useEffect(() => {
    const t = setTimeout(() => {
      if (!isLoaded) {
        setShouldFadeIn(true);
      }
    }, 150);
    return () => clearTimeout(t);
  });

  React.useEffect(() => {
    const t = setTimeout(() => setShouldShowSkeleton(true), 500);
    return () => clearTimeout(t);
  });

  return (
    <Skeleton
      fadeDuration={shouldFadeIn ? undefined : 0}
      startColor={shouldShowSkeleton ? undefined : "transparent"}
      endColor={shouldShowSkeleton ? undefined : "transparent"}
      isLoaded={isLoaded}
      {...props}
    />
  );
}

function ItemPageBadges({ item, isEmbedded }) {
  const searchBadgesAreLoaded = item?.name != null && item?.isNc != null;

  return (
    <ItemBadgeList marginTop="1">
      <SubtleSkeleton isLoaded={item?.isNc != null}>
        <ItemKindBadgeWithSupportTools item={item} />
      </SubtleSkeleton>
      {
        // If the createdAt date is null (loaded and empty), hide the badge.
        item?.createdAt !== null && (
          <SubtleSkeleton
            // Distinguish between undefined (still loading) and null (loaded and
            // empty).
            isLoaded={item?.createdAt !== undefined}
          >
            <Badge
              display="block"
              minWidth="5.25em"
              boxSizing="content-box"
              textAlign="center"
            >
              {item?.createdAt && <ShortTimestamp when={item?.createdAt} />}
            </Badge>
          </SubtleSkeleton>
        )
      }
      <SubtleSkeleton isLoaded={searchBadgesAreLoaded}>
        <LinkBadge
          href={`https://impress.openneo.net/items/${item?.id}`}
          isEmbedded={isEmbedded}
        >
          Classic DTI
        </LinkBadge>
      </SubtleSkeleton>
      <SubtleSkeleton isLoaded={searchBadgesAreLoaded}>
        <LinkBadge
          href={
            "https://items.jellyneo.net/search/?name=" +
            encodeURIComponent(item?.name) +
            "&name_type=3"
          }
          isEmbedded={isEmbedded}
        >
          Jellyneo
        </LinkBadge>
      </SubtleSkeleton>
      {item?.isNc && (
        <SubtleSkeleton
          isLoaded={
            // Distinguish between undefined (still loading) and null (loaded
            // and empty).
            item?.ncTradeValueText !== undefined
          }
        >
          {item?.ncTradeValueText && (
            <LinkBadge href="http://www.neopets.com/~owls">
              OWLS: {item?.ncTradeValueText}
            </LinkBadge>
          )}
        </SubtleSkeleton>
      )}
      <SubtleSkeleton isLoaded={searchBadgesAreLoaded}>
        {!item?.isNc && !item?.isPb && (
          <LinkBadge
            href={
              "http://www.neopets.com/shops/wizard.phtml?string=" +
              encodeURIComponent(item?.name)
            }
            isEmbedded={isEmbedded}
          >
            Shop Wiz
          </LinkBadge>
        )}
      </SubtleSkeleton>
      <SubtleSkeleton isLoaded={searchBadgesAreLoaded}>
        {!item?.isNc && !item?.isPb && (
          <LinkBadge
            href={
              "http://www.neopets.com/portal/supershopwiz.phtml?string=" +
              encodeURIComponent(item?.name)
            }
            isEmbedded={isEmbedded}
          >
            Super Wiz
          </LinkBadge>
        )}
      </SubtleSkeleton>
      <SubtleSkeleton isLoaded={searchBadgesAreLoaded}>
        {!item?.isNc && !item?.isPb && (
          <LinkBadge
            href={
              "http://www.neopets.com/island/tradingpost.phtml?type=browse&criteria=item_exact&search_string=" +
              encodeURIComponent(item?.name)
            }
            isEmbedded={isEmbedded}
          >
            Trade Post
          </LinkBadge>
        )}
      </SubtleSkeleton>
      <SubtleSkeleton isLoaded={searchBadgesAreLoaded}>
        {!item?.isNc && !item?.isPb && (
          <LinkBadge
            href={
              "http://www.neopets.com/genie.phtml?type=process_genie&criteria=exact&auctiongenie=" +
              encodeURIComponent(item?.name)
            }
            isEmbedded={isEmbedded}
          >
            Auctions
          </LinkBadge>
        )}
      </SubtleSkeleton>
    </ItemBadgeList>
  );
}

function ItemKindBadgeWithSupportTools({ item }) {
  const { isSupportUser, supportSecret } = useSupport();
  const toast = useToast();

  const ncRef = React.useRef(null);

  const isNcAutoDetectedFromRarity =
    item?.rarityIndex === 500 || item?.rarityIndex === 0;

  const [mutate, { loading }] = useMutation(gql`
    mutation ItemPageSupportSetIsManuallyNc(
      $itemId: ID!
      $isManuallyNc: Boolean!
      $supportSecret: String!
    ) {
      setItemIsManuallyNc(
        itemId: $itemId
        isManuallyNc: $isManuallyNc
        supportSecret: $supportSecret
      ) {
        id
        isNc
        isManuallyNc
      }
    }
  `);

  if (
    isSupportUser &&
    item?.rarityIndex != null &&
    item?.isManuallyNc != null
  ) {
    // TODO: Could code-split this into a SupportOnly file...
    return (
      <Popover placement="bottom-start" initialFocusRef={ncRef} showArrow>
        <PopoverTrigger>
          <ItemKindBadge isNc={item.isNc} isPb={item.isPb} isEditButton />
        </PopoverTrigger>
        <Portal>
          <PopoverContent padding="4">
            <PopoverArrow />
            <VStack spacing="2" align="flex-start">
              <Flex align="center">
                <Box as="span" fontWeight="600" marginRight="2">
                  NC:
                </Box>
                <Select
                  ref={ncRef}
                  size="xs"
                  value={item.isManuallyNc ? "true" : "false"}
                  onChange={(e) => {
                    const isManuallyNc = e.target.value === "true";
                    mutate({
                      variables: {
                        itemId: item.id,
                        isManuallyNc,
                        supportSecret,
                      },
                      optimisticResponse: {
                        setItemIsManuallyNc: {
                          __typename: "Item",
                          id: item.id,
                          isNc: isManuallyNc || isNcAutoDetectedFromRarity,
                          isManuallyNc,
                        },
                      },
                    }).catch((e) => {
                      console.error(e);
                      toast({
                        status: "error",
                        title:
                          "Could not set NC status for this item. Try again?",
                      });
                    });
                  }}
                >
                  <option value="false">
                    Auto-detect: {isNcAutoDetectedFromRarity ? "Yes" : "No"}.{" "}
                    (Rarity {item.rarityIndex})
                  </option>
                  <option value="true">Manually set: Yes.</option>
                </Select>
                {loading && <Spinner size="sm" marginLeft="2" />}
              </Flex>
              <Flex align="center">
                <Box as="span" fontWeight="600" marginRight="1">
                  PB:
                </Box>
                <Select size="xs" isReadOnly value="auto-detect">
                  <option value="auto-detect">
                    Auto-detect: {item.isPb ? "Yes" : "No"}. (from description)
                  </option>
                  <option style={{ fontStyle: "italic" }}>
                    (This cannot be manually set.)
                  </option>
                </Select>
              </Flex>
              <Badge
                colorScheme="pink"
                alignSelf="flex-end"
                marginBottom="-2"
                marginRight="-2"
              >
                Support <span aria-hidden="true">💖</span>
              </Badge>
            </VStack>
          </PopoverContent>
        </Portal>
      </Popover>
    );
  }

  return <ItemKindBadge isNc={item?.isNc} isPb={item?.isPb} />;
}

const LinkBadge = React.forwardRef(
  ({ children, href, isEmbedded, ...props }, ref) => {
    return (
      <Badge
        ref={ref}
        as="a"
        href={href}
        display="flex"
        alignItems="center"
        // Normally we want to act like a normal webpage, and treat links as
        // normal. But when we're on the wardrobe page, we want to avoid
        // disrupting the outfit, and open in a new window instead.
        target={isEmbedded ? "_blank" : undefined}
        _focus={{ outline: "none", boxShadow: "outline" }}
        {...props}
      >
        {children}
        {
          // We also change the icon to signal whether this will launch in a new
          // window or not!
          isEmbedded ? (
            <ExternalLinkIcon marginLeft="1" />
          ) : (
            <ChevronRightIcon />
          )
        }
      </Badge>
    );
  }
);

const fullDateFormatter = new Intl.DateTimeFormat("en-US", {
  dateStyle: "long",
});
const monthYearFormatter = new Intl.DateTimeFormat("en-US", {
  month: "short",
  year: "numeric",
});
const monthDayYearFormatter = new Intl.DateTimeFormat("en-US", {
  month: "short",
  day: "numeric",
  year: "numeric",
});
function ShortTimestamp({ when }) {
  const date = new Date(when);

  // To find the start of last month, take today, then set its date to the 1st
  // and its time to midnight (the start of this month), and subtract one
  // month. (JS handles negative months and rolls them over correctly.)
  const startOfLastMonth = new Date();
  startOfLastMonth.setDate(1);
  startOfLastMonth.setHours(0);
  startOfLastMonth.setMinutes(0);
  startOfLastMonth.setSeconds(0);
  startOfLastMonth.setMilliseconds(0);
  startOfLastMonth.setMonth(startOfLastMonth.getMonth() - 1);

  const dateIsOlderThanLastMonth = date < startOfLastMonth;

  return (
    <Tooltip
      label={`First seen on ${fullDateFormatter.format(date)}`}
      placement="top"
      openDelay={400}
    >
      {dateIsOlderThanLastMonth
        ? monthYearFormatter.format(date)
        : monthDayYearFormatter.format(date)}
    </Tooltip>
  );
}

export default ItemPageLayout;
