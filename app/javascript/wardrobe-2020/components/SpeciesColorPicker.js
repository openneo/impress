import React from "react";
import gql from "graphql-tag";
import { useQuery } from "@apollo/client";
import { Box, Flex, Select, Text, useColorModeValue } from "@chakra-ui/react";

import { Delay, logAndCapture, useFetch } from "../util";

/**
 * SpeciesColorPicker lets the user pick the species/color of their pet.
 *
 * It preloads all species, colors, and valid species/color pairs; and then
 * ensures that the outfit is always in a valid state.
 *
 * NOTE: This component is memoized with React.memo. It's not the cheapest to
 *       re-render on every outfit change. This contributes to
 *       wearing/unwearing items being noticeably slower on lower-power
 *       devices.
 */
function SpeciesColorPicker({
  speciesId,
  colorId,
  idealPose,
  showPlaceholders = false,
  colorPlaceholderText = "",
  speciesPlaceholderText = "",
  stateMustAlwaysBeValid = false,
  isDisabled = false,
  speciesIsDisabled = false,
  size = "md",
  speciesTestId = null,
  colorTestId = null,
  onChange,
}) {
  const { loading: loadingMeta, error: errorMeta, data: meta } = useQuery(gql`
    query SpeciesColorPicker {
      allSpecies {
        id
        name
        standardBodyId # Used for keeping items on during standard color changes
      }

      allColors {
        id
        name
        isStandard # Used for keeping items on during standard color changes
      }
    }
  `);

  const {
    loading: loadingValids,
    error: errorValids,
    valids,
  } = useAllValidPetPoses();

  const allColors = (meta && [...meta.allColors]) || [];
  allColors.sort((a, b) => a.name.localeCompare(b.name));
  const allSpecies = (meta && [...meta.allSpecies]) || [];
  allSpecies.sort((a, b) => a.name.localeCompare(b.name));

  const textColor = useColorModeValue("inherit", "green.50");

  if ((loadingMeta || loadingValids) && !showPlaceholders) {
    return (
      <Delay ms={5000}>
        <Text color={textColor} textShadow="md">
          Loading species/color data…
        </Text>
      </Delay>
    );
  }

  if (errorMeta || errorValids) {
    return (
      <Text color={textColor} textShadow="md">
        Error loading species/color data.
      </Text>
    );
  }

  // When the color changes, check if the new pair is valid, and update the
  // outfit if so!
  const onChangeColor = (e) => {
    const newColorId = e.target.value;
    console.debug(`SpeciesColorPicker.onChangeColor`, {
      // for IMPRESS-2020-1H
      speciesId,
      colorId,
      newColorId,
    });

    // Ignore switching to the placeholder option. It shouldn't generally be
    // doable once real options exist, and it doesn't represent a valid or
    // meaningful transition in the case where it could happen.
    if (newColorId === "SpeciesColorPicker-color-loading-placeholder") {
      return;
    }

    const species = allSpecies.find((s) => s.id === speciesId);
    const newColor = allColors.find((c) => c.id === newColorId);
    const validPoses = getValidPoses(valids, speciesId, newColorId);
    const isValid = validPoses.size > 0;
    if (stateMustAlwaysBeValid && !isValid) {
      // NOTE: This shouldn't happen, because we should hide invalid colors.
      logAndCapture(
        new Error(
          `Assertion error in SpeciesColorPicker: Entered an invalid state, ` +
            `with prop stateMustAlwaysBeValid: speciesId=${speciesId}, ` +
            `colorId=${newColorId}.`
        )
      );
      return;
    }
    const closestPose = getClosestPose(validPoses, idealPose);
    onChange(species, newColor, isValid, closestPose);
  };

  // When the species changes, check if the new pair is valid, and update the
  // outfit if so!
  const onChangeSpecies = (e) => {
    const newSpeciesId = e.target.value;
    console.debug(`SpeciesColorPicker.onChangeSpecies`, {
      // for IMPRESS-2020-1H
      speciesId,
      newSpeciesId,
      colorId,
    });

    // Ignore switching to the placeholder option. It shouldn't generally be
    // doable once real options exist, and it doesn't represent a valid or
    // meaningful transition in the case where it could happen.
    if (newSpeciesId === "SpeciesColorPicker-species-loading-placeholder") {
      return;
    }

    const newSpecies = allSpecies.find((s) => s.id === newSpeciesId);
    if (!newSpecies) {
      // Trying to isolate Sentry issue IMPRESS-2020-1H, where an empty species
      // ends up coming out of `onChange`!
      console.debug({ allSpecies, loadingMeta, errorMeta, meta });
      logAndCapture(
        new Error(
          `Assertion error in SpeciesColorPicker: species not found. ` +
            `speciesId=${speciesId}, newSpeciesId=${newSpeciesId}, ` +
            `colorId=${colorId}.`
        )
      );
      return;
    }

    let color = allColors.find((c) => c.id === colorId);
    let validPoses = getValidPoses(valids, newSpeciesId, colorId);
    let isValid = validPoses.size > 0;

    if (stateMustAlwaysBeValid && !isValid) {
      // If `stateMustAlwaysBeValid`, but the user switches to a species that
      // doesn't support this color, that's okay and normal! We'll just switch
      // to one of the four basic colors instead.
      const basicColorId = ["8", "34", "61", "84"][
        Math.floor(Math.random() * 4)
      ];
      const basicColor = allColors.find((c) => c.id === basicColorId);
      color = basicColor;
      validPoses = getValidPoses(valids, newSpeciesId, color.id);
      isValid = true;
    }

    const closestPose = getClosestPose(validPoses, idealPose);
    onChange(newSpecies, color, isValid, closestPose);
  };

  // In `stateMustAlwaysBeValid` mode, we hide colors that are invalid on this
  // species, so the user can't switch. (We handle species differently: if you
  // switch to a new species and the color is invalid, we reset the color. We
  // think this matches users' mental hierarchy of species -> color: showing
  // supported colors for a species makes sense, but the other way around feels
  // confusing and restrictive.)
  //
  // Also, if a color is provided that wouldn't normally be visible, we still
  // show it. This can happen when someone models a new species/color combo for
  // the first time - the boxes will still be red as if it were invalid, but
  // this still smooths out the experience a lot.
  let visibleColors = allColors;
  if (stateMustAlwaysBeValid && valids && speciesId) {
    visibleColors = visibleColors.filter(
      (c) => getValidPoses(valids, speciesId, c.id).size > 0 || c.id === colorId
    );
  }

  return (
    <Flex direction="row">
      <SpeciesColorSelect
        aria-label="Pet color"
        value={colorId || "SpeciesColorPicker-color-loading-placeholder"}
        // We also wait for the valid pairs before enabling, so users can't
        // trigger change events we're not ready for. Also, if the caller
        // hasn't provided species and color yet, assume it's still loading.
        isLoading={
          allColors.length === 0 || loadingValids || !speciesId || !colorId
        }
        isDisabled={isDisabled}
        onChange={onChangeColor}
        size={size}
        valids={valids}
        speciesId={speciesId}
        colorId={colorId}
        data-test-id={colorTestId}
      >
        {
          // If the selected color isn't in the set we have here, show the
          // placeholder. (Can happen during loading, or if an invalid color ID
          // like null is intentionally provided while the real value loads.)
          !visibleColors.some((c) => c.id === colorId) && (
            <option value="SpeciesColorPicker-color-loading-placeholder">
              {colorPlaceholderText}
            </option>
          )
        }
        {
          // A long name for sizing! Should appear below the placeholder, out
          // of view.
          visibleColors.length === 0 && <option>Dimensional</option>
        }
        {visibleColors.map((color) => (
          <option key={color.id} value={color.id}>
            {color.name}
          </option>
        ))}
      </SpeciesColorSelect>
      <Box width={size === "sm" ? 2 : 4} />
      <SpeciesColorSelect
        aria-label="Pet species"
        value={speciesId || "SpeciesColorPicker-species-loading-placeholder"}
        // We also wait for the valid pairs before enabling, so users can't
        // trigger change events we're not ready for. Also, if the caller
        // hasn't provided species and color yet, assume it's still loading.
        isLoading={
          allColors.length === 0 || loadingValids || !speciesId || !colorId
        }
        isDisabled={isDisabled || speciesIsDisabled}
        // Don't fade out in the speciesIsDisabled case; it's more like a
        // read-only state.
        _disabled={
          speciesIsDisabled
            ? { opacity: "1", cursor: "not-allowed" }
            : undefined
        }
        onChange={onChangeSpecies}
        size={size}
        valids={valids}
        speciesId={speciesId}
        colorId={colorId}
        data-test-id={speciesTestId}
      >
        {
          // If the selected species isn't in the set we have here, show the
          // placeholder. (Can happen during loading, or if an invalid species
          // ID like null is intentionally provided while the real value
          // loads.)
          !allSpecies.some((s) => s.id === speciesId) && (
            <option value="SpeciesColorPicker-species-loading-placeholder">
              {speciesPlaceholderText}
            </option>
          )
        }
        {
          // A long name for sizing! Should appear below the placeholder, out
          // of view.
          allSpecies.length === 0 && <option>Tuskaninny</option>
        }
        {allSpecies.map((species) => (
          <option key={species.id} value={species.id}>
            {species.name}
          </option>
        ))}
      </SpeciesColorSelect>
    </Flex>
  );
}

