import React from "react";
import { ClassNames } from "@emotion/react";
import {
  Box,
  Button,
  DarkMode,
  Flex,
  FormControl,
  FormHelperText,
  FormLabel,
  HStack,
  IconButton,
  ListItem,
  Menu,
  MenuItem,
  MenuList,
  Popover,
  PopoverArrow,
  PopoverBody,
  PopoverContent,
  PopoverTrigger,
  Portal,
  Stack,
  Switch,
  Tooltip,
  UnorderedList,
  useClipboard,
  useToast,
} from "@chakra-ui/react";
import {
  ArrowBackIcon,
  CheckIcon,
  ChevronDownIcon,
  DownloadIcon,
  LinkIcon,
  SettingsIcon,
} from "@chakra-ui/icons";
import { MdPause, MdPlayArrow } from "react-icons/md";

import { getBestImageUrlForLayer } from "../components/OutfitPreview";
import HTML5Badge, { layerUsesHTML5 } from "../components/HTML5Badge";
import PosePicker from "./PosePicker";
import SpeciesColorPicker from "../components/SpeciesColorPicker";
import { loadImage, loadable, useLocalStorage } from "../util";
import useCurrentUser from "../components/useCurrentUser";
import useOutfitAppearance from "../components/useOutfitAppearance";
import OutfitKnownGlitchesBadge from "./OutfitKnownGlitchesBadge";
import usePreferArchive from "../components/usePreferArchive";

const LoadableLayersInfoModal = loadable(() => import("./LayersInfoModal"));

/**
 * OutfitControls is the set of controls layered over the outfit preview, to
 * control things like species/color and sharing links!
 */
