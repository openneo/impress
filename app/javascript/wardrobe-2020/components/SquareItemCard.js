import React from "react";
import {
  Box,
  IconButton,
  Skeleton,
  useColorModeValue,
  useTheme,
  useToken,
} from "@chakra-ui/react";
import { ClassNames } from "@emotion/react";
import Link from "next/link";

import { safeImageUrl, useCommonStyles } from "../util";
import { CheckIcon, CloseIcon, StarIcon } from "@chakra-ui/icons";
import usePreferArchive from "./usePreferArchive";

function SquareItemCard({
  item,
  showRemoveButton = false,
  onRemove = () => {},
  tradeMatchingMode = null,
  footer = null,
  ...props
}) {
  const outlineShadowValue = useToken("shadows", "outline");
  const mdRadiusValue = useToken("radii", "md");

  const tradeMatchOwnShadowColor = useColorModeValue("green.500", "green.200");
  const tradeMatchWantShadowColor = useColorModeValue("blue.400", "blue.200");
  const [
    tradeMatchOwnShadowColorValue,
    tradeMatchWantShadowColorValue,
  ] = useToken("colors", [tradeMatchOwnShadowColor, tradeMatchWantShadowColor]);

  // When this is a trade match, give it an extra colorful shadow highlight so
  // it stands out! (They'll generally be sorted to the front anyway, but this
  // make it easier to scan a user's lists page, and to learn how the sorting
  // works!)
  let tradeMatchShadow;
  if (tradeMatchingMode === "offering" && item.currentUserWantsThis) {
    tradeMatchShadow = `0 0 6px ${tradeMatchWantShadowColorValue}`;
  } else if (tradeMatchingMode === "seeking" && item.currentUserOwnsThis) {
    tradeMatchShadow = `0 0 6px ${tradeMatchOwnShadowColorValue}`;
  } else {
    tradeMatchShadow = null;
  }

  return (
    <ClassNames>
      {({ css }) => (
        // SquareItemCard renders in large lists of 1k+ items, so we get a big
        // perf win by using Emotion directly instead of Chakra's styled-system
        // Box.
        <div
          className={css`
            position: relative;
            display: flex;
          `}
          role="group"
        >
          <Link href={`/items/${item.id}`} passHref>
            <Box
              as="a"
              className={css`
                border-radius: ${mdRadiusValue};
                transition: all 0.2s;
                &:hover,
                &:focus {
                  transform: scale(1.05);
                }
                &:focus {
                  box-shadow: ${outlineShadowValue};
                  outline: none;
                }
              `}
              {...props}
            >
              <SquareItemCardLayout
                name={item.name}
                thumbnailImage={
                  <ItemThumbnail
                    item={item}
                    tradeMatchingMode={tradeMatchingMode}
                  />
                }
                removeButton={
                  showRemoveButton ? (
                    <SquareItemCardRemoveButton onClick={onRemove} />
                  ) : null
                }
                boxShadow={tradeMatchShadow}
                footer={footer}
              />
            </Box>
          </Link>
          {showRemoveButton && (
            <div
              className={css`
                position: absolute;
                right: 0;
                top: 0;
                transform: translate(50%, -50%);
                z-index: 1;

                /* Apply some padding, so accidental clicks around the button
                 * don't click the link instead, or vice-versa! */
                padding: 0.75em;

                opacity: 0;
                [role="group"]:hover &,
                [role="group"]:focus-within &,
                &:hover,
                &:focus-within {
                  opacity: 1;
                }
              `}
            >
              <SquareItemCardRemoveButton onClick={onRemove} />
            </div>
          )}
        </div>
      )}
    </ClassNames>
  );
}

