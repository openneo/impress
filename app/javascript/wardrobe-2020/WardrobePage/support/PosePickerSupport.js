import React from "react";
import gql from "graphql-tag";
import { useMutation, useQuery } from "@apollo/client";
import {
  Box,
  Button,
  IconButton,
  Select,
  Spinner,
  Switch,
  Wrap,
  WrapItem,
  useDisclosure,
  UnorderedList,
  ListItem,
} from "@chakra-ui/react";
import {
  ArrowBackIcon,
  ArrowForwardIcon,
  CheckCircleIcon,
  EditIcon,
} from "@chakra-ui/icons";

import HangerSpinner from "../../components/HangerSpinner";
import Metadata, { MetadataLabel, MetadataValue } from "./Metadata";
import useSupport from "./useSupport";
import AppearanceLayerSupportModal from "./AppearanceLayerSupportModal";
import { petAppearanceForPosePickerFragment } from "../PosePicker";

function PosePickerSupport({
  speciesId,
  colorId,
  pose,
  appearanceId,
  initialFocusRef,
  dispatchToOutfit,
}) {
  const { loading, error, data } = useQuery(
    gql`
      query PosePickerSupport($speciesId: ID!, $colorId: ID!) {
        petAppearances(speciesId: $speciesId, colorId: $colorId) {
          id
          pose
          isGlitched
          layers {
            id
            zone {
              id
              label @client
            }

            # For AppearanceLayerSupportModal
            remoteId
            bodyId
            swfUrl
            svgUrl
            imageUrl: imageUrlV2(idealSize: SIZE_600)
            canvasMovieLibraryUrl
          }
          restrictedZones {
            id
            label @client
          }

          # For AppearanceLayerSupportModal to know the name
          species {
            id
            name
          }
          color {
            id
            name
          }

          # Also, anything the PosePicker wants that isn't here, so that we
          # don't have to refetch anything when we change the canonical poses.
          ...PetAppearanceForPosePicker
        }

        ...CanonicalPetAppearances
      }
      ${canonicalPetAppearancesFragment}
      ${petAppearanceForPosePickerFragment}
    `,
    { variables: { speciesId, colorId } }
  );

  // Resize the Popover when we toggle loading state, because it probably will
  // affect the content size. appearanceId might also affect content size, if
  // it occupies different zones.
  //
  // NOTE: This also triggers an additional necessary resize when the component
  //       first mounts, because PosePicker lazy-loads it, so it actually
  //       mounting affects size too.
  React.useLayoutEffect(() => {
    // HACK: To trigger a Popover resize, we simulate a window resize event,
    //       because Popover listens for window resizes to reposition itself.
    //       I've also filed an issue requesting an official API!
    //       https://github.com/chakra-ui/chakra-ui/issues/1853
    window.dispatchEvent(new Event("resize"));
  }, [loading, appearanceId]);

  const canonicalAppearanceIdsByPose = {
    HAPPY_MASC: data?.happyMasc?.id,
    SAD_MASC: data?.sadMasc?.id,
    SICK_MASC: data?.sickMasc?.id,
    HAPPY_FEM: data?.happyFem?.id,
    SAD_FEM: data?.sadFem?.id,
    SICK_FEM: data?.sickFem?.id,
    UNCONVERTED: data?.unconverted?.id,
    UNKNOWN: data?.unknown?.id,
  };
  const canonicalAppearanceIds = Object.values(
    canonicalAppearanceIdsByPose
  ).filter((id) => id);

  const providedAppearanceId = appearanceId;
  if (!providedAppearanceId) {
    appearanceId = canonicalAppearanceIdsByPose[pose];
  }

  // If you don't already have `appearanceId` in the outfit state, opening up
  // PosePickerSupport adds it! That way, if you make changes that affect the
  // canonical poses, we'll still stay navigated to this one.
  React.useEffect(() => {
    if (!providedAppearanceId && appearanceId) {
      dispatchToOutfit({
        type: "setPose",
        pose,
        appearanceId,
      });
    }
  }, [providedAppearanceId, appearanceId, pose, dispatchToOutfit]);

  if (loading) {
    return (
      <Box display="flex" justifyContent="center">
        <HangerSpinner size="sm" />
      </Box>
    );
  }

  if (error) {
    return (
      <Box color="red.400" marginTop="8">
        {error.message}
      </Box>
    );
  }

  const currentPetAppearance = data.petAppearances.find(
    (pa) => pa.id === appearanceId
  );
  if (!currentPetAppearance) {
    return (
      <Box color="red.400" marginTop="8">
        Pet appearance with ID {JSON.stringify(appearanceId)} not found
      </Box>
    );
  }

  return (
    <Box>
      <PosePickerSupportNavigator
        petAppearances={data.petAppearances}
        currentPetAppearance={currentPetAppearance}
        canonicalAppearanceIds={canonicalAppearanceIds}
        dropdownRef={initialFocusRef}
        dispatchToOutfit={dispatchToOutfit}
      />
      <Metadata
        fontSize="sm"
        // Build a new copy of this tree when the appearance changes, to reset
        // things like element focus and mutation state!
        key={currentPetAppearance.id}
      >
        <MetadataLabel>DTI ID:</MetadataLabel>
        <MetadataValue>{appearanceId}</MetadataValue>
        <MetadataLabel>Pose:</MetadataLabel>
        <MetadataValue>
          <PosePickerSupportPoseFields
            petAppearance={currentPetAppearance}
            speciesId={speciesId}
            colorId={colorId}
          />
        </MetadataValue>
        <MetadataLabel>Layers:</MetadataLabel>
        <MetadataValue>
          <Wrap spacing="1">
            {currentPetAppearance.layers
              .map((layer) => [`${layer.zone.label} (${layer.zone.id})`, layer])
              .sort((a, b) => a[0].localeCompare(b[0]))
              .map(([text, layer]) => (
                <WrapItem key={layer.id}>
                  <PetLayerSupportLink
                    outfitState={{ speciesId, colorId, pose }}
                    petAppearance={currentPetAppearance}
                    layer={layer}
                  >
                    {text}
                    <EditIcon marginLeft="1" />
                  </PetLayerSupportLink>
                </WrapItem>
              ))}
          </Wrap>
        </MetadataValue>
        <MetadataLabel>Restricts:</MetadataLabel>
        <MetadataValue maxHeight="64" overflowY="auto">
          {currentPetAppearance.restrictedZones.length > 0 ? (
            <UnorderedList>
              {currentPetAppearance.restrictedZones
                .map((zone) => `${zone.label} (${zone.id})`)
                .sort((a, b) => a[0].localeCompare(b[0]))
                .map((zoneText) => (
                  <ListItem key={zoneText}>{zoneText}</ListItem>
                ))}
            </UnorderedList>
          ) : (
            <Box fontStyle="italic" opacity="0.8">
              None
            </Box>
          )}
        </MetadataValue>
      </Metadata>
    </Box>
  );
}