function OutfitControls({
  outfitState,
  dispatchToOutfit,
  showAnimationControls,
  appearance,
}) {
  const [focusIsLocked, setFocusIsLocked] = React.useState(false);
  const onLockFocus = React.useCallback(
    () => setFocusIsLocked(true),
    [setFocusIsLocked]
  );
  const onUnlockFocus = React.useCallback(
    () => setFocusIsLocked(false),
    [setFocusIsLocked]
  );

  // HACK: As of 1.0.0-rc.0, Chakra's `toast` function rebuilds unnecessarily,
  //       which triggers unnecessary rebuilds of the `onSpeciesColorChange`
  //       callback, which causes the `React.memo` on `SpeciesColorPicker` to
  //       fail, which harms performance. But it seems to work just fine if we
  //       hold onto the first copy of the function we get! :/
  const _toast = useToast();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const toast = React.useMemo(() => _toast, []);

  const onSpeciesColorChange = React.useCallback(
    (species, color, isValid, closestPose) => {
      if (isValid) {
        dispatchToOutfit({
          type: "setSpeciesAndColor",
          speciesId: species.id,
          colorId: color.id,
          pose: closestPose,
        });
      } else {
        // NOTE: This shouldn't be possible to trigger, because the
        //       `stateMustAlwaysBeValid` prop should prevent it. But we have
        //       it as a fallback, just in case!
        toast({
          title: `We haven't seen a ${color.name} ${species.name} before! 😓`,
          status: "warning",
        });
      }
    },
    [dispatchToOutfit, toast]
  );

  const maybeUnlockFocus = (e) => {
    // We lock focus when a touch-device user taps the area. When they tap
    // empty space, we treat that as a toggle and release the focus lock.
    if (e.target === e.currentTarget) {
      onUnlockFocus();
    }
  };

  return (
    <ClassNames>
      {({ css, cx }) => (
        <OutfitControlsContextMenu outfitState={outfitState}>
          <Box
            role="group"
            pos="absolute"
            left="0"
            right="0"
            top="0"
            bottom="0"
            height="100%" // Required for Safari to size the grid correctly
            padding={{ base: 2, lg: 6 }}
            display="grid"
            overflow="auto"
            gridTemplateAreas={`"back play-pause sharing"
                          "space space space"
                          "picker picker picker"`}
            gridTemplateRows="auto minmax(1rem, 1fr) auto"
            className={cx(
              css`
                opacity: 0;
                transition: opacity 0.2s;

                &:focus-within,
                &.focus-is-locked {
                  opacity: 1;
                }

                /* Ignore simulated hovers, only reveal for _real_ hovers. This helps
           * us avoid state conflicts with the focus-lock from clicks. */
                @media (hover: hover) {
                  &:hover {
                    opacity: 1;
                  }
                }
              `,
              focusIsLocked && "focus-is-locked"
            )}
            onClickCapture={(e) => {
              const opacity = parseFloat(
                getComputedStyle(e.currentTarget).opacity
              );
              if (opacity < 0.5) {
                // If the controls aren't visible right now, then clicks on them are
                // probably accidental. Ignore them! (We prevent default to block
                // built-in behaviors like link nav, and we stop propagation to block
                // our own custom click handlers. I don't know if I can prevent the
                // select clicks though?)
                e.preventDefault();
                e.stopPropagation();

                // We also show the controls, by locking focus. We'll undo this when
                // the user taps elsewhere (because it will trigger a blur event from
                // our child components), in `maybeUnlockFocus`.
                setFocusIsLocked(true);
              }
            }}
            data-test-id="wardrobe-outfit-controls"
          >
            <Box gridArea="back" onClick={maybeUnlockFocus}>
              <BackButton outfitState={outfitState} />
            </Box>

            <Flex
              gridArea="play-pause"
              // HACK: Better visual centering with other controls
              paddingTop="0.3rem"
              direction="column"
              align="center"
            >
              {showAnimationControls && <PlayPauseButton />}
              <Box height="2" />
              <HStack spacing="2" align="center" justify="center">
                <OutfitHTML5Badge appearance={appearance} />
                <OutfitKnownGlitchesBadge appearance={appearance} />
                <SettingsButton
                  onLockFocus={onLockFocus}
                  onUnlockFocus={onUnlockFocus}
                />
              </HStack>
            </Flex>
            <Stack
              gridArea="sharing"
              alignSelf="flex-end"
              spacing={{ base: "2", lg: "4" }}
              align="flex-end"
              onClick={maybeUnlockFocus}
            >
              <Box>
                <DownloadButton outfitState={outfitState} />
              </Box>
              <Box>
                <CopyLinkButton outfitState={outfitState} />
              </Box>
            </Stack>
            <Box gridArea="space" onClick={maybeUnlockFocus} />
            {outfitState.speciesId && outfitState.colorId && (
              <Flex
                gridArea="picker"
                justify="center"
                onClick={maybeUnlockFocus}
              >
                {/**
                 * We try to center the species/color picker, but the left spacer will
                 * shrink more than the pose picker container if we run out of space!
                 */}
                <Flex
                  flex="1 1 0"
                  paddingRight="3"
                  align="center"
                  justify="flex-end"
                />
                <Box flex="0 0 auto">
                  <DarkMode>
                    <SpeciesColorPicker
                      speciesId={outfitState.speciesId}
                      colorId={outfitState.colorId}
                      idealPose={outfitState.pose}
                      onChange={onSpeciesColorChange}
                      stateMustAlwaysBeValid
                      speciesTestId="wardrobe-species-picker"
                      colorTestId="wardrobe-color-picker"
                    />
                  </DarkMode>
                </Box>
                <Flex flex="1 1 0" align="center" pl="2">
                  <PosePicker
                    speciesId={outfitState.speciesId}
                    colorId={outfitState.colorId}
                    pose={outfitState.pose}
                    appearanceId={outfitState.appearanceId}
                    dispatchToOutfit={dispatchToOutfit}
                    onLockFocus={onLockFocus}
                    onUnlockFocus={onUnlockFocus}
                    data-test-id="wardrobe-pose-picker"
                  />
                </Flex>
              </Flex>
            )}
          </Box>
        </OutfitControlsContextMenu>
      )}
    </ClassNames>
  );
}

