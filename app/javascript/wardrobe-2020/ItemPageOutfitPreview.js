import React from "react";
import { useQuery } from "@apollo/client";
import gql from "graphql-tag";
import {
  AspectRatio,
  Box,
  Button,
  Flex,
  Grid,
  IconButton,
  Tooltip,
  useColorModeValue,
  usePrefersReducedMotion,
} from "@chakra-ui/react";
import { EditIcon, WarningIcon } from "@chakra-ui/icons";
import { MdPause, MdPlayArrow } from "react-icons/md";

import HTML5Badge, { layerUsesHTML5 } from "./components/HTML5Badge";
import SpeciesColorPicker, {
  useAllValidPetPoses,
  getValidPoses,
  getClosestPose,
} from "./components/SpeciesColorPicker";
import SpeciesFacesPicker, {
  colorIsBasic,
} from "./ItemPage/SpeciesFacesPicker";
import {
  itemAppearanceFragment,
  petAppearanceFragment,
} from "./components/useOutfitAppearance";
import { useOutfitPreview } from "./components/OutfitPreview";
import { logAndCapture, useLocalStorage } from "./util";
import { useItemAppearances } from "./loaders/items";

function ItemPageOutfitPreview({ itemId }) {
  const idealPose = React.useMemo(
    () => (Math.random() > 0.5 ? "HAPPY_FEM" : "HAPPY_MASC"),
    [],
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
    null,
  );
  const [preferredColorId, setPreferredColorId] = useLocalStorage(
    "DTIItemPreviewPreferredColorId",
    null,
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
    [setPreferredColorId, setPreferredSpeciesId],
  );

  // We don't need to reload this query when preferred species/color change, so
  // cache their initial values here to use as query arguments.
  const [initialPreferredSpeciesId] = React.useState(preferredSpeciesId);
  const [initialPreferredColorId] = React.useState(preferredColorId);

  const {
    data: itemAppearancesData,
    loading: loadingAppearances,
    error: errorAppearances,
  } = useItemAppearances(itemId);
  const itemName = itemAppearancesData?.name ?? "";
  const itemAppearances = itemAppearancesData?.appearances ?? [];
  const restrictedZones = itemAppearancesData?.restrictedZones ?? [];

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
    },
  );

  const compatibleBodies = itemAppearances?.map(({ body }) => body) || [];

  // If there's only one compatible body, and the canonical species's name
  // appears in the item name, then this is probably a species-specific item,
  // and we should adjust the UI to avoid implying that other species could
  // model it.
  const speciesName =
    data?.item?.canonicalAppearance?.body?.canonicalAppearance?.species?.name ??
    "";
  const isProbablySpeciesSpecific =
    compatibleBodies.length === 1 &&
    compatibleBodies[0] !== "all" &&
    itemName.toLowerCase().includes(speciesName.toLowerCase());
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
    [valids, idealPose, setPetStateFromUserAction],
  );

  const borderColor = useColorModeValue("green.700", "green.400");
  const errorColor = useColorModeValue("red.600", "red.400");

  const error = errorGQL || errorAppearances || errorValids;
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
      width="100%"
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
              !loadingAppearances &&
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
          isLoading={loadingGQL || loadingAppearances || loadingValids}
        />
      </Box>
      <Flex gridArea="zones" justifySelf="center" align="center">
        {itemAppearances.length > 0 && (
          <ItemZonesInfo
            itemAppearances={itemAppearances}
            restrictedZones={restrictedZones}
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
          `Measurer node not ready during effect. Transition won't be smooth.`,
        ),
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

function ItemZonesInfo({ itemAppearances, restrictedZones }) {
  // Reorganize the body-and-zones data, into zone-and-bodies data. Also, we're
  // merging zones with the same label, because that's how user-facing zone UI
  // generally works!
  const zoneLabelsAndTheirBodiesMap = {};
  for (const { body, swfAssets } of itemAppearances) {
    for (const { zone } of swfAssets) {
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
      buildSortKeyForZoneLabelsAndTheirBodies(b),
    ),
  );

  const restrictedZoneLabels = [
    ...new Set(restrictedZones.map((z) => z.label)),
  ].sort();

  // We only show body info if there's more than one group of bodies to talk
  // about. If they all have the same zones, it's clear from context that any
  // preview available in the list has the zones listed here.
  const bodyGroups = new Set(
    zoneLabelsAndTheirBodies.map(({ bodies }) =>
      bodies.map((b) => b.id).join(","),
    ),
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
      const speciesNames = new Set(bodies.map((b) => b.species.humanName));
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

export default ItemPageOutfitPreview;
