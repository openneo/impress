import React from "react";
import gql from "graphql-tag";
import { useQuery } from "@apollo/client";
import { ClassNames } from "@emotion/react";
import {
  Box,
  Button,
  Flex,
  Popover,
  PopoverArrow,
  PopoverContent,
  PopoverTrigger,
  Portal,
  Tab,
  Tabs,
  TabList,
  TabPanel,
  TabPanels,
  VisuallyHidden,
  useColorModeValue,
  useTheme,
  useToast,
  useToken,
} from "@chakra-ui/react";
import { loadable } from "../util";

import { petAppearanceFragment } from "../components/useOutfitAppearance";
import getVisibleLayers from "../components/getVisibleLayers";
import { OutfitLayers } from "../components/OutfitPreview";
import SupportOnly from "./support/SupportOnly";
import { useAltStylesForSpecies } from "../loaders/alt-styles";
import useSupport from "./support/useSupport";
import { useLocalStorage } from "../util";

// From https://twemoji.twitter.com/, thank you!
import twemojiSmile from "../images/twemoji/smile.svg";
import twemojiCry from "../images/twemoji/cry.svg";
import twemojiSick from "../images/twemoji/sick.svg";
import twemojiSunglasses from "../images/twemoji/sunglasses.svg";
import twemojiQuestion from "../images/twemoji/question.svg";
import twemojiMasc from "../images/twemoji/masc.svg";
import twemojiFem from "../images/twemoji/fem.svg";

const PosePickerSupport = loadable(() => import("./support/PosePickerSupport"));

const PosePickerSupportSwitch = loadable(() =>
  import("./support/PosePickerSupport").then((m) => m.PosePickerSupportSwitch),
);

/**
 * PosePicker shows the pet poses available on the current species/color, and
 * lets the user choose which want they want!
 *
 * NOTE: This component is memoized with React.memo. It's relatively expensive
 *       to re-render on every outfit change - the contents update even if the
 *       popover is closed! This makes wearing/unwearing items noticeably
 *       slower on lower-power devices.
 *
 *       So, instead of using `outfitState` like most components, we specify
 *       exactly which props we need, so that `React.memo` can see the changes
 *       that matter, and skip updates that don't.
 */
