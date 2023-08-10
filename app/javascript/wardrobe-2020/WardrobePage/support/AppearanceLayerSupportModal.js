import * as React from "react";
import gql from "graphql-tag";
import { useMutation } from "@apollo/client";
import {
  Button,
  Box,
  FormControl,
  FormErrorMessage,
  FormHelperText,
  FormLabel,
  HStack,
  Modal,
  ModalBody,
  ModalCloseButton,
  ModalContent,
  ModalFooter,
  ModalHeader,
  ModalOverlay,
  Radio,
  RadioGroup,
  Spinner,
  useDisclosure,
  useToast,
  CheckboxGroup,
  VStack,
  Checkbox,
} from "@chakra-ui/react";
import { ChevronRightIcon, ExternalLinkIcon } from "@chakra-ui/icons";

import AppearanceLayerSupportUploadModal from "./AppearanceLayerSupportUploadModal";
import Metadata, { MetadataLabel, MetadataValue } from "./Metadata";
import { OutfitLayers } from "../../components/OutfitPreview";
import SpeciesColorPicker from "../../components/SpeciesColorPicker";
import useOutfitAppearance, {
  itemAppearanceFragment,
} from "../../components/useOutfitAppearance";
import useSupport from "./useSupport";

/**
 * AppearanceLayerSupportModal offers Support info and tools for a specific item
 * appearance layer. Open it by clicking a layer from ItemSupportDrawer.
 */