function OutfitControlsContextMenu({ outfitState, children }) {
  // NOTE: We track these separately, rather than in one atomic state object,
  // because I want to still keep the menu in the right position when it's
  // animating itself closed!
  const [isOpen, setIsOpen] = React.useState(false);
  const [position, setPosition] = React.useState({ x: 0, y: 0 });

  const [layersInfoModalIsOpen, setLayersInfoModalIsOpen] =
    React.useState(false);

  const { visibleLayers } = useOutfitAppearance(outfitState);
  const [downloadImageUrl, prepareDownload] =
    useDownloadableImage(visibleLayers);

  return (
    <Box
      onContextMenuCapture={(e) => {
        setIsOpen(true);
        setPosition({ x: e.pageX, y: e.pageY });
        e.preventDefault();
      }}
    >
      {children}
      <Menu isOpen={isOpen} onClose={() => setIsOpen(false)}>
        <Portal>
          <MenuList position="absolute" left={position.x} top={position.y}>
            <MenuItem
              icon={<DownloadIcon />}
              as="a"
              // eslint-disable-next-line no-script-url
              href={downloadImageUrl || "#"}
              onClick={(e) => {
                if (!downloadImageUrl) {
                  e.preventDefault();
                }
              }}
              download={(outfitState.name || "Outfit") + ".png"}
              onMouseEnter={prepareDownload}
              onFocus={prepareDownload}
              cursor={!downloadImageUrl && "wait"}
            >
              Download
            </MenuItem>
            <MenuItem
              icon={<LinkIcon />}
              onClick={() => setLayersInfoModalIsOpen(true)}
            >
              Layers (SWF, PNG)
            </MenuItem>
          </MenuList>
        </Portal>
      </Menu>
      <LoadableLayersInfoModal
        isOpen={layersInfoModalIsOpen}
        onClose={() => setLayersInfoModalIsOpen(false)}
        visibleLayers={visibleLayers}
      />
    </Box>
  );
}

function OutfitHTML5Badge({ appearance }) {
  const petIsUsingHTML5 =
    appearance.petAppearance?.layers.every(layerUsesHTML5);

  const itemsNotUsingHTML5 = appearance.items.filter((item) =>
    item.appearance.layers.some((l) => !layerUsesHTML5(l))
  );
  itemsNotUsingHTML5.sort((a, b) => a.name.localeCompare(b.name));

  const usesHTML5 = petIsUsingHTML5 && itemsNotUsingHTML5.length === 0;

  let tooltipLabel;
  if (usesHTML5) {
    tooltipLabel = (
      <>This outfit is converted to HTML5, and ready to use on Neopets.com!</>
    );
  } else {
    tooltipLabel = (
      <Box>
        <Box as="p">
          This outfit isn't converted to HTML5 yet, so it might not appear in
          Neopets.com customization yet. Once it's ready, it could look a bit
          different than our temporary preview here. It might even be animated!
        </Box>
        {!petIsUsingHTML5 && (
          <Box as="p" marginTop="1em" fontWeight="bold">
            This pet is not yet converted.
          </Box>
        )}
        {itemsNotUsingHTML5.length > 0 && (
          <>
            <Box as="header" marginTop="1em" fontWeight="bold">
              The following items aren't yet converted:
            </Box>
            <UnorderedList>
              {itemsNotUsingHTML5.map((item) => (
                <ListItem key={item.id}>{item.name}</ListItem>
              ))}
            </UnorderedList>
          </>
        )}
      </Box>
    );
  }

  return (
    <HTML5Badge
      usesHTML5={usesHTML5}
      isLoading={appearance.loading}
      tooltipLabel={tooltipLabel}
    />
  );
}

/**
 * BackButton takes you back home, or to Your Outfits if this outfit is yours.
 */
function BackButton({ outfitState }) {
  const currentUser = useCurrentUser();
  const outfitBelongsToCurrentUser =
    outfitState.creator && outfitState.creator.id === currentUser.id;

  return (
    <ControlButton
      as="a"
      href={outfitBelongsToCurrentUser ? "/your-outfits" : "/"}
      icon={<ArrowBackIcon />}
      aria-label="Leave this outfit"
      d="inline-flex" // Not sure why <a> requires this to style right! ^^`
      data-test-id="wardrobe-nav-back-button"
    />
  );
}

/**
 * DownloadButton downloads the outfit as an image!
 */
function DownloadButton({ outfitState }) {
  const { visibleLayers } = useOutfitAppearance(outfitState);

  const [downloadImageUrl, prepareDownload] =
    useDownloadableImage(visibleLayers);

  return (
    <Tooltip label="Download" placement="left">
      <Box>
        <ControlButton
          icon={<DownloadIcon />}
          aria-label="Download"
          as="a"
          // eslint-disable-next-line no-script-url
          href={downloadImageUrl || "#"}
          onClick={(e) => {
            if (!downloadImageUrl) {
              e.preventDefault();
            }
          }}
          download={(outfitState.name || "Outfit") + ".png"}
          onMouseEnter={prepareDownload}
          onFocus={prepareDownload}
          cursor={!downloadImageUrl && "wait"}
        />
      </Box>
    </Tooltip>
  );
}