function PosePicker({
  speciesId,
  colorId,
  pose,
  appearanceId,
  dispatchToOutfit,
  onLockFocus,
  onUnlockFocus,
  ...props
}) {
  const initialFocusRef = React.useRef();
  const posesQuery = usePoses(speciesId, colorId, pose);
  const altStylesQuery = useAltStylesForSpecies(speciesId);
  const [isInSupportMode, setIsInSupportMode] = useLocalStorage(
    "DTIPosePickerIsInSupportMode",
    false,
  );
  const { isSupportUser } = useSupport();
  const toast = useToast();

  const loading = posesQuery.loading || altStylesQuery.loading;
  const error = posesQuery.error ?? altStylesQuery.error;
  const poseInfos = posesQuery.poseInfos;
  const altStyles = altStylesQuery.data ?? [];

  // Resize the Popover when we toggle support mode, because it probably will
  // affect the content size.
  React.useLayoutEffect(() => {
    // HACK: To trigger a Popover resize, we simulate a window resize event,
    //       because Popover listens for window resizes to reposition itself.
    //       I've also filed an issue requesting an official API!
    //       https://github.com/chakra-ui/chakra-ui/issues/1853
    window.dispatchEvent(new Event("resize"));
  }, [isInSupportMode]);

  // Generally, the app tries to never put us in an invalid pose state. But it
  // can happen with direct URL navigation, or pet loading when modeling isn't
  // updated! Let's do some recovery.
  const selectedPoseIsAvailable = Object.values(poseInfos).some(
    (pi) => pi.isSelected && pi.isAvailable,
  );
  const firstAvailablePose = Object.values(poseInfos).find(
    (pi) => pi.isAvailable,
  )?.pose;
  React.useEffect(() => {
    if (loading) {
      return;
    }

    if (!selectedPoseIsAvailable) {
      if (!firstAvailablePose) {
        // TODO: I suppose this error would fit better in SpeciesColorPicker!
        toast({
          status: "error",
          title: "Oops, we don't have data for this pet color!",
          description:
            "If it's new, this might be a modeling issue—try modeling it on " +
            "Classic DTI first. Sorry!",
          duration: null,
          isClosable: true,
        });
        return;
      }

      console.warn(
        `Pose ${pose} not found for speciesId=${speciesId}, ` +
          `colorId=${colorId}. Redirecting to pose ${firstAvailablePose}.`,
      );
      dispatchToOutfit({ type: "setPose", pose: firstAvailablePose });
    }
  }, [
    loading,
    selectedPoseIsAvailable,
    firstAvailablePose,
    speciesId,
    colorId,
    pose,
    toast,
    dispatchToOutfit,
  ]);

  if (loading) {
    return null;
  }

  // This is a low-stakes enough control, where enough pairs don't have data
  // anyway, that I think I want to just not draw attention to failures.
  if (error) {
    return null;
  }

  const numStandardPoses = Object.values(poseInfos).filter(
    (p) => p.isAvailable && STANDARD_POSES.includes(p.pose),
  ).length;

  const onChange = (e) => {
    dispatchToOutfit({ type: "setPose", pose: e.target.value });
  };

  return (
    <Popover
      placement="bottom-end"
      returnFocusOnClose
      onOpen={onLockFocus}
      onClose={onUnlockFocus}
      initialFocusRef={initialFocusRef}
      isLazy
      lazyBehavior="keepMounted"
    >
      {({ isOpen }) => (
        <>
          <PopoverTrigger>
            <PosePickerButton pose={pose} isOpen={isOpen} {...props} />
          </PopoverTrigger>
          <Portal>
            <PopoverContent>
              <Tabs size="sm" variant="soft-rounded">
                <TabPanels position="relative">
                  <TabPanel>
                    {isInSupportMode ? (
                      <PosePickerSupport
                        speciesId={speciesId}
                        colorId={colorId}
                        pose={pose}
                        appearanceId={appearanceId}
                        initialFocusRef={initialFocusRef}
                        dispatchToOutfit={dispatchToOutfit}
                      />
                    ) : (
                      <>
                        <PosePickerTable
                          poseInfos={poseInfos}
                          onChange={onChange}
                          initialFocusRef={initialFocusRef}
                        />
                        {numStandardPoses == 0 && (
                          <PosePickerEmptyExplanation />
                        )}
                      </>
                    )}
                    <SupportOnly>
                      <Box position="absolute" top="5" left="3">
                        <PosePickerSupportSwitch
                          isChecked={isInSupportMode}
                          onChange={(e) => setIsInSupportMode(e.target.checked)}
                        />
                      </Box>
                    </SupportOnly>
                  </TabPanel>
                  <TabPanel>
                    <StyleSelect altStyles={altStyles} />
                    <StyleExplanation />
                  </TabPanel>
                </TabPanels>
                <SupportOnly>
                  <TabList paddingX="2" paddingY="1">
                    <Tab width="50%">Expressions</Tab>
                    <Tab width="50%">Styles</Tab>
                  </TabList>
                </SupportOnly>
              </Tabs>
              <PopoverArrow />
            </PopoverContent>
          </Portal>
        </>
      )}
    </Popover>
  );
}