function PetLayerSupportLink({ outfitState, petAppearance, layer, children }) {
  const { isOpen, onOpen, onClose } = useDisclosure();
  return (
    <>
      <Button size="xs" onClick={onOpen}>
        {children}
      </Button>
      <AppearanceLayerSupportModal
        outfitState={outfitState}
        petAppearance={petAppearance}
        layer={layer}
        isOpen={isOpen}
        onClose={onClose}
      />
    </>
  );
}

function PosePickerSupportNavigator({
  petAppearances,
  currentPetAppearance,
  canonicalAppearanceIds,
  dropdownRef,
  dispatchToOutfit,
}) {
  const currentIndex = petAppearances.indexOf(currentPetAppearance);
  const prevPetAppearance = petAppearances[currentIndex - 1];
  const nextPetAppearance = petAppearances[currentIndex + 1];

  return (
    <Box
      display="flex"
      justifyContent="flex-end"
      marginBottom="4"
      // Space for the position-absolute PosePicker mode switcher
      paddingLeft="12"
    >
      <IconButton
        aria-label="Go to previous appearance"
        icon={<ArrowBackIcon />}
        size="sm"
        marginRight="2"
        isDisabled={prevPetAppearance == null}
        onClick={() =>
          dispatchToOutfit({
            type: "setPose",
            pose: prevPetAppearance.pose,
            appearanceId: prevPetAppearance.id,
          })
        }
      />
      <Select
        size="sm"
        width="auto"
        value={currentPetAppearance.id}
        ref={dropdownRef}
        onChange={(e) => {
          const id = e.target.value;
          const petAppearance = petAppearances.find((pa) => pa.id === id);
          dispatchToOutfit({
            type: "setPose",
            pose: petAppearance.pose,
            appearanceId: petAppearance.id,
          });
        }}
      >
        {petAppearances.map((pa) => (
          <option key={pa.id} value={pa.id}>
            {POSE_NAMES[pa.pose]}{" "}
            {canonicalAppearanceIds.includes(pa.id) && "⭐️"}
            {pa.isGlitched && "👾"} ({pa.id})
          </option>
        ))}
      </Select>
      <IconButton
        aria-label="Go to next appearance"
        icon={<ArrowForwardIcon />}
        size="sm"
        marginLeft="2"
        isDisabled={nextPetAppearance == null}
        onClick={() =>
          dispatchToOutfit({
            type: "setPose",
            pose: nextPetAppearance.pose,
            appearanceId: nextPetAppearance.id,
          })
        }
      />
    </Box>
  );
}

