import React from "react";
import { Box, VStack } from "@chakra-ui/react";
import { WarningTwoIcon } from "@chakra-ui/icons";
import { FaBug } from "react-icons/fa";
import { GlitchBadgeLayout, layerUsesHTML5 } from "../components/HTML5Badge";
import getVisibleLayers from "../components/getVisibleLayers";
import { useLocalStorage } from "../util";

function OutfitKnownGlitchesBadge({ appearance }) {
  const [hiResMode] = useLocalStorage("DTIHiResMode", false);
  const { petAppearance, items } = appearance;

  const glitchMessages = [];

  // Look for UC/Invisible/etc incompatibilities that we hid, that we should
  // just mark Incompatible someday instead; or with correctly partially-hidden
  // art.
  //
  // NOTE: This particular glitch is checking for the *absence* of layers, so
  //       we skip it if we're still loading!
  if (!appearance.loading) {
    for (const item of items) {
      // HACK: We use `getVisibleLayers` with just this pet appearance and item
      //       appearance, to run the logic for which layers are compatible with
      //       this pet. But `getVisibleLayers` does other things too, so it's
      //       plausible that this could do not quite what we want in some cases!
      const allItemLayers = item.appearance.layers;
      const compatibleItemLayers = getVisibleLayers(petAppearance, [
        item.appearance,
      ]).filter((l) => l.source === "item");

      if (compatibleItemLayers.length === 0) {
        glitchMessages.push(
          <Box key={`total-uc-conflict-for-item-${item.id}`}>
            <i>{item.name}</i> isn't actually compatible with this special pet.
            We're hiding the item art, which is outdated behavior, and we should
            instead be treating it as entirely incompatible. Fixing this is in
            our todo list, sorry for the confusing UI!
          </Box>
        );
      } else if (compatibleItemLayers.length < allItemLayers.length) {
        glitchMessages.push(
          <Box key={`partial-uc-conflict-for-item-${item.id}`}>
            <i>{item.name}</i>'s compatibility with this pet is complicated, but
            we believe this is how it looks: some zones are visible, and some
            zones are hidden. If this isn't quite right, please email me at
            matchu@openneo.net and let me know!
          </Box>
        );
      }
    }
  }

  // Look for items with the OFFICIAL_SWF_IS_INCORRECT glitch.
  for (const item of items) {
    const itemHasBrokenOnNeopetsDotCom = item.appearance.layers.some((l) =>
      (l.knownGlitches || []).includes("OFFICIAL_SWF_IS_INCORRECT")
    );
    const itemHasBrokenUnconvertedLayers = item.appearance.layers.some(
      (l) =>
        (l.knownGlitches || []).includes("OFFICIAL_SWF_IS_INCORRECT") &&
        !layerUsesHTML5(l)
    );
    if (itemHasBrokenOnNeopetsDotCom) {
      glitchMessages.push(
        <Box key={`official-swf-is-incorrect-for-item-${item.id}`}>
          {itemHasBrokenUnconvertedLayers ? (
            <>
              We're aware of a glitch affecting the art for <i>{item.name}</i>.
              Last time we checked, this glitch affected its appearance on
              Neopets.com, too. Hopefully this will be fixed once it's converted
              to HTML5!
            </>
          ) : (
            <>
              We're aware of a previous glitch affecting the art for{" "}
              <i>{item.name}</i>, but it might have been resolved during HTML5
              conversion. Please use the feedback form on the homepage to let us
              know if it looks right, or still looks wrong! Thank you!
            </>
          )}
        </Box>
      );
    }
  }

  // Look for items with the OFFICIAL_MOVIE_IS_INCORRECT glitch.
  for (const item of items) {
    const itemHasGlitch = item.appearance.layers.some((l) =>
      (l.knownGlitches || []).includes("OFFICIAL_MOVIE_IS_INCORRECT")
    );
    if (itemHasGlitch) {
      glitchMessages.push(
        <Box key={`official-movie-is-incorrect-for-item-${item.id}`}>
          There's a glitch in the art for <i>{item.name}</i>, and we believe it
          looks this way on-site, too. But our version might be out of date! If
          you've seen it look better on-site, please email me at
          matchu@openneo.net so we can fix it!
        </Box>
      );
    }
  }

  // Look for items with the OFFICIAL_SVG_IS_INCORRECT glitch. Only show this
  // if hi-res mode is on, because otherwise it doesn't affect the user anyway!
  if (hiResMode) {
    for (const item of items) {
      const itemHasOfficialSvgIsIncorrect = item.appearance.layers.some((l) =>
        (l.knownGlitches || []).includes("OFFICIAL_SVG_IS_INCORRECT")
      );
      if (itemHasOfficialSvgIsIncorrect) {
        glitchMessages.push(
          <Box key={`official-svg-is-incorrect-for-item-${item.id}`}>
            There's a glitch in the art for <i>{item.name}</i> that prevents us
            from showing the SVG image for Hi-Res Mode. Instead, we're showing a
            PNG, which might look a bit blurry on larger screens.
          </Box>
        );
      }
    }
  }

  // Look for items with the DISPLAYS_INCORRECTLY_BUT_CAUSE_UNKNOWN glitch.
  for (const item of items) {
    const itemHasGlitch = item.appearance.layers.some((l) =>
      (l.knownGlitches || []).includes("DISPLAYS_INCORRECTLY_BUT_CAUSE_UNKNOWN")
    );
    if (itemHasGlitch) {
      glitchMessages.push(
        <Box key={`displays-incorrectly-but-cause-unknown-for-item-${item.id}`}>
          There's a glitch in the art for <i>{item.name}</i> that causes it to
          display incorrectly—but we're not sure if it's on our end, or TNT's.
          If you own this item, please email me at matchu@openneo.net to let us
          know how it looks in the on-site customizer!
        </Box>
      );
    }
  }

  // Look for items with the OFFICIAL_BODY_ID_IS_INCORRECT glitch.
  for (const item of items) {
    const itemHasOfficialBodyIdIsIncorrect = item.appearance.layers.some((l) =>
      (l.knownGlitches || []).includes("OFFICIAL_BODY_ID_IS_INCORRECT")
    );
    if (itemHasOfficialBodyIdIsIncorrect) {
      glitchMessages.push(
        <Box key={`official-body-id-is-incorrect-for-item-${item.id}`}>
          Last we checked, <i>{item.name}</i> actually is compatible with this
          pet, even though it seems like it shouldn't be. But TNT might change
          this at any time, so be careful!
        </Box>
      );
    }
  }

  // Look for Dyeworks items that aren't converted yet.
  for (const item of items) {
    const itemIsDyeworks = item.name.includes("Dyeworks");
    const itemIsConverted = item.appearance.layers.every(layerUsesHTML5);

    if (itemIsDyeworks && !itemIsConverted) {
      glitchMessages.push(
        <Box key={`unconverted-dyeworks-warning-for-item-${item.id}`}>
          <i>{item.name}</i> isn't converted to HTML5 yet, and our Classic DTI
          code often shows old Dyeworks items in the wrong color. Once it's
          converted, we'll display it correctly!
        </Box>
      );
    }
  }

  // Check whether the pet is Invisible. If so, we'll show a blanket warning.
  if (petAppearance?.color?.id === "38") {
    glitchMessages.push(
      <Box key={`invisible-pet-warning`}>
        Invisible pets are affected by a number of glitches, including faces
        sometimes being visible on-site, and errors in the HTML5 conversion. If
        this pose looks incorrect, you can try another by clicking the emoji
        face next to the species/color picker. But be aware that Neopets.com
        might look different!
      </Box>
    );
  }

  // Check if this is a Faerie Uni. If so, we'll explain the dithering horns.
  if (
    petAppearance?.color?.id === "26" &&
    petAppearance?.species?.id === "49"
  ) {
    glitchMessages.push(
      <Box key={`faerie-uni-dithering-horn-warning`}>
        The Faerie Uni is a "dithering" pet: its horn is sometimes blue, and
        sometimes yellow. To help you design for both cases, we show the blue
        horn with the feminine design, and the yellow horn with the masculine
        design—but the pet's gender does not actually affect which horn you'll
        get, and it will often change over time!
      </Box>
    );
  }

  // Check whether the pet appearance is marked as Glitched.
  if (petAppearance?.isGlitched) {
    glitchMessages.push(
      // NOTE: This message assumes that the current pet appearance is the
      //       best canonical one, but it's _possible_ to view Glitched
      //       appearances even if we _do_ have a better one saved... but
      //       only the Support UI ever takes you there.
      <Box key={`pet-appearance-is-glitched`}>
        We know that the art for this pet is incorrect, but we still haven't
        seen a <em>correct</em> model for this pose yet. Once someone models the
        correct data, we'll use that instead. For now, you could also try
        switching to another pose, by clicking the emoji face next to the
        species/color picker!
      </Box>
    );
  }

  const petLayers = petAppearance?.layers || [];

  // Look for pet layers with the OFFICIAL_SWF_IS_INCORRECT glitch.
  for (const layer of petLayers) {
    const layerHasGlitch = (layer.knownGlitches || []).includes(
      "OFFICIAL_SWF_IS_INCORRECT"
    );
    if (layerHasGlitch) {
      glitchMessages.push(
        <Box key={`official-swf-is-incorrect-for-pet-layer-${layer.id}`}>
          We're aware of a glitch affecting the art for this pet's{" "}
          <i>{layer.zone.label}</i> zone. Last time we checked, this glitch
          affected its appearance on Neopets.com, too. But our version might be
          out of date! If you've seen it look better on-site, please email me at
          matchu@openneo.net so we can fix it!
        </Box>
      );
    }
  }

  // Look for pet layers with the OFFICIAL_SVG_IS_INCORRECT glitch.
  if (hiResMode) {
    for (const layer of petLayers) {
      const layerHasOfficialSvgIsIncorrect = (
        layer.knownGlitches || []
      ).includes("OFFICIAL_SVG_IS_INCORRECT");
      if (layerHasOfficialSvgIsIncorrect) {
        glitchMessages.push(
          <Box key={`official-svg-is-incorrect-for-pet-layer-${layer.id}`}>
            There's a glitch in the art for this pet's <i>{layer.zone.label}</i>{" "}
            zone that prevents us from showing the SVG image for Hi-Res Mode.
            Instead, we're showing a PNG, which might look a bit blurry on
            larger screens.
          </Box>
        );
      }
    }
  }

  // Look for pet layers with the DISPLAYS_INCORRECTLY_BUT_CAUSE_UNKNOWN glitch.
  for (const layer of petLayers) {
    const layerHasGlitch = (layer.knownGlitches || []).includes(
      "DISPLAYS_INCORRECTLY_BUT_CAUSE_UNKNOWN"
    );
    if (layerHasGlitch) {
      glitchMessages.push(
        <Box
          key={`displays-incorrectly-but-cause-unknown-for-pet-layer-${layer.id}`}
        >
          There's a glitch in the art for this pet's <i>{layer.zone.label}</i>{" "}
          zone that causes it to display incorrectly—but we're not sure if it's
          on our end, or TNT's. If you have this pet, please email me at
          matchu@openneo.net to let us know how it looks in the on-site
          customizer!
        </Box>
      );
    }
  }

  if (glitchMessages.length === 0) {
    return null;
  }

  return (
    <GlitchBadgeLayout
      aria-label="Has known glitches"
      tooltipLabel={
        <Box>
          <Box as="header" fontWeight="bold" fontSize="sm" marginBottom="1">
            Known glitches
          </Box>
          <VStack spacing="1em">{glitchMessages}</VStack>
        </Box>
      }
    >
      <WarningTwoIcon fontSize="xs" marginRight="1" />
      <FaBug />
    </GlitchBadgeLayout>
  );
}

export default OutfitKnownGlitchesBadge;