function PosePickerButton({ pose, isOpen, ...props }, ref) {
  const theme = useTheme();

  return (
    <ClassNames>
      {({ css, cx }) => (
        <Button
          variant="unstyled"
          boxShadow="md"
          d="flex"
          alignItems="center"
          justifyContent="center"
          _focus={{ borderColor: "gray.50" }}
          _hover={{ borderColor: "gray.50" }}
          outline="initial"
          fontSize="sm"
          fontWeight="normal"
          className={cx(
            css`
              border: 1px solid transparent !important;
              transition: border-color 0.2s !important;
              padding-inline: 0.75em;

              &:focus,
              &:hover,
              &.is-open {
                border-color: ${theme.colors.gray["50"]} !important;
              }

              &.is-open {
                border-width: 2px !important;
              }
            `,
            isOpen && "is-open",
          )}
          {...props}
          ref={ref}
        >
          <EmojiImage src={getIcon(pose)} alt="" />
          <SupportOnly>
            <Box width=".5em" />
            {getLabel(pose)}
          </SupportOnly>
        </Button>
      )}
    </ClassNames>
  );
}
PosePickerButton = React.forwardRef(PosePickerButton);

function PosePickerTable({ poseInfos, onChange, initialFocusRef }) {
  return (
    <Box display="flex" flexDirection="column" alignItems="center">
      <table width="100%">
        <thead>
          <tr>
            <th />
            <Cell as="th">
              <EmojiImage src={twemojiSmile} alt="Happy" />
            </Cell>
            <Cell as="th">
              <EmojiImage src={twemojiCry} alt="Sad" />
            </Cell>
            <Cell as="th">
              <EmojiImage src={twemojiSick} alt="Sick" />
            </Cell>
          </tr>
        </thead>
        <tbody>
          <tr>
            <Cell as="th">
              <EmojiImage src={twemojiMasc} alt="Masculine" />
            </Cell>
            <Cell as="td">
              <PoseOption
                poseInfo={poseInfos.happyMasc}
                onChange={onChange}
                inputRef={poseInfos.happyMasc.isSelected && initialFocusRef}
              />
            </Cell>
            <Cell as="td">
              <PoseOption
                poseInfo={poseInfos.sadMasc}
                onChange={onChange}
                inputRef={poseInfos.sadMasc.isSelected && initialFocusRef}
              />
            </Cell>
            <Cell as="td">
              <PoseOption
                poseInfo={poseInfos.sickMasc}
                onChange={onChange}
                inputRef={poseInfos.sickMasc.isSelected && initialFocusRef}
              />
            </Cell>
          </tr>
          <tr>
            <Cell as="th">
              <EmojiImage src={twemojiFem} alt="Feminine" />
            </Cell>
            <Cell as="td">
              <PoseOption
                poseInfo={poseInfos.happyFem}
                onChange={onChange}
                inputRef={poseInfos.happyFem.isSelected && initialFocusRef}
              />
            </Cell>
            <Cell as="td">
              <PoseOption
                poseInfo={poseInfos.sadFem}
                onChange={onChange}
                inputRef={poseInfos.sadFem.isSelected && initialFocusRef}
              />
            </Cell>
            <Cell as="td">
              <PoseOption
                poseInfo={poseInfos.sickFem}
                onChange={onChange}
                inputRef={poseInfos.sickFem.isSelected && initialFocusRef}
              />
            </Cell>
          </tr>
        </tbody>
      </table>
      {poseInfos.unconverted.isAvailable && (
        <PoseOption
          poseInfo={poseInfos.unconverted}
          onChange={onChange}
          inputRef={poseInfos.unconverted.isSelected && initialFocusRef}
          size="sm"
          label="Unconverted"
          marginTop="2"
        />
      )}
    </Box>
  );
}

function Cell({ children, as }) {
  const Tag = as;
  return (
    <Tag>
      <Flex justify="center" p="1">
        {children}
      </Flex>
    </Tag>
  );
}

const EMOTION_STRINGS = {
  HAPPY_MASC: "Happy",
  HAPPY_FEM: "Happy",
  SAD_MASC: "Sad",
  SAD_FEM: "Sad",
  SICK_MASC: "Sick",
  SICK_FEM: "Sick",
};

const GENDER_PRESENTATION_STRINGS = {
  HAPPY_MASC: "Masculine",
  SAD_MASC: "Masculine",
  SICK_MASC: "Masculine",
  HAPPY_FEM: "Feminine",
  SAD_FEM: "Feminine",
  SICK_FEM: "Feminine",
};