function AppearanceLayerSupportModal({
  item, // Specify this or `petAppearance`
  petAppearance, // Specify this or `item`
  layer,
  outfitState, // speciesId, colorId, pose
  isOpen,
  onClose,
}) {
  const [selectedBodyId, setSelectedBodyId] = React.useState(layer.bodyId);
  const [selectedKnownGlitches, setSelectedKnownGlitches] = React.useState(
    layer.knownGlitches
  );

  const [previewBiology, setPreviewBiology] = React.useState({
    speciesId: outfitState.speciesId,
    colorId: outfitState.colorId,
    pose: outfitState.pose,
    isValid: true,
  });
  const [uploadModalIsOpen, setUploadModalIsOpen] = React.useState(false);
  const { supportSecret } = useSupport();
  const toast = useToast();

  const parentName = item
    ? item.name
    : `${petAppearance.color.name} ${petAppearance.species.name} ${petAppearance.id}`;

  const [mutate, { loading: mutationLoading, error: mutationError }] =
    useMutation(
      gql`
        mutation ApperanceLayerSupportSetLayerBodyId(
          $layerId: ID!
          $bodyId: ID!
          $knownGlitches: [AppearanceLayerKnownGlitch!]!
          $supportSecret: String!
          $outfitSpeciesId: ID!
          $outfitColorId: ID!
          $formPreviewSpeciesId: ID!
          $formPreviewColorId: ID!
        ) {
          setLayerBodyId(
            layerId: $layerId
            bodyId: $bodyId
            supportSecret: $supportSecret
          ) {
            # This mutation returns the affected AppearanceLayer. Fetch the
            # updated fields, including the appearance on the outfit pet and the
            # form preview pet, to automatically update our cached appearance in
            # the rest of the app. That means you should be able to see your
            # changes immediately!
            id
            bodyId
            item {
              id
              appearanceOnOutfit: appearanceOn(
                speciesId: $outfitSpeciesId
                colorId: $outfitColorId
              ) {
                ...ItemAppearanceForOutfitPreview
              }

              appearanceOnFormPreviewPet: appearanceOn(
                speciesId: $formPreviewSpeciesId
                colorId: $formPreviewColorId
              ) {
                ...ItemAppearanceForOutfitPreview
              }
            }
          }

          setLayerKnownGlitches(
            layerId: $layerId
            knownGlitches: $knownGlitches
            supportSecret: $supportSecret
          ) {
            id
            knownGlitches
            svgUrl # Affected by OFFICIAL_SVG_IS_INCORRECT
          }
        }
        ${itemAppearanceFragment}
      `,
      {
        variables: {
          layerId: layer.id,
          bodyId: selectedBodyId,
          knownGlitches: selectedKnownGlitches,
          supportSecret,
          outfitSpeciesId: outfitState.speciesId,
          outfitColorId: outfitState.colorId,
          formPreviewSpeciesId: previewBiology.speciesId,
          formPreviewColorId: previewBiology.colorId,
        },
        onCompleted: () => {
          onClose();
          toast({
            status: "success",
            title: `Saved layer ${layer.id}: ${parentName}`,
          });
        },
      }
    );

  // TODO: Would be nicer to just learn the correct URL from the server, but we
  //       don't happen to be saving it, and it would be extra stuff to put on
  //       the GraphQL request for non-Support users. We could also just try
  //       loading them, but, ehhh…
  const [newManifestUrl, oldManifestUrl] = convertSwfUrlToPossibleManifestUrls(
    layer.swfUrl
  );

  return (
    <Modal size="xl" isOpen={isOpen} onClose={onClose}>
      <ModalOverlay>
        <ModalContent>
          <ModalHeader>
            Layer {layer.id}: {parentName}
          </ModalHeader>
          <ModalCloseButton />
          <ModalBody>
            <Metadata>
              <MetadataLabel>DTI ID:</MetadataLabel>
              <MetadataValue>{layer.id}</MetadataValue>
              <MetadataLabel>Neopets ID:</MetadataLabel>
              <MetadataValue>{layer.remoteId}</MetadataValue>
              <MetadataLabel>Zone:</MetadataLabel>
              <MetadataValue>
                {layer.zone.label} ({layer.zone.id})
              </MetadataValue>
              <MetadataLabel>Assets:</MetadataLabel>
              <MetadataValue>
                <HStack spacing="2">
                  <Button
                    as="a"
                    size="xs"
                    target="_blank"
                    href={newManifestUrl}
                    colorScheme="teal"
                  >
                    Manifest (new) <ExternalLinkIcon ml="1" />
                  </Button>
                  <Button
                    as="a"
                    size="xs"
                    target="_blank"
                    href={oldManifestUrl}
                    colorScheme="teal"
                  >
                    Manifest (old) <ExternalLinkIcon ml="1" />
                  </Button>
                </HStack>
                <HStack spacing="2" marginTop="1">
                  {layer.canvasMovieLibraryUrl ? (
                    <Button
                      as="a"
                      size="xs"
                      target="_blank"
                      href={layer.canvasMovieLibraryUrl}
                      colorScheme="teal"
                    >
                      Movie <ExternalLinkIcon ml="1" />
                    </Button>
                  ) : (
                    <Button size="xs" isDisabled>
                      No Movie
                    </Button>
                  )}
                  {layer.svgUrl ? (
                    <Button
                      as="a"
                      size="xs"
                      target="_blank"
                      href={layer.svgUrl}
                      colorScheme="teal"
                    >
                      SVG <ExternalLinkIcon ml="1" />
                    </Button>
                  ) : (
                    <Button size="xs" isDisabled>
                      No SVG
                    </Button>
                  )}
                  {layer.imageUrl ? (
                    <Button
                      as="a"
                      size="xs"
                      target="_blank"
                      href={layer.imageUrl}
                      colorScheme="teal"
                    >
                      PNG <ExternalLinkIcon ml="1" />
                    </Button>
                  ) : (
                    <Button size="xs" isDisabled>
                      No PNG
                    </Button>
                  )}
                  <Button
                    as="a"
                    size="xs"
                    target="_blank"
                    href={layer.swfUrl}
                    colorScheme="teal"
                  >
                    SWF <ExternalLinkIcon ml="1" />
                  </Button>
                  <Box flex="1 1 0" />
                  {item && (
                    <>
                      <Button
                        size="xs"
                        colorScheme="gray"
                        onClick={() => setUploadModalIsOpen(true)}
                      >
                        Upload PNG <ChevronRightIcon />
                      </Button>
                      <AppearanceLayerSupportUploadModal
                        item={item}
                        layer={layer}
                        isOpen={uploadModalIsOpen}
                        onClose={() => setUploadModalIsOpen(false)}
                      />
                    </>
                  )}
                </HStack>
              </MetadataValue>
            </Metadata>
            <Box height="8" />
            {item && (
              <>
                <AppearanceLayerSupportPetCompatibilityFields
                  item={item}
                  layer={layer}
                  outfitState={outfitState}
                  selectedBodyId={selectedBodyId}
                  previewBiology={previewBiology}
                  onChangeBodyId={setSelectedBodyId}
                  onChangePreviewBiology={setPreviewBiology}
                />
                <Box height="8" />
              </>
            )}
            <AppearanceLayerSupportKnownGlitchesFields
              selectedKnownGlitches={selectedKnownGlitches}
              onChange={setSelectedKnownGlitches}
            />
          </ModalBody>
          <ModalFooter>
            {item && (
              <AppearanceLayerSupportModalRemoveButton
                item={item}
                layer={layer}
                outfitState={outfitState}
                onRemoveSuccess={onClose}
              />
            )}
            <Box flex="1 0 0" />
            {mutationError && (
              <Box
                color="red.400"
                fontSize="sm"
                marginLeft="8"
                marginRight="2"
                textAlign="right"
              >
                {mutationError.message}
              </Box>
            )}
            <Button
              isLoading={mutationLoading}
              colorScheme="green"
              onClick={() =>
                mutate().catch((e) => {
                  /* Discard errors here; we'll show them in the UI! */
                })
              }
              flex="0 0 auto"
            >
              Save changes
            </Button>
          </ModalFooter>
        </ModalContent>
      </ModalOverlay>
    </Modal>
  );
}