function SquareItemCardLayout({
  name,
  thumbnailImage,
  footer,
  minHeightNumLines = 2,
  boxShadow = null,
}) {
  const { brightBackground } = useCommonStyles();
  const brightBackgroundValue = useToken("colors", brightBackground);
  const theme = useTheme();

  return (
    // SquareItemCard renders in large lists of 1k+ items, so we get a big perf
    // win by using Emotion directly instead of Chakra's styled-system Box.
    <ClassNames>
      {({ css }) => (
        <div
          className={css`
            display: flex;
            flex-direction: column;
            align-items: center;
            text-align: center;
            box-shadow: ${boxShadow || theme.shadows.md};
            border-radius: ${theme.radii.md};
            padding: ${theme.space["3"]};
            width: calc(80px + 2em);
            background: ${brightBackgroundValue};
          `}
        >
          {thumbnailImage}
          <div
            className={css`
              margin-top: ${theme.space["1"]};
              font-size: ${theme.fontSizes.sm};
              /* Set min height to match a 2-line item name, so the cards
               * in a row aren't toooo differently sized... */
              min-height: ${minHeightNumLines * 1.5 + "em"};
              -webkit-line-clamp: 3;
              -webkit-box-orient: vertical;
              overflow: hidden;
              text-overflow: ellipsis;
              width: 100%;
            `}
            // HACK: Emotion turns this into -webkit-display: -webkit-box?
            style={{ display: "-webkit-box" }}
          >
            {name}
          </div>
          {footer && (
            <Box marginTop="2" width="100%">
              {footer}
            </Box>
          )}
        </div>
      )}
    </ClassNames>
  );
}

function ItemThumbnail({ item, tradeMatchingMode }) {
  const [preferArchive] = usePreferArchive();
  const kindColorScheme = item.isNc ? "purple" : item.isPb ? "orange" : "gray";

  const thumbnailShadowColor = useColorModeValue(
    `${kindColorScheme}.200`,
    `${kindColorScheme}.600`
  );
  const thumbnailShadowColorValue = useToken("colors", thumbnailShadowColor);
  const mdRadiusValue = useToken("radii", "md");

  // Normally, we just show the owns/wants badges depending on whether the
  // current user owns/wants it. But, in a trade list, we use trade-matching
  // mode instead: only show the badge if it represents a viable trade, and add
  // some extra flair to it, too!
  let showOwnsBadge;
  let showWantsBadge;
  let showTradeMatchFlair;
  if (tradeMatchingMode == null) {
    showOwnsBadge = item.currentUserOwnsThis;
    showWantsBadge = item.currentUserWantsThis;
    showTradeMatchFlair = false;
  } else if (tradeMatchingMode === "offering") {
    showOwnsBadge = false;
    showWantsBadge = item.currentUserWantsThis;
    showTradeMatchFlair = true;
  } else if (tradeMatchingMode === "seeking") {
    showOwnsBadge = item.currentUserOwnsThis;
    showWantsBadge = false;
    showTradeMatchFlair = true;
  } else if (tradeMatchingMode === "hide-all") {
    showOwnsBadge = false;
    showWantsBadge = false;
    showTradeMatchFlair = false;
  } else {
    throw new Error(`unexpected tradeMatchingMode ${tradeMatchingMode}`);
  }

  return (
    <ClassNames>
      {({ css }) => (
        <div
          className={css`
            position: relative;
          `}
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={safeImageUrl(item.thumbnailUrl, { preferArchive })}
            alt={`Thumbnail art for ${item.name}`}
            width={80}
            height={80}
            className={css`
              border-radius: ${mdRadiusValue};
              box-shadow: 0 0 4px ${thumbnailShadowColorValue};

              /* Don't let alt text flash in while loading */
              &:-moz-loading {
                visibility: hidden;
              }
            `}
            loading="lazy"
          />
          <div
            className={css`
              position: absolute;
              top: -6px;
              left: -6px;
              display: flex;
              flex-direction: column;
              gap: 2px;
            `}
          >
            {showOwnsBadge && (
              <ItemOwnsWantsBadge
                colorScheme="green"
                label={
                  showTradeMatchFlair
                    ? "You own this, and they want it!"
                    : "You own this"
                }
              >
                <CheckIcon />
                {showTradeMatchFlair && (
                  <div
                    className={css`
                      margin-left: 0.25em;
                      margin-right: 0.125rem;
                    `}
                  >
                    Match
                  </div>
                )}
              </ItemOwnsWantsBadge>
            )}
            {showWantsBadge && (
              <ItemOwnsWantsBadge
                colorScheme="blue"
                label={
                  showTradeMatchFlair
                    ? "You want this, and they own it!"
                    : "You want this"
                }
              >
                <StarIcon />
                {showTradeMatchFlair && (
                  <div
                    className={css`
                      margin-left: 0.25em;
                      margin-right: 0.125rem;
                    `}
                  >
                    Match
                  </div>
                )}
              </ItemOwnsWantsBadge>
            )}
          </div>
          {item.isNc != null && (
            <div
              className={css`
                position: absolute;
                bottom: -6px;
                right: -3px;
              `}
            >
              <ItemThumbnailKindBadge colorScheme={kindColorScheme}>
                {item.isNc ? "NC" : item.isPb ? "PB" : "NP"}
              </ItemThumbnailKindBadge>
            </div>
          )}
        </div>
      )}
    </ClassNames>
  );
}