const STANDARD_POSES = Object.keys(EMOTION_STRINGS);

function PoseOption({
  poseInfo,
  onChange,
  inputRef,
  size = "md",
  label,
  ...otherProps
}) {
  const theme = useTheme();
  const genderPresentationStr = GENDER_PRESENTATION_STRINGS[poseInfo.pose];
  const emotionStr = EMOTION_STRINGS[poseInfo.pose];

  let poseName =
    poseInfo.pose === "UNCONVERTED"
      ? "Unconverted"
      : `${emotionStr} and ${genderPresentationStr}`;
  if (!poseInfo.isAvailable) {
    poseName += ` (not modeled yet)`;
  }

  const borderColor = useColorModeValue(
    theme.colors.green["600"],
    theme.colors.green["300"],
  );

  return (
    <ClassNames>
      {({ css, cx }) => (
        <Box
          as="label"
          cursor="pointer"
          display="flex"
          alignItems="center"
          borderColor={poseInfo.isSelected ? borderColor : "gray.400"}
          boxShadow={label ? "md" : "none"}
          borderWidth={label ? "1px" : "0"}
          borderRadius={label ? "full" : "0"}
          paddingRight={label ? "3" : "0"}
          onClick={(e) => {
            // HACK: We need the timeout to beat the popover's focus stealing!
            const input = e.currentTarget.querySelector("input");
            setTimeout(() => input.focus(), 0);
          }}
          {...otherProps}
        >
          <VisuallyHidden
            as="input"
            type="radio"
            aria-label={poseName}
            name="pose"
            value={poseInfo.pose}
            checked={poseInfo.isSelected}
            disabled={!poseInfo.isAvailable}
            onChange={onChange}
            ref={inputRef || null}
          />
          <Box
            aria-hidden
            borderRadius="full"
            boxShadow="md"
            overflow="hidden"
            width={size === "sm" ? "30px" : "50px"}
            height={size === "sm" ? "30px" : "50px"}
            title={
              poseInfo.isAvailable
                ? // A lil debug output, so that we can quickly identify glitched
                  // PetStates and manually mark them as glitched!
                  window.location.hostname.includes("localhost") &&
                  `#${poseInfo.id}`
                : "Not modeled yet"
            }
            position="relative"
            className={css`
              transform: scale(0.8);
              opacity: 0.8;
              transition: all 0.2s;

              input:checked + & {
                transform: scale(1);
                opacity: 1;
              }
            `}
          >
            <Box
              borderRadius="full"
              position="absolute"
              top="0"
              bottom="0"
              left="0"
              right="0"
              zIndex="2"
              className={cx(
                css`
                  border: 0px solid ${borderColor};
                  transition: border-width 0.2s;

                  &.not-available {
                    border-color: ${theme.colors.gray["500"]};
                    border-width: 1px;
                  }

                  input:checked + * & {
                    border-width: 1px;
                  }

                  input:focus + * & {
                    border-width: 3px;
                  }
                `,
                !poseInfo.isAvailable && "not-available",
              )}
            />
            {poseInfo.isAvailable ? (
              <Box
                width="100%"
                height="100%"
                transform={getTransform(poseInfo)}
              >
                <OutfitLayers visibleLayers={getVisibleLayers(poseInfo, [])} />
              </Box>
            ) : (
              <Flex align="center" justify="center" width="100%" height="100%">
                <EmojiImage src={twemojiQuestion} boxSize={24} />
              </Flex>
            )}
          </Box>
          {label && (
            <Box
              marginLeft="2"
              fontSize="xs"
              fontWeight={poseInfo.isSelected ? "bold" : "normal"}
            >
              {label}
            </Box>
          )}
        </Box>
      )}
    </ClassNames>
  );
}