function AppearanceLayerSupportPetCompatibilityFields({
  item,
  layer,
  outfitState,
  selectedBodyId,
  previewBiology,
  onChangeBodyId,
  onChangePreviewBiology,
}) {
  const [selectedBiology, setSelectedBiology] = React.useState(previewBiology);

  const {
    loading,
    error,
    visibleLayers,
    bodyId: appearanceBodyId,
  } = useOutfitAppearance({
    speciesId: previewBiology.speciesId,
    colorId: previewBiology.colorId,
    pose: previewBiology.pose,
    wornItemIds: [item.id],
  });

  const biologyLayers = visibleLayers.filter((l) => l.source === "pet");

  // After we touch a species/color selector and null out `bodyId`, when the
  // appearance body ID loads in, select it as the new body ID.
  //
  // This might move the radio button away from "all pets", but I think that's
  // a _less_ surprising experience: if you're touching the pickers, then
  // that's probably where you head is.
  React.useEffect(() => {
    if (selectedBodyId == null && appearanceBodyId != null) {
      onChangeBodyId(appearanceBodyId);
    }
  }, [selectedBodyId, appearanceBodyId, onChangeBodyId]);

  return (
    <FormControl isInvalid={error || !selectedBiology.isValid ? true : false}>
      <FormLabel fontWeight="bold">Pet compatibility</FormLabel>
      <RadioGroup
        colorScheme="green"
        value={selectedBodyId}
        onChange={(newBodyId) => onChangeBodyId(newBodyId)}
        marginBottom="4"
      >
        <Radio value="0">
          Fits all pets{" "}
          <Box display="inline" color="gray.400" fontSize="sm">
            (Body ID: 0)
          </Box>
        </Radio>
        <Radio as="div" value={appearanceBodyId} marginTop="2">
          Fits all pets with the same body as:{" "}
          <Box display="inline" color="gray.400" fontSize="sm">
            (Body ID:{" "}
            {appearanceBodyId == null ? (
              <Spinner size="sm" />
            ) : (
              appearanceBodyId
            )}
            )
          </Box>
        </Radio>
      </RadioGroup>
      <Box display="flex" flexDirection="column" alignItems="center">
        <Box
          width="150px"
          height="150px"
          marginTop="2"
          marginBottom="2"
          boxShadow="md"
          borderRadius="md"
        >
          <OutfitLayers
            loading={loading}
            visibleLayers={[...biologyLayers, layer]}
          />
        </Box>
        <SpeciesColorPicker
          speciesId={selectedBiology.speciesId}
          colorId={selectedBiology.colorId}
          idealPose={outfitState.pose}
          size="sm"
          showPlaceholders
          onChange={(species, color, isValid, pose) => {
            const speciesId = species.id;
            const colorId = color.id;

            setSelectedBiology({ speciesId, colorId, isValid, pose });
            if (isValid) {
              onChangePreviewBiology({ speciesId, colorId, isValid, pose });

              // Also temporarily null out the body ID. We'll switch to the new
              // body ID once it's loaded.
              onChangeBodyId(null);
            }
          }}
        />
        <Box height="1" />
        {!error && (
          <FormHelperText>
            If it doesn't look right, try some other options until it does!
          </FormHelperText>
        )}
        {error && <FormErrorMessage>{error.message}</FormErrorMessage>}
      </Box>
    </FormControl>
  );
}

