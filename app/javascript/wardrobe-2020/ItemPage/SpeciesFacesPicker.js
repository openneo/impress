import React from "react";
import { ClassNames } from "@emotion/react";
import {
  Box,
  Tooltip,
  useColorModeValue,
  useToken,
  Wrap,
  WrapItem,
  Flex,
} from "@chakra-ui/react";
import { WarningTwoIcon } from "@chakra-ui/icons";
import gql from "graphql-tag";
import { useQuery } from "@apollo/client";

function SpeciesFacesPicker({
  selectedSpeciesId,
  selectedColorId,
  compatibleBodies,
  couldProbablyModelMoreData,
  onChange,
  isLoading,
}) {
  // For basic colors (Blue, Green, Red, Yellow), we just use the hardcoded
  // data, which is part of the bundle and loads super-fast. For other colors,
  // we load in all the faces of that color, falling back to basic colors when
  // absent!
  //
  // TODO: Could we move this into our `build-cached-data` script, and just do
  //       the query all the time, and have Apollo happen to satisfy it fast?
  //       The semantics of returning our colorful random set could be weird…
  const selectedColorIsBasic = colorIsBasic(selectedColorId);
  const {
    loading: loadingGQL,
    error,
    data,
  } = useQuery(
    gql`
      query SpeciesFacesPicker($selectedColorId: ID!) {
        color(id: $selectedColorId) {
          id
          appliedToAllCompatibleSpecies {
            id
            neopetsImageHash
            species {
              id
            }
            body {
              id
            }
          }
        }
      }
    `,
    {
      variables: { selectedColorId },
      skip: selectedColorId == null || selectedColorIsBasic,
      onError: (e) => console.error(e),
    }
  );

  const allBodiesAreCompatible = compatibleBodies.some(
    (body) => body.representsAllBodies
  );
  const compatibleBodyIds = compatibleBodies.map((body) => body.id);

  const speciesFacesFromData = data?.color?.appliedToAllCompatibleSpecies || [];

  const allSpeciesFaces = DEFAULT_SPECIES_FACES.map((defaultSpeciesFace) => {
    const providedSpeciesFace = speciesFacesFromData.find(
      (f) => f.species.id === defaultSpeciesFace.speciesId
    );
    if (providedSpeciesFace) {
      return {
        ...defaultSpeciesFace,
        colorId: selectedColorId,
        bodyId: providedSpeciesFace.body.id,
        // If this species/color pair exists, but without an image hash, then
        // we want to provide a face so that it's enabled, but use the fallback
        // image even though it's wrong, so that it looks like _something_.
        neopetsImageHash:
          providedSpeciesFace.neopetsImageHash ||
          defaultSpeciesFace.neopetsImageHash,
      };
    } else {
      return defaultSpeciesFace;
    }
  });

  return (
    <Box>
      <Wrap spacing="0" justify="center">
        {allSpeciesFaces.map((speciesFace) => (
          <WrapItem key={speciesFace.speciesId}>
            <SpeciesFaceOption
              speciesId={speciesFace.speciesId}
              speciesName={speciesFace.speciesName}
              colorId={speciesFace.colorId}
              neopetsImageHash={speciesFace.neopetsImageHash}
              isSelected={speciesFace.speciesId === selectedSpeciesId}
              // If the face color doesn't match the current color, this is a
              // fallback face for an invalid species/color pair.
              isValid={
                speciesFace.colorId === selectedColorId || selectedColorIsBasic
              }
              bodyIsCompatible={
                allBodiesAreCompatible ||
                compatibleBodyIds.includes(speciesFace.bodyId)
              }
              couldProbablyModelMoreData={couldProbablyModelMoreData}
              onChange={onChange}
              isLoading={isLoading || loadingGQL}
            />
          </WrapItem>
        ))}
      </Wrap>
      {error && (
        <Flex
          color="yellow.500"
          fontSize="xs"
          marginTop="1"
          textAlign="center"
          width="100%"
          align="flex-start"
          justify="center"
        >
          <WarningTwoIcon marginTop="0.4em" marginRight="1" />
          <Box>
            Error loading this color's pet photos.
            <br />
            Check your connection and try again.
          </Box>
        </Flex>
      )}
    </Box>
  );
}
const SpeciesFaceOption = React.memo(
  ({
    speciesId,
    speciesName,
    colorId,
    neopetsImageHash,
    isSelected,
    bodyIsCompatible,
    isValid,
    couldProbablyModelMoreData,
    onChange,
    isLoading,
  }) => {
    const selectedBorderColor = useColorModeValue("green.600", "green.400");
    const selectedBackgroundColor = useColorModeValue("green.200", "green.600");
    const focusBorderColor = "blue.400";
    const focusBackgroundColor = "blue.100";
    const [
      selectedBorderColorValue,
      selectedBackgroundColorValue,
      focusBorderColorValue,
      focusBackgroundColorValue,
    ] = useToken("colors", [
      selectedBorderColor,
      selectedBackgroundColor,
      focusBorderColor,
      focusBackgroundColor,
    ]);
    const xlShadow = useToken("shadows", "xl");

    const [labelIsHovered, setLabelIsHovered] = React.useState(false);
    const [inputIsFocused, setInputIsFocused] = React.useState(false);

    const isDisabled = isLoading || !isValid || !bodyIsCompatible;
    const isHappy = isLoading || (isValid && bodyIsCompatible);
    const emotionId = isHappy ? "1" : "2";
    const cursor = isLoading ? "wait" : isDisabled ? "not-allowed" : "pointer";

    let disabledExplanation = null;
    if (isLoading) {
      // If we're still loading, don't try to explain anything yet!
    } else if (!isValid) {
      disabledExplanation = "(Can't be this color)";
    } else if (!bodyIsCompatible) {
      disabledExplanation = couldProbablyModelMoreData
        ? "(Item needs models)"
        : "(Not compatible)";
    }

    const tooltipLabel = (
      <div style={{ textAlign: "center" }}>
        {speciesName}
        {disabledExplanation && (
          <div style={{ fontStyle: "italic", fontSize: "0.75em" }}>
            {disabledExplanation}
          </div>
        )}
      </div>
    );

    // NOTE: Because we render quite a few of these, avoiding using Chakra
    //       elements like Box helps with render performance!
    return (
      <ClassNames>
        {({ css }) => (
          <DeferredTooltip
            label={tooltipLabel}
            placement="top"
            gutter={-10}
            // We track hover and focus state manually for the tooltip, so that
            // keyboard nav to switch between options causes the tooltip to
            // follow. (By default, the tooltip appears on the first tab focus,
            // but not when you _change_ options!)
            isOpen={labelIsHovered || inputIsFocused}
          >
            <label
              style={{ cursor }}
              onMouseEnter={() => setLabelIsHovered(true)}
              onMouseLeave={() => setLabelIsHovered(false)}
            >
              <input
                type="radio"
                aria-label={speciesName}
                name="species-faces-picker"
                value={speciesId}
                checked={isSelected}
                // It's possible to get this selected via the SpeciesColorPicker,
                // even if this would normally be disabled. If so, make this
                // option enabled, so keyboard users can focus and change it.
                disabled={isDisabled && !isSelected}
                onChange={() => onChange({ speciesId, colorId })}
                onFocus={() => setInputIsFocused(true)}
                onBlur={() => setInputIsFocused(false)}
                className={css`
                  /* Copied from Chakra's <VisuallyHidden /> */
                  border: 0px;
                  clip: rect(0px, 0px, 0px, 0px);
                  height: 1px;
                  width: 1px;
                  margin: -1px;
                  padding: 0px;
                  overflow: hidden;
                  white-space: nowrap;
                  position: absolute;
                `}
              />
              <div
                className={css`
                  overflow: hidden;
                  transition: all 0.2s;
                  position: relative;

                  input:checked + & {
                    background: ${selectedBackgroundColorValue};
                    border-radius: 6px;
                    box-shadow: ${xlShadow},
                      ${selectedBorderColorValue} 0 0 2px 2px;
                    transform: scale(1.2);
                    z-index: 1;
                  }

                  input:focus + & {
                    background: ${focusBackgroundColorValue};
                    box-shadow: ${xlShadow}, ${focusBorderColorValue} 0 0 0 3px;
                  }
                `}
              >
                <CrossFadeImage
                  src={`https://pets.neopets-asset-proxy.openneo.net/cp/${neopetsImageHash}/${emotionId}/1.png`}
                  srcSet={
                    `https://pets.neopets-asset-proxy.openneo.net/cp/${neopetsImageHash}/${emotionId}/1.png 1x, ` +
                    `https://pets.neopets-asset-proxy.openneo.net/cp/${neopetsImageHash}/${emotionId}/6.png 2x`
                  }
                  alt={speciesName}
                  width={55}
                  height={55}
                  data-is-loading={isLoading}
                  data-is-disabled={isDisabled}
                  className={css`
                    filter: saturate(90%);
                    opacity: 0.9;
                    transition: all 0.2s;

                    &[data-is-disabled="true"] {
                      filter: saturate(0%);
                      opacity: 0.6;
                    }

                    &[data-is-loading="true"] {
                      animation: 0.8s linear 0s infinite alternate none running
                        pulse;
                    }

                    input:checked + * &[data-body-is-disabled="false"] {
                      opacity: 1;
                      filter: saturate(110%);
                    }

                    input:checked + * &[data-body-is-disabled="true"] {
                      opacity: 0.85;
                    }

                    @keyframes pulse {
                      from {
                        opacity: 0.5;
                      }
                      to {
                        opacity: 1;
                      }
                    }

                    /* Alt text for when the image fails to load! We hide it
                     * while still loading though! */
                    font-size: 0.75rem;
                    text-align: center;
                    &:-moz-loading {
                      visibility: hidden;
                    }
                    &:-moz-broken {
                      padding: 0.5rem;
                    }
                  `}
                />
              </div>
            </label>
          </DeferredTooltip>
        )}
      </ClassNames>
    );
  }
);