function PosePickerEmptyExplanation() {
  return (
    <Box
      fontSize="xs"
      fontStyle="italic"
      textAlign="center"
      opacity="0.7"
      marginTop="2"
    >
      We're still working on labeling these! For now, we're just giving you one
      of the expressions we have.
    </Box>
  );
}

function StyleSelect({ altStyles }) {
  const [selectedStyleId, setSelectedStyleId] = React.useState(null);

  const defaultStyle = { id: null, adjectiveName: "Default" };

  return (
    <Flex
      as="form"
      direction="column"
      gap="2"
      maxHeight="40vh"
      padding="4px"
      overflow="auto"
    >
      <StyleOption
        altStyle={defaultStyle}
        checked={selectedStyleId == null}
        onChange={setSelectedStyleId}
      />
      {altStyles.map((altStyle) => (
        <StyleOption
          key={altStyle.id}
          altStyle={altStyle}
          checked={selectedStyleId === altStyle.id}
          onChange={setSelectedStyleId}
        />
      ))}
    </Flex>
  );
}

function StyleOption({ altStyle, checked, onChange }) {
  const theme = useTheme();
  const selectedBorderColor = useColorModeValue(
    theme.colors.green["600"],
    theme.colors.green["300"],
  );
  const outlineShadow = useToken("shadows", "outline");

  return (
    <ClassNames>
      {({ css, cx }) => (
        <Box
          as="label"
          cursor="pointer"
          onClick={(e) => {
            // HACK: We need the timeout to beat the popover's focus stealing!
            const input = e.currentTarget.querySelector("input");
            setTimeout(() => input.focus(), 0);
          }}
        >
          <VisuallyHidden
            as="input"
            type="radio"
            name="style"
            value={altStyle.id}
            checked={checked}
            onChange={(e) => onChange(altStyle.id)}
          />
          <Flex
            alignItems="center"
            gap="2"
            borderRadius="md"
            // HACK: Don't let the thumbnail image overlap the border
            paddingLeft="2px"
            paddingY="2px"
            className={cx(css`
              border: 2px solid transparent;
              opacity: 0.8;
              transition: all 0.2s;

              input:focus + & {
                box-shadow: ${outlineShadow};
              }

              input:checked + & {
                border-color: ${selectedBorderColor};
                opacity: 1;
                font-weight: bold;
              }
            `)}
          >
            {altStyle.thumbnailUrl ? (
              <Box
                as="img"
                src={altStyle.thumbnailUrl}
                alt="Item thumbnail"
                width="40px"
                height="40px"
                loading="lazy"
              />
            ) : (
              <Box width="40px" height="40px" />
            )}
            <Box width="2" />
            {altStyle.adjectiveName}
          </Flex>
        </Box>
      )}
    </ClassNames>
  );
}

function StyleExplanation() {
  return (
    <Box
      fontSize="xs"
      fontStyle="italic"
      textAlign="center"
      opacity="0.7"
      marginTop="2"
    >
      "Alt Styles" are special NC items that override the pet's usual appearance
      via the{" "}
      <Box
        as="a"
        href="https://www.neopets.com/stylingchamber/"
        target="_blank"
        textDecoration="underline"
      >
        Styling Chamber
      </Box>
      . The pet's color doesn't have to match.
      <SupportOnly>
        <br />
        WIP: Only Support staff see this tab for now! 💖
      </SupportOnly>
    </Box>
  );
}

function EmojiImage({ src, alt, boxSize = 16 }) {
  return <img src={src} alt={alt} width={boxSize} height={boxSize} />;
}

