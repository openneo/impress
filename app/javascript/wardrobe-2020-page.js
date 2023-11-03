import React from "react";
import ReactDOM from "react-dom";

import { AppProvider, WardrobePage } from "./wardrobe-2020";

const rootNode = document.querySelector("#wardrobe-2020-root");
// TODO: Use the new React 18 APIs instead!
// eslint-disable-next-line react/no-deprecated
ReactDOM.render(
  <AppProvider>
    <WardrobePage />
  </AppProvider>,
  rootNode,
);
