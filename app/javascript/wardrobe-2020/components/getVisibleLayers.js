import gql from "graphql-tag";

function getVisibleLayers(petAppearance, itemAppearances) {
  if (!petAppearance) {
    return [];
  }

  const validItemAppearances = itemAppearances.filter((a) => a);

  const petLayers = petAppearance.layers.map((l) => ({ ...l, source: "pet" }));

  const itemLayers = validItemAppearances
    .map((a) => a.layers)
    .flat()
    .map((l) => ({ ...l, source: "item" }));

  let allLayers = [...petLayers, ...itemLayers];

  const itemRestrictedZoneIds = new Set(
    validItemAppearances
      .map((a) => a.restrictedZones)
      .flat()
      .map((z) => z.id)
  );
  const petRestrictedZoneIds = new Set(
    petAppearance.restrictedZones.map((z) => z.id)
  );

  const visibleLayers = allLayers.filter((layer) => {
    // When an item restricts a zone, it hides pet layers of the same zone.
    // We use this to e.g. make a hat hide a hair ruff.
    //
    // NOTE: Items' restricted layers also affect what items you can wear at
    //       the same time. We don't enforce anything about that here, and
    //       instead assume that the input by this point is valid!
    if (layer.source === "pet" && itemRestrictedZoneIds.has(layer.zone.id)) {
      return false;
    }

    // When a pet appearance restricts a zone, or when the pet is Unconverted,
    // it makes body-specific items incompatible. We use this to disallow UCs
    // from wearing certain body-specific Biology Effects, Statics, etc, while
    // still allowing non-body-specific items in those zones! (I think this
    // happens for some Invisible pet stuff, too?)
    //
    // TODO: We shouldn't be *hiding* these zones, like we do with items; we
    //       should be doing this way earlier, to prevent the item from even
    //       showing up even in search results!
    //
    // NOTE: This can result in both pet layers and items occupying the same
    //       zone, like Static, so long as the item isn't body-specific! That's
    //       correct, and the item layer should be on top! (Here, we implement
    //       it by placing item layers second in the list, and rely on JS sort
    //       stability, and *then* rely on the UI to respect that ordering when
    //       rendering them by depth. Not great! 😅)
    //
    // NOTE: We used to also include the pet appearance's *occupied* zones in
    //       this condition, not just the restricted zones, as a sensible
    //       defensive default, even though we weren't aware of any relevant
    //       items. But now we know that actually the "Bruce Brucey B Mouth"
    //       occupies the real Mouth zone, and still should be visible and
    //       above pet layers! So, we now only check *restricted* zones.
    //
    // NOTE: UCs used to implement their restrictions by listing specific
    //       zones, but it seems that the logic has changed to just be about
    //       UC-ness and body-specific-ness, and not necessarily involve the
    //       set of restricted zones at all. (This matters because e.g. UCs
    //       shouldn't show _any_ part of the Rainy Day Umbrella, but most UCs
    //       don't restrict Right-Hand Item (Zone 49).) Still, I'm keeping the
    //       zone restriction case running too, because I don't think it
    //       _hurts_ anything, and I'm not confident enough in this conclusion.
    //
    // TODO: Do Invisibles follow this new rule like UCs, too? Or do they still
    //       use zone restrictions?
    if (
      layer.source === "item" &&
      layer.bodyId !== "0" &&
      (petAppearance.pose === "UNCONVERTED" ||
        petRestrictedZoneIds.has(layer.zone.id))
    ) {
      return false;
    }

    // A pet appearance can also restrict its own zones. The Wraith Uni is an
    // interesting example: it has a horn, but its zone restrictions hide it!
    if (layer.source === "pet" && petRestrictedZoneIds.has(layer.zone.id)) {
      return false;
    }

    return true;
  });
  visibleLayers.sort((a, b) => a.zone.depth - b.zone.depth);

  return visibleLayers;
}

// TODO: The web client could save bandwidth by applying @client to the `depth`
//       field, because it already has zone depths cached.
export const itemAppearanceFragmentForGetVisibleLayers = gql`
  fragment ItemAppearanceForGetVisibleLayers on ItemAppearance {
    id
    layers {
      id
      bodyId
      zone {
        id
        depth
      }
    }
    restrictedZones {
      id
    }
  }
`;

// TODO: The web client could save bandwidth by applying @client to the `depth`
//       field, because it already has zone depths cached.
export const petAppearanceFragmentForGetVisibleLayers = gql`
  fragment PetAppearanceForGetVisibleLayers on PetAppearance {
    id
    pose
    layers {
      id
      zone {
        id
        depth
      }
    }
    restrictedZones {
      id
    }
  }
`;

export default getVisibleLayers;