const SpeciesColorSelect = ({
  size,
  valids,
  speciesId,
  colorId,
  isDisabled,
  isLoading,
  ...props
}) => {
  const backgroundColor = useColorModeValue("white", "gray.600");
  const borderColor = useColorModeValue("green.600", "transparent");
  const textColor = useColorModeValue("inherit", "green.50");

  const loadingProps = isLoading
    ? {
        // Visually the disabled state is the same as the normal state, but
        // with a wait cursor. We don't expect this to take long, and the flash
        // of content is rough!
        opacity: "1 !important",
        cursor: "wait !important",
      }
    : {};

  return (
    <Select
      backgroundColor={backgroundColor}
      color={textColor}
      size={size}
      border="1px"
      borderColor={borderColor}
      boxShadow="md"
      width="auto"
      transition="all 0.25s"
      _hover={{
        borderColor: "green.400",
      }}
      isInvalid={
        valids &&
        speciesId &&
        colorId &&
        !pairIsValid(valids, speciesId, colorId)
      }
      isDisabled={isDisabled || isLoading}
      errorBorderColor="red.300"
      {...props}
      {...loadingProps}
    />
  );
};

let cachedResponseForAllValidPetPoses = null;

/**
 * useAllValidPoses fetches the valid pet poses, as a `valids` object ready to
 * pass into the various validity-checker utility functions!
 *
 * In addition to the network caching, we globally cache this response in the
 * client code as `cachedResponseForAllValidPetPoses`. This helps prevent extra
 * re-renders when client-side navigating between pages, similar to how cached
 * data from GraphQL serves on the first render, without a loading state.
 */