function AppearanceLayerSupportKnownGlitchesFields({
  selectedKnownGlitches,
  onChange,
}) {
  return (
    <FormControl>
      <FormLabel fontWeight="bold">Known glitches</FormLabel>
      <CheckboxGroup value={selectedKnownGlitches} onChange={onChange}>
        <VStack spacing="2" align="flex-start">
          <Checkbox value="OFFICIAL_SWF_IS_INCORRECT">
            Official SWF is incorrect{" "}
            <Box display="inline" color="gray.400" fontSize="sm">
              (Will display a message)
            </Box>
          </Checkbox>
          <Checkbox value="OFFICIAL_SVG_IS_INCORRECT">
            Official SVG is incorrect{" "}
            <Box display="inline" color="gray.400" fontSize="sm">
              (Will use the PNG instead)
            </Box>
          </Checkbox>
          <Checkbox value="OFFICIAL_MOVIE_IS_INCORRECT">
            Official Movie is incorrect{" "}
            <Box display="inline" color="gray.400" fontSize="sm">
              (Will display a message)
            </Box>
          </Checkbox>
          <Checkbox value="DISPLAYS_INCORRECTLY_BUT_CAUSE_UNKNOWN">
            Displays incorrectly, but cause unknown{" "}
            <Box display="inline" color="gray.400" fontSize="sm">
              (Will display a vague message)
            </Box>
          </Checkbox>
          <Checkbox value="OFFICIAL_BODY_ID_IS_INCORRECT">
            Fits all pets on-site, but should not{" "}
            <Box display="inline" color="gray.400" fontSize="sm">
              (TNT's fault. Will show a message, and keep the compatibility
              settings above.)
            </Box>
          </Checkbox>
          <Checkbox value="REQUIRES_OTHER_BODY_SPECIFIC_ASSETS">
            Only fits pets with other body-specific assets{" "}
            <Box display="inline" color="gray.400" fontSize="sm">
              (DTI's fault: bodyId=0 is a lie! Will mark incompatible for some
              pets.)
            </Box>
          </Checkbox>
        </VStack>
      </CheckboxGroup>
    </FormControl>
  );
}

