import React from "react";
import {
  Drawer,
  DrawerBody,
  DrawerContent,
  DrawerCloseButton,
  DrawerOverlay,
  useBreakpointValue,
} from "@chakra-ui/react";

import { ItemPageContent } from "./ItemPage";

function ItemPageDrawer({ item, isOpen, onClose }) {
  const placement = useBreakpointValue({ base: "bottom", lg: "right" });

  return (
    <Drawer placement={placement} size="md" isOpen={isOpen} onClose={onClose}>
      <DrawerOverlay>
        <DrawerContent>
          <DrawerCloseButton />
          <DrawerBody>
            <ItemPageContent itemId={item.id} isEmbedded />
          </DrawerBody>
        </DrawerContent>
      </DrawerOverlay>
    </Drawer>
  );
}

export default ItemPageDrawer;