export function useAllValidPetPoses() {
  const networkResponse = useFetch("/api/validPetPoses", {
    responseType: "arrayBuffer",
    // If we already have globally-cached valids, skip the request.
    skip: cachedResponseForAllValidPetPoses != null,
  });

  // Use the globally-cached response if we have one, or await the network
  // response if not.
  const response = cachedResponseForAllValidPetPoses || networkResponse;
  const { loading, error, data: validsBuffer } = response;

  const valids = React.useMemo(
    () => validsBuffer && new DataView(validsBuffer),
    [validsBuffer]
  );

  // Once a network response comes in, save it as the globally-cached response.
  React.useEffect(() => {
    if (
      networkResponse &&
      !networkResponse.loading &&
      !cachedResponseForAllValidPetPoses
    ) {
      cachedResponseForAllValidPetPoses = networkResponse;
    }
  }, [networkResponse]);

  return { loading, error, valids };
}

function getPairByte(valids, speciesId, colorId) {
  // Reading a bit table, owo!
  const speciesIndex = speciesId - 1;
  const colorIndex = colorId - 1;
  const numColors = valids.getUint8(1);
  const pairByteIndex = speciesIndex * numColors + colorIndex + 2;
  try {
    return valids.getUint8(pairByteIndex);
  } catch (e) {
    logAndCapture(
      new Error(
        `Error loading valid poses for species=${speciesId}, color=${colorId}: ${e.message}`
      )
    );
    return 0;
  }
}

