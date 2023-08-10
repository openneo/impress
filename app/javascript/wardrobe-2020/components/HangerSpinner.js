import * as React from "react";
import { ClassNames } from "@emotion/react";
import { Box, useColorModeValue } from "@chakra-ui/react";
import { createIcon } from "@chakra-ui/icons";

const HangerIcon = createIcon({
  displayName: "HangerIcon",

  // https://www.svgrepo.com/svg/108090/clothes-hanger
  viewBox: "0 0 473 473",
  path: (
    <path
      fill="currentColor"
      d="M451.426,315.003c-0.517-0.344-1.855-0.641-2.41-0.889l-201.09-88.884v-28.879c38.25-4.6,57.136-29.835,57.136-62.28c0-35.926-25.283-63.026-59.345-63.026c-35.763,0-65.771,29.481-65.771,64.384c0,6.005,4.973,10.882,10.978,10.882c1.788,0,3.452-0.535,4.934-1.291c3.519-1.808,6.024-5.365,6.024-9.591c0-22.702,20.674-42.62,44.217-42.62c22.003,0,37.982,17.356,37.982,41.262c0,23.523-19.011,41.262-44.925,41.262c-6.005,0-10.356,4.877-10.356,10.882v21.267v21.353c0,0.21-0.421,0.383-0.401,0.593L35.61,320.55C7.181,330.792-2.554,354.095,0.554,371.881c3.194,18.293,18.704,30.074,38.795,30.074H422.26c23.782,0,42.438-12.307,48.683-32.942C477.11,348.683,469.078,326.766,451.426,315.003z M450.115,364.031c-3.452,11.427-13.607,18.8-27.846,18.8H39.349c-9.725,0-16.104-5.394-17.5-13.368c-1.587-9.104,4.265-22.032,21.831-28.42l199.531-94.583l196.844,87.65C449.303,340.717,453.434,353.072,450.115,364.031z"
    />
  ),
});

function HangerSpinner({ size = "md", ...props }) {
  const boxSize = { sm: "32px", md: "48px" }[size];
  const color = useColorModeValue("green.500", "green.300");

  return (
    <ClassNames>
      {({ css }) => (
        <Box
          className={css`
            /*
              Adapted from animate.css "swing". We spend 75% of the time swinging,
              then 25% of the time pausing before the next loop.

              We use this animation for folks who are okay with dizzy-ish motion.
              For reduced motion, we use a pulse-fade instead.
            */
            @keyframes swing {
              15% {
                transform: rotate3d(0, 0, 1, 15deg);
              }

              30% {
                transform: rotate3d(0, 0, 1, -10deg);
              }

              45% {
                transform: rotate3d(0, 0, 1, 5deg);
              }

              60% {
                transform: rotate3d(0, 0, 1, -5deg);
              }

              75% {
                transform: rotate3d(0, 0, 1, 0deg);
              }

              100% {
                transform: rotate3d(0, 0, 1, 0deg);
              }
            }

            /*
              A homebrew fade-pulse animation. We use this for folks who don't
              like motion. It's an important accessibility thing!
            */
            @keyframes fade-pulse {
              0% {
                opacity: 0.2;
              }

              50% {
                opacity: 1;
              }

              100% {
                opacity: 0.2;
              }
            }

            @media (prefers-reduced-motion: no-preference) {
              animation: 1.2s infinite swing;
              transform-origin: top center;
            }

            @media (prefers-reduced-motion: reduce) {
              animation: 1.6s infinite fade-pulse;
            }
          `}
          {...props}
        >
          <HangerIcon boxSize={boxSize} color={color} transition="color 0.2s" />
        </Box>
      )}
    </ClassNames>
  );
}

export default HangerSpinner;