/**
 * CrossFadeImage is like <img>, but listens for successful load events, and
 * fades from the previous image to the new image once it loads.
 *
 * We treat `src` as a unique key representing the image's identity, but we
 * also carry along the rest of the props during the fade, like `srcSet` and
 * `className`.
 */
function CrossFadeImage(incomingImageProps) {
  const [prevImageProps, setPrevImageProps] = React.useState(null);
  const [currentImageProps, setCurrentImageProps] = React.useState(null);

  const incomingImageIsCurrentImage =
    incomingImageProps.src === currentImageProps?.src;

  const onLoadNextImage = () => {
    setPrevImageProps(currentImageProps);
    setCurrentImageProps(incomingImageProps);
  };

  // The main trick to this component is using React's `key` feature! When
  // diffing the rendered tree, if React sees two nodes with the same `key`, it
  // treats them as the same node and makes the prop changes to match.
  //
  // We usually use this in `.map`, to make sure that adds/removes in a list
  // don't cause our children to shift around and swap their React state or DOM
  // nodes with each other.
  //
  // But here, we use `key` to get React to transition the same <img> DOM node
  // between 3 different states!
  //
  // The image starts its life as the last in the list, from
  // `incomingImageProps`: it's invisible, and still loading. We use its `src`
  // as the `key`.
  //
  // When it loads, we update the state so that this `key` now belongs to the
  // _second_ node, from `currentImageProps`. React will see this and make the
  // correct transition for us: it sets opacity to 0, sets z-index to 2,
  // removes aria-hidden, and removes the `onLoad` handler.
  //
  // Then, when another image is ready to show, we update the state so that
  // this key now belongs to the _first_ node, from `prevImageProps` (and the
  // second node is showing something new). React sees this, and makes the
  // transition back to invisibility, but without the `onLoad` handler this
  // time! (And transitions the current image into view, like it did for this
  // one.)
  //
  // Finally, when yet _another_ image is ready to show, we stop rendering any
  // images with this key anymore, and so React unmounts the image entirely.
  //
  // Thanks, React, for handling our multiple overlapping transitions through
  // this little state machine! This could have been a LOT harder to write,
  // whew!
  return (
    <ClassNames>
      {({ css }) => (
        <div
          className={css`
            display: grid;
            grid-template-areas: "shared-overlapping-area";
            isolation: isolate; /* Avoid z-index conflicts with parent! */

            > div {
              grid-area: shared-overlapping-area;
              transition: opacity 0.2s;
            }
          `}
        >
          {prevImageProps && (
            <div
              key={prevImageProps.src}
              className={css`
                z-index: 3;
                opacity: 0;
              `}
            >
              {/* eslint-disable-next-line jsx-a11y/alt-text, @next/next/no-img-element */}
              <img {...prevImageProps} aria-hidden />
            </div>
          )}

          {currentImageProps && (
            <div
              key={currentImageProps.src}
              className={css`
                z-index: 2;
                opacity: 1;
              `}
            >
              {/* eslint-disable-next-line jsx-a11y/alt-text, @next/next/no-img-element */}
              <img
                {...currentImageProps}
                // If the current image _is_ the incoming image, we'll allow
                // new props to come in and affect it. But if it's a new image
                // incoming, we want to stick to the last props the current
                // image had! (This matters for e.g. `bodyIsCompatible`
                // becoming true in `SpeciesFaceOption` and restoring color,
                // before the new color's image loads in.)
                {...(incomingImageIsCurrentImage ? incomingImageProps : {})}
              />
            </div>
          )}

          {!incomingImageIsCurrentImage && (
            <div
              key={incomingImageProps.src}
              className={css`
                z-index: 1;
                opacity: 0;
              `}
            >
              {/* eslint-disable-next-line jsx-a11y/alt-text, @next/next/no-img-element */}
              <img
                {...incomingImageProps}
                aria-hidden
                onLoad={onLoadNextImage}
              />
            </div>
          )}
        </div>
      )}
    </ClassNames>
  );
}
/**
 * DeferredTooltip is like Chakra's <Tooltip />, but it waits until `isOpen` is
 * true before mounting it, and unmounts it after closing.
 *
 * This can drastically improve render performance when there are lots of
 * tooltip targets to re-render… but it comes with some limitations, like the
 * extra requirement to control `isOpen`, and some additional DOM structure!
 */