/**
 * CopyLinkButton copies the outfit URL to the clipboard!
 */
function CopyLinkButton({ outfitState }) {
  const { onCopy, hasCopied } = useClipboard(outfitState.url);

  return (
    <Tooltip label={hasCopied ? "Copied!" : "Copy link"} placement="left">
      <Box>
        <ControlButton
          icon={hasCopied ? <CheckIcon /> : <LinkIcon />}
          aria-label="Copy link"
          onClick={onCopy}
        />
      </Box>
    </Tooltip>
  );
}

function PlayPauseButton() {
  const [isPaused, setIsPaused] = useLocalStorage("DTIOutfitIsPaused", true);

  // We show an intro animation if this mounts while paused. Whereas if we're
  // not paused, we initialize as if we had already finished.
  const [blinkInState, setBlinkInState] = React.useState(
    isPaused ? { type: "ready" } : { type: "done" }
  );
  const buttonRef = React.useRef(null);

  React.useLayoutEffect(() => {
    if (blinkInState.type === "ready" && buttonRef.current) {
      setBlinkInState({
        type: "started",
        position: {
          left: buttonRef.current.offsetLeft,
          top: buttonRef.current.offsetTop,
        },
      });
    }
  }, [blinkInState, setBlinkInState]);

  return (
    <ClassNames>
      {({ css }) => (
        <>
          <PlayPauseButtonContent
            isPaused={isPaused}
            setIsPaused={setIsPaused}
            ref={buttonRef}
          />
          {blinkInState.type === "started" && (
            <Portal>
              <PlayPauseButtonContent
                isPaused={isPaused}
                setIsPaused={setIsPaused}
                position="absolute"
                left={blinkInState.position.left}
                top={blinkInState.position.top}
                backgroundColor="gray.600"
                borderColor="gray.50"
                color="gray.50"
                onAnimationEnd={() => setBlinkInState({ type: "done" })}
                // Don't disrupt the hover state of the controls! (And the button
                // doesn't seem to click correctly, not sure why, but instead of
                // debugging I'm adding this :p)
                pointerEvents="none"
                className={css`
                  @keyframes fade-in-out {
                    0% {
                      opacity: 0;
                    }

                    10% {
                      opacity: 1;
                    }

                    90% {
                      opacity: 1;
                    }

                    100% {
                      opacity: 0;
                    }
                  }

                  opacity: 0;
                  animation: fade-in-out 2s;
                `}
              />
            </Portal>
          )}
        </>
      )}
    </ClassNames>
  );
}

const PlayPauseButtonContent = React.forwardRef(
  ({ isPaused, setIsPaused, ...props }, ref) => {
    return (
      <TranslucentButton
        ref={ref}
        leftIcon={isPaused ? <MdPause /> : <MdPlayArrow />}
        onClick={() => setIsPaused(!isPaused)}
        {...props}
      >
        {isPaused ? <>Paused</> : <>Playing</>}
      </TranslucentButton>
    );
  }
);

function SettingsButton({ onLockFocus, onUnlockFocus }) {
  return (
    <Popover onOpen={onLockFocus} onClose={onUnlockFocus}>
      <PopoverTrigger>
        <TranslucentButton size="xs" aria-label="Settings">
          <SettingsIcon />
          <Box width="1" />
          <ChevronDownIcon />
        </TranslucentButton>
      </PopoverTrigger>
      <Portal>
        <PopoverContent width="25ch">
          <PopoverArrow />
          <PopoverBody>
            <HiResModeSetting />
          </PopoverBody>
        </PopoverContent>
      </Portal>
    </Popover>
  );
}