function usePoses(speciesId, colorId, selectedPose) {
  const { loading, error, data } = useQuery(
    gql`
      query PosePicker($speciesId: ID!, $colorId: ID!) {
        happyMasc: petAppearance(
          speciesId: $speciesId
          colorId: $colorId
          pose: HAPPY_MASC
        ) {
          ...PetAppearanceForPosePicker
        }
        sadMasc: petAppearance(
          speciesId: $speciesId
          colorId: $colorId
          pose: SAD_MASC
        ) {
          ...PetAppearanceForPosePicker
        }
        sickMasc: petAppearance(
          speciesId: $speciesId
          colorId: $colorId
          pose: SICK_MASC
        ) {
          ...PetAppearanceForPosePicker
        }
        happyFem: petAppearance(
          speciesId: $speciesId
          colorId: $colorId
          pose: HAPPY_FEM
        ) {
          ...PetAppearanceForPosePicker
        }
        sadFem: petAppearance(
          speciesId: $speciesId
          colorId: $colorId
          pose: SAD_FEM
        ) {
          ...PetAppearanceForPosePicker
        }
        sickFem: petAppearance(
          speciesId: $speciesId
          colorId: $colorId
          pose: SICK_FEM
        ) {
          ...PetAppearanceForPosePicker
        }
        unconverted: petAppearance(
          speciesId: $speciesId
          colorId: $colorId
          pose: UNCONVERTED
        ) {
          ...PetAppearanceForPosePicker
        }
        unknown: petAppearance(
          speciesId: $speciesId
          colorId: $colorId
          pose: UNKNOWN
        ) {
          ...PetAppearanceForPosePicker
        }
      }

      ${petAppearanceForPosePickerFragment}
    `,
    { variables: { speciesId, colorId }, onError: (e) => console.error(e) },
  );

  const poseInfos = {
    happyMasc: {
      ...data?.happyMasc,
      pose: "HAPPY_MASC",
      isAvailable: Boolean(data?.happyMasc),
      isSelected: selectedPose === "HAPPY_MASC",
    },
    sadMasc: {
      ...data?.sadMasc,
      pose: "SAD_MASC",
      isAvailable: Boolean(data?.sadMasc),
      isSelected: selectedPose === "SAD_MASC",
    },
    sickMasc: {
      ...data?.sickMasc,
      pose: "SICK_MASC",
      isAvailable: Boolean(data?.sickMasc),
      isSelected: selectedPose === "SICK_MASC",
    },
    happyFem: {
      ...data?.happyFem,
      pose: "HAPPY_FEM",
      isAvailable: Boolean(data?.happyFem),
      isSelected: selectedPose === "HAPPY_FEM",
    },
    sadFem: {
      ...data?.sadFem,
      pose: "SAD_FEM",
      isAvailable: Boolean(data?.sadFem),
      isSelected: selectedPose === "SAD_FEM",
    },
    sickFem: {
      ...data?.sickFem,
      pose: "SICK_FEM",
      isAvailable: Boolean(data?.sickFem),
      isSelected: selectedPose === "SICK_FEM",
    },
    unconverted: {
      ...data?.unconverted,
      pose: "UNCONVERTED",
      isAvailable: Boolean(data?.unconverted),
      isSelected: selectedPose === "UNCONVERTED",
    },
    unknown: {
      ...data?.unknown,
      pose: "UNKNOWN",
      isAvailable: Boolean(data?.unknown),
      isSelected: selectedPose === "UNKNOWN",
    },
  };

  return { loading, error, poseInfos };
}

function getIcon(pose) {
  if (["HAPPY_MASC", "HAPPY_FEM"].includes(pose)) {
    return twemojiSmile;
  } else if (["SAD_MASC", "SAD_FEM"].includes(pose)) {
    return twemojiCry;
  } else if (["SICK_MASC", "SICK_FEM"].includes(pose)) {
    return twemojiSick;
  } else if (pose === "UNCONVERTED") {
    return twemojiSunglasses;
  } else {
    return twemojiPaintbrush;
  }
}

function getLabel(pose) {
  if (pose === "HAPPY_MASC" || pose === "HAPPY_FEM") {
    return "Happy";
  } else if (pose === "SAD_MASC" || pose === "SAD_FEM") {
    return "Sad";
  } else if (pose === "SICK_MASC" || pose === "SICK_FEM") {
    return "Sick";
  } else if (pose === "UNCONVERTED") {
    return "Classic UC";
  } else {
    return "Default";
  }
}

