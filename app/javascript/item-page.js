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

try {
  const tradeHangers = document.querySelector("#trade-hangers");
  const tradeSections = document.querySelectorAll("#trade-hangers p");
  for (const section of tradeSections) {
    const oneLine = parseFloat(getComputedStyle(section)['line-height']);
    const maxHeight = oneLine * 2;

    if (section.offsetHeight > maxHeight) {
      section.style.maxHeight = `${maxHeight}px`;
      section.setAttribute("data-overflows", "");
    }

    section.querySelector(".more")?.addEventListener("click", (event) => {
      section.setAttribute("data-showing-more", "");
      section.style.maxHeight = "none";
    });

    section.querySelector(".less")?.addEventListener("click", (event) => {
      section.removeAttribute("data-showing-more");
      section.style.maxHeight = `${maxHeight}px`;
    });
  }
} catch (error) {
  console.error("Error applying trade list more/less toggle", error);
}