function DeferredTooltip({ children, isOpen, ...props }) {
  const [shouldShowTooltip, setShouldShowToolip] = React.useState(isOpen);

  React.useEffect(() => {
    if (isOpen) {
      setShouldShowToolip(true);
    } else {
      const timeoutId = setTimeout(() => setShouldShowToolip(false), 500);
      return () => clearTimeout(timeoutId);
    }
  }, [isOpen]);

  return (
    <ClassNames>
      {({ css }) => (
        <div
          className={css`
            position: relative;
          `}
        >
          {children}
          {shouldShowTooltip && (
            <Tooltip isOpen={isOpen} {...props}>
              <div
                className={css`
                  position: absolute;
                  top: 0;
                  left: 0;
                  right: 0;
                  bottom: 0;
                  pointer-events: none;
                `}
              />
            </Tooltip>
          )}
        </div>
      )}
    </ClassNames>
  );
}

// HACK: I'm just hardcoding all this, rather than connecting up to the
//       database and adding a loading state. Tbh I'm not sure it's a good idea
//       to load this dynamically until we have SSR to make it come in fast!
//       And it's not so bad if this gets out of sync with the database,
//       because the SpeciesColorPicker will still be usable!
const colors = { BLUE: "8", RED: "61", GREEN: "34", YELLOW: "84" };