function PosePickerSupportPoseFields({ petAppearance, speciesId, colorId }) {
  const { supportSecret } = useSupport();

  const [mutatePose, poseMutation] = useMutation(
    gql`
      mutation PosePickerSupportSetPetAppearancePose(
        $appearanceId: ID!
        $pose: Pose!
        $supportSecret: String!
      ) {
        setPetAppearancePose(
          appearanceId: $appearanceId
          pose: $pose
          supportSecret: $supportSecret
        ) {
          id
          pose
        }
      }
    `,
    {
      refetchQueries: [
        {
          query: gql`
            query PosePickerSupportRefetchCanonicalAppearances(
              $speciesId: ID!
              $colorId: ID!
            ) {
              ...CanonicalPetAppearances
            }
            ${canonicalPetAppearancesFragment}
          `,
          variables: { speciesId, colorId },
        },
      ],
    }
  );

  const [mutateIsGlitched, isGlitchedMutation] = useMutation(
    gql`
      mutation PosePickerSupportSetPetAppearanceIsGlitched(
        $appearanceId: ID!
        $isGlitched: Boolean!
        $supportSecret: String!
      ) {
        setPetAppearanceIsGlitched(
          appearanceId: $appearanceId
          isGlitched: $isGlitched
          supportSecret: $supportSecret
        ) {
          id
          isGlitched
        }
      }
    `,
    {
      refetchQueries: [
        {
          query: gql`
            query PosePickerSupportRefetchCanonicalAppearances(
              $speciesId: ID!
              $colorId: ID!
            ) {
              ...CanonicalPetAppearances
            }
            ${canonicalPetAppearancesFragment}
          `,
          variables: { speciesId, colorId },
        },
      ],
    }
  );

  return (
    <Box>
      <Box display="flex" flexDirection="row" alignItems="center">
        <Select
          size="sm"
          value={petAppearance.pose}
          flex="0 1 200px"
          icon={
            poseMutation.loading ? (
              <Spinner />
            ) : poseMutation.data ? (
              <CheckCircleIcon />
            ) : undefined
          }
          onChange={(e) => {
            const pose = e.target.value;
            mutatePose({
              variables: {
                appearanceId: petAppearance.id,
                pose,
                supportSecret,
              },
              optimisticResponse: {
                __typename: "Mutation",
                setPetAppearancePose: {
                  __typename: "PetAppearance",
                  id: petAppearance.id,
                  pose,
                },
              },
            }).catch((e) => {
              /* Discard errors here; we'll show them in the UI! */
            });
          }}
          isInvalid={poseMutation.error != null}
        >
          {Object.entries(POSE_NAMES).map(([pose, name]) => (
            <option key={pose} value={pose}>
              {name}
            </option>
          ))}
        </Select>
        <Select
          size="sm"
          marginLeft="2"
          flex="0 1 150px"
          value={petAppearance.isGlitched}
          icon={
            isGlitchedMutation.loading ? (
              <Spinner />
            ) : isGlitchedMutation.data ? (
              <CheckCircleIcon />
            ) : undefined
          }
          onChange={(e) => {
            const isGlitched = e.target.value === "true";
            mutateIsGlitched({
              variables: {
                appearanceId: petAppearance.id,
                isGlitched,
                supportSecret,
              },
              optimisticResponse: {
                __typename: "Mutation",
                setPetAppearanceIsGlitched: {
                  __typename: "PetAppearance",
                  id: petAppearance.id,
                  isGlitched,
                },
              },
            }).catch((e) => {
              /* Discard errors here; we'll show them in the UI! */
            });
          }}
          isInvalid={isGlitchedMutation.error != null}
        >
          <option value="false">Valid</option>
          <option value="true">Glitched</option>
        </Select>
      </Box>
      {poseMutation.error && (
        <Box color="red.400">{poseMutation.error.message}</Box>
      )}
      {isGlitchedMutation.error && (
        <Box color="red.400">{isGlitchedMutation.error.message}</Box>
      )}
    </Box>
  );
}

