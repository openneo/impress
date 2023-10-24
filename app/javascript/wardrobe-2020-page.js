import React from "react";
import ReactDOM from "react-dom";

import { AppProvider, WardrobePage } from "./wardrobe-2020";

const rootNode = document.querySelector("#wardrobe-2020-root");
ReactDOM.render(
  <AppProvider>
    <WardrobePage />
  </AppProvider>,
  rootNode,
);