function getTransform(poseInfo) {
  const { pose, bodyId } = poseInfo;
  if (pose === "UNCONVERTED") {
    return transformsByBodyId.default;
  }
  if (bodyId in transformsByBodyId) {
    return transformsByBodyId[bodyId];
  }
  return transformsByBodyId.default;
}

export const petAppearanceForPosePickerFragment = gql`
  fragment PetAppearanceForPosePicker on PetAppearance {
    id
    bodyId
    pose
    ...PetAppearanceForOutfitPreview
  }
  ${petAppearanceFragment}
`;

const transformsByBodyId = {
  93: "translate(-5px, 10px) scale(2.8)",
  106: "translate(-8px, 8px) scale(2.9)",
  47: "translate(-1px, 17px) scale(3)",
  84: "translate(-21px, 22px) scale(3.2)",
  146: "translate(2px, 15px) scale(3.3)",
  250: "translate(-14px, 28px) scale(3.4)",
  212: "translate(-4px, 8px) scale(2.9)",
  74: "translate(-26px, 30px) scale(3.0)",
  94: "translate(-4px, 8px) scale(3.1)",
  132: "translate(-14px, 18px) scale(3.0)",
  56: "translate(-7px, 24px) scale(2.9)",
  90: "translate(-16px, 20px) scale(3.5)",
  136: "translate(-11px, 18px) scale(3.0)",
  138: "translate(-14px, 26px) scale(3.5)",
  166: "translate(-13px, 24px) scale(3.1)",
  119: "translate(-6px, 29px) scale(3.1)",
  126: "translate(3px, 13px) scale(3.1)",
  67: "translate(2px, 27px) scale(3.4)",
  163: "translate(-7px, 16px) scale(3.1)",
  147: "translate(-2px, 15px) scale(3.0)",
  80: "translate(-2px, -17px) scale(3.0)",
  117: "translate(-14px, 16px) scale(3.6)",
  201: "translate(-16px, 16px) scale(3.2)",
  51: "translate(-2px, 6px) scale(3.2)",
  208: "translate(-3px, 6px) scale(3.7)",
  196: "translate(-7px, 19px) scale(5.2)",
  143: "translate(-16px, 20px) scale(3.5)",
  150: "translate(-3px, 24px) scale(3.2)",
  175: "translate(-9px, 15px) scale(3.4)",
  173: "translate(3px, 57px) scale(4.4)",
  199: "translate(-28px, 35px) scale(3.8)",
  52: "translate(-8px, 33px) scale(3.5)",
  109: "translate(-8px, -6px) scale(3.2)",
  134: "translate(-14px, 14px) scale(3.1)",
  95: "translate(-12px, 0px) scale(3.4)",
  96: "translate(6px, 23px) scale(3.3)",
  154: "translate(-20px, 25px) scale(3.6)",
  55: "translate(-16px, 28px) scale(4.0)",
  76: "translate(-8px, 11px) scale(3.0)",
  156: "translate(2px, 12px) scale(3.5)",
  78: "translate(-3px, 18px) scale(3.0)",
  191: "translate(-18px, 46px) scale(4.4)",
  187: "translate(-6px, 22px) scale(3.2)",
  46: "translate(-2px, 19px) scale(3.4)",
  178: "translate(-11px, 32px) scale(3.3)",
  100: "translate(-13px, 23px) scale(3.3)",
  130: "translate(-14px, 4px) scale(3.1)",
  188: "translate(-9px, 24px) scale(3.5)",
  257: "translate(-14px, 25px) scale(3.4)",
  206: "translate(-7px, 4px) scale(3.6)",
  101: "translate(-13px, 16px) scale(3.2)",
  68: "translate(-2px, 13px) scale(3.2)",
  182: "translate(-6px, 4px) scale(3.1)",
  180: "translate(-15px, 22px) scale(3.6)",
  306: "translate(1px, 14px) scale(3.1)",
  default: "scale(2.5)",
};

export default React.memo(PosePicker);