export function PosePickerSupportSwitch({ isChecked, onChange }) {
  return (
    <Box as="label" display="flex" flexDirection="row" alignItems="center">
      <Box fontSize="sm">
        <span role="img" aria-label="Support">
          💖
        </span>
      </Box>
      <Switch
        colorScheme="pink"
        marginLeft="1"
        size="sm"
        isChecked={isChecked}
        onChange={onChange}
      />
    </Box>
  );
}

const POSE_NAMES = {
  HAPPY_MASC: "Happy Masc",
  HAPPY_FEM: "Happy Fem",
  SAD_MASC: "Sad Masc",
  SAD_FEM: "Sad Fem",
  SICK_MASC: "Sick Masc",
  SICK_FEM: "Sick Fem",
  UNCONVERTED: "Unconverted",
  UNKNOWN: "Unknown",
};

const canonicalPetAppearancesFragment = gql`
  fragment CanonicalPetAppearances on Query {
    happyMasc: petAppearance(
      speciesId: $speciesId
      colorId: $colorId
      pose: HAPPY_MASC
    ) {
      id
    }

    sadMasc: petAppearance(
      speciesId: $speciesId
      colorId: $colorId
      pose: SAD_MASC
    ) {
      id
    }

    sickMasc: petAppearance(
      speciesId: $speciesId
      colorId: $colorId
      pose: SICK_MASC
    ) {
      id
    }

    happyFem: petAppearance(
      speciesId: $speciesId
      colorId: $colorId
      pose: HAPPY_FEM
    ) {
      id
    }

    sadFem: petAppearance(
      speciesId: $speciesId
      colorId: $colorId
      pose: SAD_FEM
    ) {
      id
    }

    sickFem: petAppearance(
      speciesId: $speciesId
      colorId: $colorId
      pose: SICK_FEM
    ) {
      id
    }

    unconverted: petAppearance(
      speciesId: $speciesId
      colorId: $colorId
      pose: UNCONVERTED
    ) {
      id
    }

    unknown: petAppearance(
      speciesId: $speciesId
      colorId: $colorId
      pose: UNKNOWN
    ) {
      id
    }
  }
`;

export default PosePickerSupport;