function HiResModeSetting() {
  const [hiResMode, setHiResMode] = useLocalStorage("DTIHiResMode", false);
  const [preferArchive, setPreferArchive] = usePreferArchive();

  return (
    <Box>
      <FormControl>
        <Flex>
          <Box>
            <FormLabel htmlFor="hi-res-mode-setting" fontSize="sm" margin="0">
              Hi-res mode (SVG)
            </FormLabel>
            <FormHelperText marginTop="0" fontSize="xs">
              Crisper at higher resolutions, but not always accurate
            </FormHelperText>
          </Box>
          <Box width="2" />
          <Switch
            id="hi-res-mode-setting"
            size="sm"
            marginTop="0.1rem"
            isChecked={hiResMode}
            onChange={(e) => setHiResMode(e.target.checked)}
          />
        </Flex>
      </FormControl>
      <Box height="2" />
      <FormControl>
        <Flex>
          <Box>
            <FormLabel
              htmlFor="prefer-archive-setting"
              fontSize="sm"
              margin="0"
            >
              Use DTI's image archive
            </FormLabel>
            <FormHelperText marginTop="0" fontSize="xs">
              Turn this on when images.neopets.com is slow!
            </FormHelperText>
          </Box>
          <Box width="2" />
          <Switch
            id="prefer-archive-setting"
            size="sm"
            marginTop="0.1rem"
            isChecked={preferArchive ?? false}
            onChange={(e) => setPreferArchive(e.target.checked)}
          />
        </Flex>
      </FormControl>
    </Box>
  );
}

const TranslucentButton = React.forwardRef(({ children, ...props }, ref) => {
  return (
    <Button
      ref={ref}
      size="sm"
      color="gray.100"
      variant="outline"
      borderColor="gray.200"
      borderRadius="full"
      backgroundColor="blackAlpha.600"
      boxShadow="md"
      _hover={{
        backgroundColor: "gray.600",
        borderColor: "gray.50",
        color: "gray.50",
      }}
      _focus={{
        backgroundColor: "gray.600",
        borderColor: "gray.50",
        color: "gray.50",
      }}
      {...props}
    >
      {children}
    </Button>
  );
});

/**
 * ControlButton is a UI helper to render the cute round buttons we use in
 * OutfitControls!
 */
function ControlButton({ icon, "aria-label": ariaLabel, ...props }) {
  return (
    <IconButton
      icon={icon}
      aria-label={ariaLabel}
      isRound
      variant="unstyled"
      backgroundColor="gray.600"
      color="gray.50"
      boxShadow="md"
      d="flex"
      alignItems="center"
      justifyContent="center"
      transition="backgroundColor 0.2s"
      _focus={{ backgroundColor: "gray.500" }}
      _hover={{ backgroundColor: "gray.500" }}
      outline="initial"
      {...props}
    />
  );
}

/**
 * useDownloadableImage loads the image data and generates the downloadable
 * image URL.
 */
function useDownloadableImage(visibleLayers) {
  const [hiResMode] = useLocalStorage("DTIHiResMode", false);
  const [preferArchive] = usePreferArchive();

  const [downloadImageUrl, setDownloadImageUrl] = React.useState(null);
  const [preparedForLayerIds, setPreparedForLayerIds] = React.useState([]);
  const toast = useToast();

  const prepareDownload = React.useCallback(async () => {
    // Skip if the current image URL is already correct for these layers.
    const layerIds = visibleLayers.map((l) => l.id);
    if (layerIds.join(",") === preparedForLayerIds.join(",")) {
      return;
    }

    // Skip if there are no layers. (This probably means we're still loading!)
    if (layerIds.length === 0) {
      return;
    }

    setDownloadImageUrl(null);

    // NOTE: You could argue that we may as well just always use PNGs here,
    //       regardless of hi-res mode… but using the same src will help both
    //       performance (can use cached SVG), and predictability (image will
    //       look like what you see here).
    const imagePromises = visibleLayers.map((layer) =>
      loadImage(getBestImageUrlForLayer(layer, { hiResMode }), {
        crossOrigin: "anonymous",
        preferArchive,
      })
    );

    let images;
    try {
      images = await Promise.all(imagePromises);
    } catch (e) {
      console.error("Error building downloadable image", e);
      toast({
        status: "error",
        title: "Oops, sorry, we couldn't download the image!",
        description:
          "Check your connection, then reload the page and try again.",
      });
      return;
    }

    const canvas = document.createElement("canvas");
    const context = canvas.getContext("2d");
    canvas.width = 600;
    canvas.height = 600;

    for (const image of images) {
      context.drawImage(image, 0, 0);
    }

    console.debug(
      "Generated image for download",
      layerIds,
      canvas.toDataURL("image/png")
    );
    setDownloadImageUrl(canvas.toDataURL("image/png"));
    setPreparedForLayerIds(layerIds);
  }, [preparedForLayerIds, visibleLayers, toast, hiResMode, preferArchive]);

  return [downloadImageUrl, prepareDownload];
}

export default OutfitControls;
