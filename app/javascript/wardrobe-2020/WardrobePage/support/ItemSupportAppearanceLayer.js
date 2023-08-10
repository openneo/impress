import * as React from "react";
import { ClassNames } from "@emotion/react";
import { Box, useColorModeValue, useDisclosure } from "@chakra-ui/react";
import { EditIcon } from "@chakra-ui/icons";
import AppearanceLayerSupportModal from "./AppearanceLayerSupportModal";
import { OutfitLayers } from "../../components/OutfitPreview";

function ItemSupportAppearanceLayer({
  item,
  itemLayer,
  biologyLayers,
  outfitState,
}) {
  const { isOpen, onOpen, onClose } = useDisclosure();

  const iconButtonBgColor = useColorModeValue("green.100", "green.300");
  const iconButtonColor = useColorModeValue("green.800", "gray.900");

  return (
    <ClassNames>
      {({ css }) => (
        <Box
          as="button"
          width="150px"
          textAlign="center"
          fontSize="xs"
          onClick={onOpen}
        >
          <Box
            width="150px"
            height="150px"
            marginBottom="1"
            boxShadow="md"
            borderRadius="md"
            position="relative"
          >
            <OutfitLayers visibleLayers={[...biologyLayers, itemLayer]} />
            <Box
              className={css`
                opacity: 0;
                transition: opacity 0.2s;

                button:hover &,
                button:focus & {
                  opacity: 1;
                }

                /* On touch devices, always show the icon, to clarify that this is
             * an interactable object! (Whereas I expect other devices to
             * discover things by exploratory hover or focus!) */
                @media (hover: none) {
                  opacity: 1;
                }
              `}
              background={iconButtonBgColor}
              color={iconButtonColor}
              borderRadius="full"
              boxShadow="sm"
              position="absolute"
              bottom="2"
              right="2"
              padding="2"
              alignItems="center"
              justifyContent="center"
              width="32px"
              height="32px"
            >
              <EditIcon
                boxSize="16px"
                position="relative"
                top="-2px"
                right="-1px"
              />
            </Box>
          </Box>
          <Box>
            <Box as="span" fontWeight="700">
              {itemLayer.zone.label}
            </Box>{" "}
            <Box as="span" fontWeight="600">
              (Zone {itemLayer.zone.id})
            </Box>
          </Box>
          <Box>Neopets ID: {itemLayer.remoteId}</Box>
          <Box>DTI ID: {itemLayer.id}</Box>
          <AppearanceLayerSupportModal
            item={item}
            layer={itemLayer}
            outfitState={outfitState}
            isOpen={isOpen}
            onClose={onClose}
          />
        </Box>
      )}
    </ClassNames>
  );
}

export default ItemSupportAppearanceLayer;