function ItemOwnsWantsBadge({ colorScheme, children, label }) {
  const badgeBackground = useColorModeValue(
    `${colorScheme}.100`,
    `${colorScheme}.500`
  );
  const badgeColor = useColorModeValue(
    `${colorScheme}.500`,
    `${colorScheme}.100`
  );

  const [badgeBackgroundValue, badgeColorValue] = useToken("colors", [
    badgeBackground,
    badgeColor,
  ]);

  return (
    <ClassNames>
      {({ css }) => (
        <div
          aria-label={label}
          title={label}
          className={css`
            border-radius: 999px;
            height: 16px;
            min-width: 16px;
            font-size: 14px;
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 0 2px ${badgeBackgroundValue};
            /* Decrease the padding: I don't want to hit the edges, but I want
             * to be a circle when possible! */
            padding-left: 0.125rem;
            padding-right: 0.125rem;
            /* Copied from Chakra <Badge> */
            white-space: nowrap;
            vertical-align: middle;
            text-transform: uppercase;
            font-size: 0.65rem;
            font-weight: 700;
            background: ${badgeBackgroundValue};
            color: ${badgeColorValue};
          `}
        >
          {children}
        </div>
      )}
    </ClassNames>
  );
}

function ItemThumbnailKindBadge({ colorScheme, children }) {
  const badgeBackground = useColorModeValue(
    `${colorScheme}.100`,
    `${colorScheme}.500`
  );
  const badgeColor = useColorModeValue(
    `${colorScheme}.500`,
    `${colorScheme}.100`
  );

  const [badgeBackgroundValue, badgeColorValue] = useToken("colors", [
    badgeBackground,
    badgeColor,
  ]);

  return (
    <ClassNames>
      {({ css }) => (
        <div
          className={css`
            /* Copied from Chakra <Badge> */
            white-space: nowrap;
            vertical-align: middle;
            padding-left: 0.25rem;
            padding-right: 0.25rem;
            text-transform: uppercase;
            font-size: 0.65rem;
            border-radius: 0.125rem;
            font-weight: 700;
            background: ${badgeBackgroundValue};
            color: ${badgeColorValue};
          `}
        >
          {children}
        </div>
      )}
    </ClassNames>
  );
}

function SquareItemCardRemoveButton({ onClick }) {
  const backgroundColor = useColorModeValue("gray.200", "gray.500");

  return (
    <IconButton
      aria-label="Remove"
      title="Remove"
      icon={<CloseIcon />}
      size="xs"
      borderRadius="full"
      boxShadow="lg"
      backgroundColor={backgroundColor}
      onClick={onClick}
      _hover={{
        // Override night mode's fade-out on hover
        opacity: 1,
        transform: "scale(1.15, 1.15)",
      }}
      _focus={{
        transform: "scale(1.15, 1.15)",
        boxShadow: "outline",
      }}
    />
  );
}

export function SquareItemCardSkeleton({ minHeightNumLines, footer = null }) {
  return (
    <SquareItemCardLayout
      name={
        <>
          <Skeleton width="100%" height="1em" marginTop="2" />
          {minHeightNumLines >= 3 && (
            <Skeleton width="100%" height="1em" marginTop="2" />
          )}
        </>
      }
      thumbnailImage={<Skeleton width="80px" height="80px" />}
      minHeightNumLines={minHeightNumLines}
      footer={footer}
    />
  );
}

export default SquareItemCard;