function pairIsValid(valids, speciesId, colorId) {
  return getPairByte(valids, speciesId, colorId) !== 0;
}

export function getValidPoses(valids, speciesId, colorId) {
  const pairByte = getPairByte(valids, speciesId, colorId);

  const validPoses = new Set();
  if (pairByte & 0b00000001) validPoses.add("HAPPY_MASC");
  if (pairByte & 0b00000010) validPoses.add("SAD_MASC");
  if (pairByte & 0b00000100) validPoses.add("SICK_MASC");
  if (pairByte & 0b00001000) validPoses.add("HAPPY_FEM");
  if (pairByte & 0b00010000) validPoses.add("SAD_FEM");
  if (pairByte & 0b00100000) validPoses.add("SICK_FEM");
  if (pairByte & 0b01000000) validPoses.add("UNCONVERTED");
  if (pairByte & 0b10000000) validPoses.add("UNKNOWN");

  return validPoses;
}

export function getClosestPose(validPoses, idealPose) {
  return closestPosesInOrder[idealPose].find((p) => validPoses.has(p)) || null;
}

// For each pose, in what order do we prefer to match other poses?
//
// The principles of this ordering are:
//   - Happy/sad matters more than gender presentation.
//   - "Sick" is an unpopular emotion, and it's better to change gender
//     presentation and stay happy/sad than to become sick.
//   - Sad is a better fallback for sick than happy.
//   - Unconverted vs converted is the biggest possible difference.
//   - Unknown is the pose of last resort - even coming from another unknown.
const closestPosesInOrder = {
  HAPPY_MASC: [
    "HAPPY_MASC",
    "HAPPY_FEM",
    "SAD_MASC",
    "SAD_FEM",
    "SICK_MASC",
    "SICK_FEM",
    "UNCONVERTED",
    "UNKNOWN",
  ],
  HAPPY_FEM: [
    "HAPPY_FEM",
    "HAPPY_MASC",
    "SAD_FEM",
    "SAD_MASC",
    "SICK_FEM",
    "SICK_MASC",
    "UNCONVERTED",
    "UNKNOWN",
  ],
  SAD_MASC: [
    "SAD_MASC",
    "SAD_FEM",
    "HAPPY_MASC",
    "HAPPY_FEM",
    "SICK_MASC",
    "SICK_FEM",
    "UNCONVERTED",
    "UNKNOWN",
  ],
  SAD_FEM: [
    "SAD_FEM",
    "SAD_MASC",
    "HAPPY_FEM",
    "HAPPY_MASC",
    "SICK_FEM",
    "SICK_MASC",
    "UNCONVERTED",
    "UNKNOWN",
  ],
  SICK_MASC: [
    "SICK_MASC",
    "SICK_FEM",
    "SAD_MASC",
    "SAD_FEM",
    "HAPPY_MASC",
    "HAPPY_FEM",
    "UNCONVERTED",
    "UNKNOWN",
  ],
  SICK_FEM: [
    "SICK_FEM",
    "SICK_MASC",
    "SAD_FEM",
    "SAD_MASC",
    "HAPPY_FEM",
    "HAPPY_MASC",
    "UNCONVERTED",
    "UNKNOWN",
  ],
  UNCONVERTED: [
    "UNCONVERTED",
    "HAPPY_FEM",
    "HAPPY_MASC",
    "SAD_FEM",
    "SAD_MASC",
    "SICK_FEM",
    "SICK_MASC",
    "UNKNOWN",
  ],
  UNKNOWN: [
    "HAPPY_FEM",
    "HAPPY_MASC",
    "SAD_FEM",
    "SAD_MASC",
    "SICK_FEM",
    "SICK_MASC",
    "UNCONVERTED",
    "UNKNOWN",
  ],
};

export default React.memo(SpeciesColorPicker);
