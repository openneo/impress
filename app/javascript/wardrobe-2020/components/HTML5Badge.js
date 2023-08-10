import React from "react";
import { Tooltip, useColorModeValue, Flex, Icon } from "@chakra-ui/react";
import { CheckCircleIcon, WarningTwoIcon } from "@chakra-ui/icons";

function HTML5Badge({ usesHTML5, isLoading, tooltipLabel }) {
  // `delayedUsesHTML5` stores the last known value of `usesHTML5`, when
  // `isLoading` was `false`. This enables us to keep showing the badge, even
  // when loading a new appearance - because it's unlikely the badge will
  // change between different appearances for the same item, and the flicker is
  // annoying!
  const [delayedUsesHTML5, setDelayedUsesHTML5] = React.useState(null);
  React.useEffect(() => {
    if (!isLoading) {
      setDelayedUsesHTML5(usesHTML5);
    }
  }, [usesHTML5, isLoading]);

  if (delayedUsesHTML5 === true) {
    return (
      <GlitchBadgeLayout
        hasGlitches={false}
        aria-label="HTML5 supported!"
        tooltipLabel={
          tooltipLabel ||
          "This item is converted to HTML5, and ready to use on Neopets.com!"
        }
      >
        <CheckCircleIcon fontSize="xs" />
        <Icon
          viewBox="0 0 36 36"
          fontSize="xl"
          // Visual re-balancing, there's too much visual right-padding here!
          marginRight="-1"
        >
          {/* From Twemoji Keycap 5 */}
          <path
            fill="currentColor"
            d="M16.389 14.489c.744-.155 1.551-.31 2.326-.31 3.752 0 6.418 2.977 6.418 6.604 0 5.178-2.851 8.589-8.216 8.589-2.201 0-6.821-1.427-6.821-4.155 0-1.147.961-2.107 2.108-2.107 1.24 0 2.729 1.984 4.806 1.984 2.17 0 3.288-2.109 3.288-4.062 0-1.86-1.055-3.131-2.977-3.131-1.799 0-2.078 1.023-3.659 1.023-1.209 0-1.829-.93-1.829-1.457 0-.403.062-.713.093-1.054l.774-6.544c.341-2.418.93-2.945 2.418-2.945h7.472c1.428 0 2.264.837 2.264 1.953 0 2.14-1.611 2.326-2.17 2.326h-5.829l-.466 3.286z"
          />
        </Icon>
      </GlitchBadgeLayout>
    );
  } else if (delayedUsesHTML5 === false) {
    return (
      <GlitchBadgeLayout
        hasGlitches={true}
        aria-label="HTML5 not supported"
        tooltipLabel={
          tooltipLabel || (
            <>
              This item isn't converted to HTML5 yet, so it might not appear in
              Neopets.com customization yet. Once it's ready, it could look a
              bit different than our temporary preview here. It might even be
              animated!
            </>
          )
        }
      >
        <WarningTwoIcon fontSize="xs" marginRight="1" />
        <Icon viewBox="0 0 36 36" fontSize="xl">
          {/* From Twemoji Keycap 5 */}
          <path
            fill="currentColor"
            d="M16.389 14.489c.744-.155 1.551-.31 2.326-.31 3.752 0 6.418 2.977 6.418 6.604 0 5.178-2.851 8.589-8.216 8.589-2.201 0-6.821-1.427-6.821-4.155 0-1.147.961-2.107 2.108-2.107 1.24 0 2.729 1.984 4.806 1.984 2.17 0 3.288-2.109 3.288-4.062 0-1.86-1.055-3.131-2.977-3.131-1.799 0-2.078 1.023-3.659 1.023-1.209 0-1.829-.93-1.829-1.457 0-.403.062-.713.093-1.054l.774-6.544c.341-2.418.93-2.945 2.418-2.945h7.472c1.428 0 2.264.837 2.264 1.953 0 2.14-1.611 2.326-2.17 2.326h-5.829l-.466 3.286z"
          />

          {/* From Twemoji Not Allowed */}
          <path
            fill="#DD2E44"
            opacity="0.75"
            d="M18 0C8.059 0 0 8.059 0 18s8.059 18 18 18 18-8.059 18-18S27.941 0 18 0zm13 18c0 2.565-.753 4.95-2.035 6.965L11.036 7.036C13.05 5.753 15.435 5 18 5c7.18 0 13 5.821 13 13zM5 18c0-2.565.753-4.95 2.036-6.964l17.929 17.929C22.95 30.247 20.565 31 18 31c-7.179 0-13-5.82-13-13z"
          />
        </Icon>
      </GlitchBadgeLayout>
    );
  } else {
    // If no `usesHTML5` value has been provided yet, we're empty for now!
    return null;
  }
}

export function GlitchBadgeLayout({
  hasGlitches = true,
  children,
  tooltipLabel,
  ...props
}) {
  const [isHovered, setIsHovered] = React.useState(false);
  const [isFocused, setIsFocused] = React.useState(false);

  const greenBackground = useColorModeValue("green.100", "green.900");
  const greenBorderColor = useColorModeValue("green.600", "green.500");
  const greenTextColor = useColorModeValue("green.700", "white");

  const yellowBackground = useColorModeValue("yellow.100", "yellow.900");
  const yellowBorderColor = useColorModeValue("yellow.600", "yellow.500");
  const yellowTextColor = useColorModeValue("yellow.700", "white");

  return (
    <Tooltip
      textAlign="center"
      fontSize="xs"
      placement="bottom"
      label={tooltipLabel}
      // HACK: Chakra tooltips seem inconsistent about staying open when focus
      //       comes from touch events. But I really want this one to work on
      //       mobile!
      isOpen={isHovered || isFocused}
    >
      <Flex
        align="center"
        backgroundColor={hasGlitches ? yellowBackground : greenBackground}
        borderColor={hasGlitches ? yellowBorderColor : greenBorderColor}
        color={hasGlitches ? yellowTextColor : greenTextColor}
        border="1px solid"
        borderRadius="md"
        boxShadow="md"
        paddingX="2"
        paddingY="1"
        transition="all 0.2s"
        tabIndex="0"
        _focus={{ outline: "none", boxShadow: "outline" }}
        // For consistency between the HTML5Badge & OutfitKnownGlitchesBadge
        minHeight="30px"
        onMouseEnter={() => setIsHovered(true)}
        onMouseLeave={() => setIsHovered(false)}
        onFocus={() => setIsFocused(true)}
        onBlur={() => setIsFocused(false)}
        {...props}
      >
        {children}
      </Flex>
    </Tooltip>
  );
}

export function layerUsesHTML5(layer) {
  return Boolean(
    layer.svgUrl ||
      layer.canvasMovieLibraryUrl ||
      // If this glitch is applied, then `svgUrl` will be null, but there's still
      // an HTML5 manifest that the official player can render.
      (layer.knownGlitches || []).includes("OFFICIAL_SVG_IS_INCORRECT")
  );
}

export default HTML5Badge;