function AppearanceLayerSupportModalRemoveButton({
  item,
  layer,
  outfitState,
  onRemoveSuccess,
}) {
  const { isOpen, onOpen, onClose } = useDisclosure();
  const toast = useToast();
  const { supportSecret } = useSupport();

  const [mutate, { loading, error }] = useMutation(
    gql`
      mutation AppearanceLayerSupportRemoveButton(
        $layerId: ID!
        $itemId: ID!
        $outfitSpeciesId: ID!
        $outfitColorId: ID!
        $supportSecret: String!
      ) {
        removeLayerFromItem(
          layerId: $layerId
          itemId: $itemId
          supportSecret: $supportSecret
        ) {
          # This mutation returns the affected layer, and the affected item.
          # Fetch the updated appearance for the current outfit, which should
          # no longer include this layer. This means you should be able to see
          # your changes immediately!
          item {
            id
            appearanceOn(speciesId: $outfitSpeciesId, colorId: $outfitColorId) {
              ...ItemAppearanceForOutfitPreview
            }
          }

          # The layer's item should be null now, fetch to confirm and update!
          layer {
            id
            item {
              id
            }
          }
        }
      }
      ${itemAppearanceFragment}
    `,
    {
      variables: {
        layerId: layer.id,
        itemId: item.id,
        outfitSpeciesId: outfitState.speciesId,
        outfitColorId: outfitState.colorId,
        supportSecret,
      },
      onCompleted: () => {
        onClose();
        onRemoveSuccess();
        toast({
          status: "success",
          title: `Removed layer ${layer.id} from ${item.name}`,
        });
      },
    }
  );

  return (
    <>
      <Button colorScheme="red" flex="0 0 auto" onClick={onOpen}>
        Remove
      </Button>
      <Modal isOpen={isOpen} onClose={onClose} size="xl" isCentered>
        <ModalOverlay>
          <ModalContent>
            <ModalCloseButton />
            <ModalHeader>
              Remove Layer {layer.id} ({layer.zone.label}) from {item.name}?
            </ModalHeader>
            <ModalBody>
              <Box as="p" marginBottom="4">
                This will permanently-ish remove Layer {layer.id} (
                {layer.zone.label}) from this item.
              </Box>
              <Box as="p" marginBottom="4">
                If you remove a correct layer by mistake, re-modeling should fix
                it, or Matchu can restore it if you write down the layer ID
                before proceeding!
              </Box>
              <Box as="p" marginBottom="4">
                Are you sure you want to remove Layer {layer.id} from this item?
              </Box>
            </ModalBody>
            <ModalFooter>
              <Button flex="0 0 auto" onClick={onClose}>
                Close
              </Button>
              <Box flex="1 0 0" />
              {error && (
                <Box
                  color="red.400"
                  fontSize="sm"
                  marginLeft="8"
                  marginRight="2"
                  textAlign="right"
                >
                  {error.message}
                </Box>
              )}
              <Button
                colorScheme="red"
                flex="0 0 auto"
                onClick={() =>
                  mutate().catch((e) => {
                    /* Discard errors here; we'll show them in the UI! */
                  })
                }
                isLoading={loading}
              >
                Yes, remove permanently
              </Button>
            </ModalFooter>
          </ModalContent>
        </ModalOverlay>
      </Modal>
    </>
  );
}

const SWF_URL_PATTERN =
  /^https?:\/\/images\.neopets\.com\/cp\/(bio|items)\/swf\/(.+?)_([a-z0-9]+)\.swf$/;

function convertSwfUrlToPossibleManifestUrls(swfUrl) {
  const match = new URL(swfUrl, "http://images.neopets.com")
    .toString()
    .match(SWF_URL_PATTERN);
  if (!match) {
    throw new Error(`unexpected SWF URL format: ${JSON.stringify(swfUrl)}`);
  }

  const type = match[1];
  const folders = match[2];
  const hash = match[3];

  // TODO: There are a few potential manifest URLs in play! Long-term, we
  //       should get this from modeling data. But these are some good guesses!
  return [
    `http://images.neopets.com/cp/${type}/data/${folders}/manifest.json`,
    `http://images.neopets.com/cp/${type}/data/${folders}_${hash}/manifest.json`,
  ];
}

export default AppearanceLayerSupportModal;
