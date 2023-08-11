import React from "react";
import ReactDOM from "react-dom";
import { loadErrorMessages, loadDevMessages } from "@apollo/client/dev";

import { AppProvider, WardrobePage } from "./wardrobe-2020";

// Use Apollo's error messages in development.
if (process.env["NODE_ENV"] === "development") {
  loadErrorMessages();
  loadDevMessages();
}

const rootNode = document.querySelector("#wardrobe-2020-root");
ReactDOM.render(
  <AppProvider>
    <WardrobePage />
  </AppProvider>,
  rootNode
);
