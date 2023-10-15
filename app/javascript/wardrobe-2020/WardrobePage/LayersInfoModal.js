import React from "react";
import {
  Box,
  Button,
  Modal,
  ModalBody,
  ModalCloseButton,
  ModalContent,
  ModalHeader,
  ModalOverlay,
  Table,
  Tbody,
  Td,
  Th,
  Thead,
  Tr,
} from "@chakra-ui/react";

function LayersInfoModal({ isOpen, onClose, visibleLayers }) {
  return (
    <Modal isOpen={isOpen} onClose={onClose} size="xl">
      <ModalOverlay>
        <ModalContent maxWidth="800px">
          <ModalHeader>Outfit layers</ModalHeader>
          <ModalCloseButton />
          <ModalBody>
            <LayerTable layers={visibleLayers} />
          </ModalBody>
        </ModalContent>
      </ModalOverlay>
    </Modal>
  );
}

function LayerTable({ layers }) {
  return (
    <Table>
      <Thead>
        <Tr>
          <Th>Preview</Th>
          <Th>DTI ID</Th>
          <Th>Zone</Th>
          <Th>Links</Th>
        </Tr>
      </Thead>
      <Tbody>
        {layers.map((layer) => (
          <LayerTableRow key={layer.id} layer={layer} />
        ))}
      </Tbody>
    </Table>
  );
}

function LayerTableRow({ layer, ...props }) {
  return (
    <Tr {...props}>
      <Td>
        <Box
          as="img"
          src={layer.imageUrl}
          width="60px"
          height="60px"
          boxShadow="md"
        />
      </Td>
      <Td>{layer.id}</Td>
      <Td>{layer.zone.label}</Td>
      <Td>
        <Box display="flex" gap=".5em">
          {layer.imageUrl && (
            <Button as="a" href={layer.imageUrl} target="_blank" size="sm">
              PNG
            </Button>
          )}
          {layer.swfUrl && (
            <Button as="a" href={layer.swfUrl} size="sm" download>
              SWF
            </Button>
          )}
          {layer.svgUrl && (
            <Button as="a" href={layer.svgUrl} target="_blank" size="sm">
              SVG
            </Button>
          )}
        </Box>
      </Td>
    </Tr>
  );
}

export default LayersInfoModal;
