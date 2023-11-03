import React from "react";
import ReactDOM from "react-dom";

import { AppProvider, ItemPageOutfitPreview } from "./wardrobe-2020";

const rootNode = document.querySelector("#outfit-preview-root");
const itemId = rootNode.getAttribute("data-item-id");
// TODO: Use the new React 18 APIs instead!
// eslint-disable-next-line react/no-deprecated
ReactDOM.render(
  <AppProvider>
    <ItemPageOutfitPreview itemId={itemId} />
  </AppProvider>,
  rootNode,
);