export function colorIsBasic(colorId) {
  return ["8", "34", "61", "84"].includes(colorId);
}

const DEFAULT_SPECIES_FACES = [
  {
    speciesName: "Acara",
    speciesId: "1",
    colorId: colors.GREEN,
    bodyId: "93",
    neopetsImageHash: "obxdjm88",
  },
  {
    speciesName: "Aisha",
    speciesId: "2",
    colorId: colors.BLUE,
    bodyId: "106",
    neopetsImageHash: "n9ozx4z5",
  },
  {
    speciesName: "Blumaroo",
    speciesId: "3",
    colorId: colors.YELLOW,
    bodyId: "47",
    neopetsImageHash: "kfonqhdc",
  },
  {
    speciesName: "Bori",
    speciesId: "4",
    colorId: colors.YELLOW,
    bodyId: "84",
    neopetsImageHash: "sc2hhvhn",
  },
  {
    speciesName: "Bruce",
    speciesId: "5",
    colorId: colors.YELLOW,
    bodyId: "146",
    neopetsImageHash: "wqz8xn4t",
  },
  {
    speciesName: "Buzz",
    speciesId: "6",
    colorId: colors.YELLOW,
    bodyId: "250",
    neopetsImageHash: "jc9klfxm",
  },
  {
    speciesName: "Chia",
    speciesId: "7",
    colorId: colors.RED,
    bodyId: "212",
    neopetsImageHash: "4lrb4n3f",
  },
  {
    speciesName: "Chomby",
    speciesId: "8",
    colorId: colors.YELLOW,
    bodyId: "74",
    neopetsImageHash: "bdml26md",
  },
  {
    speciesName: "Cybunny",
    speciesId: "9",
    colorId: colors.GREEN,
    bodyId: "94",
    neopetsImageHash: "xl6msllv",
  },
  {
    speciesName: "Draik",
    speciesId: "10",
    colorId: colors.YELLOW,
    bodyId: "132",
    neopetsImageHash: "bob39shq",
  },
  {
    speciesName: "Elephante",
    speciesId: "11",
    colorId: colors.RED,
    bodyId: "56",
    neopetsImageHash: "jhhhbrww",
  },
  {
    speciesName: "Eyrie",
    speciesId: "12",
    colorId: colors.RED,
    bodyId: "90",
    neopetsImageHash: "6kngmhvs",
  },
  {
    speciesName: "Flotsam",
    speciesId: "13",
    colorId: colors.GREEN,
    bodyId: "136",
    neopetsImageHash: "47vt32x2",
  },
  {
    speciesName: "Gelert",
    speciesId: "14",
    colorId: colors.YELLOW,
    bodyId: "138",
    neopetsImageHash: "5nrd2lvd",
  },
  {
    speciesName: "Gnorbu",
    speciesId: "15",
    colorId: colors.BLUE,
    bodyId: "166",
    neopetsImageHash: "6c275jcg",
  },
  {
    speciesName: "Grarrl",
    speciesId: "16",
    colorId: colors.BLUE,
    bodyId: "119",
    neopetsImageHash: "j7q65fv4",
  },
  {
    speciesName: "Grundo",
    speciesId: "17",
    colorId: colors.GREEN,
    bodyId: "126",
    neopetsImageHash: "5xn4kjf8",
  },
  {
    speciesName: "Hissi",
    speciesId: "18",
    colorId: colors.RED,
    bodyId: "67",
    neopetsImageHash: "jsfvcqwt",
  },
  {
    speciesName: "Ixi",
    speciesId: "19",
    colorId: colors.GREEN,
    bodyId: "163",
    neopetsImageHash: "w32r74vo",
  },
  {
    speciesName: "Jetsam",
    speciesId: "20",
    colorId: colors.YELLOW,
    bodyId: "147",
    neopetsImageHash: "kz43rnld",
  },
  {
    speciesName: "Jubjub",
    speciesId: "21",
    colorId: colors.GREEN,
    bodyId: "80",
    neopetsImageHash: "m267j935",
  },
  {
    speciesName: "Kacheek",
    speciesId: "22",
    colorId: colors.YELLOW,
    bodyId: "117",
    neopetsImageHash: "4gsrb59g",
  },
  {
    speciesName: "Kau",
    speciesId: "23",
    colorId: colors.BLUE,
    bodyId: "201",
    neopetsImageHash: "ktlxmrtr",
  },
  {
    speciesName: "Kiko",
    speciesId: "24",
    colorId: colors.GREEN,
    bodyId: "51",
    neopetsImageHash: "42j5q3zx",
  },
  {
    speciesName: "Koi",
    speciesId: "25",
    colorId: colors.GREEN,
    bodyId: "208",
    neopetsImageHash: "ncfn87wk",
  },
  {
    speciesName: "Korbat",
    speciesId: "26",
    colorId: colors.RED,
    bodyId: "196",
    neopetsImageHash: "omx9c876",
  },
  {
    speciesName: "Kougra",
    speciesId: "27",
    colorId: colors.BLUE,
    bodyId: "143",
    neopetsImageHash: "rfsbh59t",
  },
  {
    speciesName: "Krawk",
    speciesId: "28",
    colorId: colors.BLUE,
    bodyId: "150",
    neopetsImageHash: "hxgsm5d4",
  },
  {
    speciesName: "Kyrii",
    speciesId: "29",
    colorId: colors.YELLOW,
    bodyId: "175",
    neopetsImageHash: "blxmjgbk",
  },
  {
    speciesName: "Lenny",
    speciesId: "30",
    colorId: colors.YELLOW,
    bodyId: "173",
    neopetsImageHash: "8r94jhfq",
  },
  {
    speciesName: "Lupe",
    speciesId: "31",
    colorId: colors.YELLOW,
    bodyId: "199",
    neopetsImageHash: "z42535zh",
  },
  {
    speciesName: "Lutari",
    speciesId: "32",
    colorId: colors.BLUE,
    bodyId: "52",
    neopetsImageHash: "qgg6z8s7",
  },
  {
    speciesName: "Meerca",
    speciesId: "33",
    colorId: colors.YELLOW,
    bodyId: "109",
    neopetsImageHash: "kk2nn2jr",
  },
  {
    speciesName: "Moehog",
    speciesId: "34",
    colorId: colors.GREEN,
    bodyId: "134",
    neopetsImageHash: "jgkoro5z",
  },
  {
    speciesName: "Mynci",
    speciesId: "35",
    colorId: colors.BLUE,
    bodyId: "95",
    neopetsImageHash: "xwlo9657",
  },
  {
    speciesName: "Nimmo",
    speciesId: "36",
    colorId: colors.BLUE,
    bodyId: "96",
    neopetsImageHash: "bx7fho8x",
  },
  {
    speciesName: "Ogrin",
    speciesId: "37",
    colorId: colors.YELLOW,
    bodyId: "154",
    neopetsImageHash: "rjzmx24v",
  },
  {
    speciesName: "Peophin",
    speciesId: "38",
    colorId: colors.RED,
    bodyId: "55",
    neopetsImageHash: "kokc52kh",
  },
  {
    speciesName: "Poogle",
    speciesId: "39",
    colorId: colors.GREEN,
    bodyId: "76",
    neopetsImageHash: "fw6lvf3c",
  },
  {
    speciesName: "Pteri",
    speciesId: "40",
    colorId: colors.RED,
    bodyId: "156",
    neopetsImageHash: "tjhwbro3",
  },
  {
    speciesName: "Quiggle",
    speciesId: "41",
    colorId: colors.YELLOW,
    bodyId: "78",
    neopetsImageHash: "jdto7mj4",
  },
  {
    speciesName: "Ruki",
    speciesId: "42",
    colorId: colors.BLUE,
    bodyId: "191",
    neopetsImageHash: "qsgbm5f6",
  },
  {
    speciesName: "Scorchio",
    speciesId: "43",
    colorId: colors.RED,
    bodyId: "187",
    neopetsImageHash: "hkjoncsx",
  },
  {
    speciesName: "Shoyru",
    speciesId: "44",
    colorId: colors.YELLOW,
    bodyId: "46",
    neopetsImageHash: "mmvn4tkg",
  },
  {
    speciesName: "Skeith",
    speciesId: "45",
    colorId: colors.RED,
    bodyId: "178",
    neopetsImageHash: "fc4cxk3t",
  },
  {
    speciesName: "Techo",
    speciesId: "46",
    colorId: colors.YELLOW,
    bodyId: "100",
    neopetsImageHash: "84gvowmj",
  },
  {
    speciesName: "Tonu",
    speciesId: "47",
    colorId: colors.BLUE,
    bodyId: "130",
    neopetsImageHash: "jd433863",
  },
  {
    speciesName: "Tuskaninny",
    speciesId: "48",
    colorId: colors.YELLOW,
    bodyId: "188",
    neopetsImageHash: "q39wn6vq",
  },
  {
    speciesName: "Uni",
    speciesId: "49",
    colorId: colors.GREEN,
    bodyId: "257",
    neopetsImageHash: "njzvoflw",
  },
  {
    speciesName: "Usul",
    speciesId: "50",
    colorId: colors.RED,
    bodyId: "206",
    neopetsImageHash: "rox4mgh5",
  },
  {
    speciesName: "Vandagyre",
    speciesId: "55",
    colorId: colors.YELLOW,
    bodyId: "306",
    neopetsImageHash: "xkntzsww",
  },
  {
    speciesName: "Wocky",
    speciesId: "51",
    colorId: colors.YELLOW,
    bodyId: "101",
    neopetsImageHash: "dnr2kj4b",
  },
  {
    speciesName: "Xweetok",
    speciesId: "52",
    colorId: colors.RED,
    bodyId: "68",
    neopetsImageHash: "tdkqr2b6",
  },
  {
    speciesName: "Yurble",
    speciesId: "53",
    colorId: colors.RED,
    bodyId: "182",
    neopetsImageHash: "h95cs547",
  },
  {
    speciesName: "Zafara",
    speciesId: "54",
    colorId: colors.BLUE,
    bodyId: "180",
    neopetsImageHash: "x8c57g2l",
  },
];

export default SpeciesFacesPicker;
