import React from "react";
import gql from "graphql-tag";
import { useQuery } from "@apollo/client";
import { ClassNames } from "@emotion/react";
import {
	Box,
	Button,
	Flex,
	Input,
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
	useBreakpointValue,
	useColorModeValue,
	useTheme,
	useToast,
	useToken,
} from "@chakra-ui/react";
import { ChevronDownIcon, WarningTwoIcon } from "@chakra-ui/icons";
import { loadable, safeImageUrl } from "../util";

import { petAppearanceFragment } from "../components/useOutfitAppearance";
import getVisibleLayers from "../components/getVisibleLayers";
import { OutfitLayers } from "../components/OutfitPreview";
import SupportOnly from "./support/SupportOnly";
import { useAltStylesForSpecies } from "../loaders/alt-styles";
import { useLocalStorage } from "../util";

// From https://twemoji.twitter.com/, thank you!
import twemojiSmile from "../images/twemoji/smile.svg";
import twemojiCry from "../images/twemoji/cry.svg";
import twemojiSick from "../images/twemoji/sick.svg";
import twemojiSunglasses from "../images/twemoji/sunglasses.svg";
import twemojiQuestion from "../images/twemoji/question.svg";
import twemojiMasc from "../images/twemoji/masc.svg";
import twemojiFem from "../images/twemoji/fem.svg";
import twemojiHourglass from "../images/twemoji/hourglass.svg";

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
	altStyleId,
	appearanceId,
	dispatchToOutfit,
	onPreviewAltStyle,
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
	const toast = useToast();

	const loading = posesQuery.loading || altStylesQuery.isLoading;
	const error = posesQuery.error ?? altStylesQuery.error;
	const poseInfos = posesQuery.poseInfos;
	const altStyles = altStylesQuery.data ?? [];

	const [isOpen, setIsOpen] = React.useState(false);
	const [tabIndex, setTabIndex] = React.useState(0);

	const altStyle = altStyles.find((s) => s.id === altStyleId);

	const placement = useBreakpointValue({ base: "bottom-end", md: "top-end" });

	React.useEffect(() => {
		// While the popover is open, don't change which tab is open.
		if (isOpen) {
			return;
		}

		// Otherwise, set the tab to Styles if we're wearing an Alt Style, or
		// Expressions if we're not.
		setTabIndex(altStyle != null ? 1 : 0);
	}, [altStyle, isOpen]);

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

	// NOTE: This needs to be stable, so the memoized tiles in `StyleSelect`
	//       don't all re-render whenever we do.
	const onChangeStyle = React.useCallback(
		(altStyleId) => dispatchToOutfit({ type: "setStyle", altStyleId }),
		[dispatchToOutfit],
	);

	// This is a low-stakes enough control, where enough pairs don't have data
	// anyway, that I think I want to just not draw attention to failures.
	if (error) {
		return null;
	}

	const numStandardPoses = Object.values(poseInfos).filter(
		(p) => p.isAvailable && STANDARD_POSES.includes(p.pose),
	).length;

	const onChangePose = (e) => {
		dispatchToOutfit({ type: "setPose", pose: e.target.value });
	};

	return (
		<Popover
			placement={placement}
			returnFocusOnClose
			onOpen={() => {
				setIsOpen(true);
				onLockFocus();
			}}
			onClose={() => {
				setIsOpen(false);
				onUnlockFocus();
			}}
			initialFocusRef={initialFocusRef}
			isLazy
			lazyBehavior="keepMounted"
		>
			{() => (
				<>
					<PopoverTrigger>
						<PosePickerButton
							pose={pose}
							altStyle={altStyle}
							isOpen={isOpen}
							loading={loading}
							{...props}
						/>
					</PopoverTrigger>
					<Portal>
						<PopoverContent>
							<Tabs
								size="sm"
								variant="soft-rounded"
								display="flex"
								flexDirection={{ base: "column", md: "column-reverse" }}
								paddingY="2"
								gap="2"
								index={tabIndex}
								onChange={setTabIndex}
							>
								<TabList paddingX="2" paddingY="0">
									<Tab width="50%">Expressions</Tab>
									<Tab width="50%">Styles</Tab>
								</TabList>
								<TabPanels position="relative">
									<TabPanel paddingX="4" paddingY="0">
										{isInSupportMode ? (
											<PosePickerSupport
												speciesId={speciesId}
												colorId={colorId}
												pose={pose}
												appearanceId={appearanceId}
												initialFocusRef={
													tabIndex === 0 ? initialFocusRef : null
												}
												dispatchToOutfit={dispatchToOutfit}
											/>
										) : (
											<>
												<PosePickerTable
													poseInfos={poseInfos}
													onChange={onChangePose}
													initialFocusRef={
														tabIndex === 0 ? initialFocusRef : null
													}
												/>
												{numStandardPoses == 0 && (
													<PosePickerEmptyExplanation />
												)}
											</>
										)}
										<SupportOnly>
											<Box position="absolute" top="1" left="3">
												<PosePickerSupportSwitch
													isChecked={isInSupportMode}
													onChange={(e) => setIsInSupportMode(e.target.checked)}
												/>
											</Box>
										</SupportOnly>
									</TabPanel>
									<TabPanel paddingX="4" paddingY="0">
										<StyleSelect
											selectedStyleId={altStyleId}
											altStyles={altStyles}
											petColorId={colorId}
											isShowing={isOpen && tabIndex === 1}
											onChange={onChangeStyle}
											onPreview={onPreviewAltStyle}
											initialFocusRef={tabIndex === 1 ? initialFocusRef : null}
										/>
									</TabPanel>
								</TabPanels>
							</Tabs>
							<PopoverArrow />
						</PopoverContent>
					</Portal>
				</>
			)}
		</Popover>
	);
}

const PosePickerButton = React.forwardRef(
	({ pose, altStyle, isOpen, loading, ...props }, ref) => {
		const theme = useTheme();

		const icon = altStyle != null ? twemojiSunglasses : getIcon(pose);
		const label = altStyle != null ? getStyleLabel(altStyle) : getLabel(pose);

		return (
			<ClassNames>
				{({ css, cx }) => (
					<Button
						variant="unstyled"
						textShadow={`${theme.colors.blackAlpha["700"]} 0 1px 2px`}
						d="flex"
						alignItems="center"
						justifyContent="center"
						_focus={{ borderColor: "gray.50" }}
						_hover={{ borderColor: "gray.50" }}
						outline="initial"
						fontSize="sm"
						fontWeight="normal"
						minWidth="12ch"
						disabled={loading}
						className={cx(
							css`
              border: 1px solid transparent !important;
              color: ${theme.colors.gray["100"]};
              cursor: ${loading ? "wait" : "pointer"} !important;
              transition:
                color 0.2s,
                background: 0.2s,
                border-color 0.2s !important;
              padding-left: 0.75em;
              padding-right: 0.5em;

              &:hover,
              &.is-open {
                border-color: ${theme.colors.gray["50"]} !important;
                color: ${theme.colors.gray["50"]};
                background: ${theme.colors.blackAlpha["600"]};
                text-shadow: transparent 0 1px 2px;
              }

              &:focus {
                border-color: ${theme.colors.gray["50"]} !important;
                box-shadow: ${theme.shadows.outline};
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
						<EmojiImage src={icon} alt="Style" />
						<Box overflow="hidden" textOverflow="ellipsis" marginX=".5em">
							{label}
						</Box>
						<ChevronDownIcon />
					</Button>
				)}
			</ClassNames>
		);
	},
);

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
				<Flex
					align="center"
					justify="center"
					gap="1"
					marginTop="2"
					marginBottom="2"
				>
					<PoseOption
						poseInfo={poseInfos.unconverted}
						onChange={onChange}
						inputRef={poseInfos.unconverted.isSelected && initialFocusRef}
						size="sm"
						label="Retired UC"
					/>
					<RetiredUCWarning isSelected={poseInfos.unconverted.isSelected} />
				</Flex>
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

function RetiredUCWarning({ isSelected }) {
	return (
		<Popover placement="right" trigger="hover">
			<PopoverTrigger>
				<Box
					as="button"
					tabIndex="0"
					aria-label="Warning"
					cursor="help"
					lineHeight="1"
					opacity={isSelected ? "1" : "0.75"}
					transform={isSelected ? "scale(1)" : "scale(0.8)"}
					color={isSelected ? "yellow.500" : "inherit"}
					transition="all 0.2s"
					padding="1"
				>
					<WarningTwoIcon />
				</Box>
			</PopoverTrigger>
			<PopoverContent
				background="blackAlpha.800"
				borderColor="blackAlpha.900"
				color="white"
				padding="2"
				fontSize="sm"
			>
				"Unconverted" pets are no longer available on Neopets.com, and have been
				replaced with the very similar Styles feature. We're just keeping this
				as an archive!
			</PopoverContent>
		</Popover>
	);
}

// How long the mouse rests on a style before we preview it on the pet. Short
// enough to feel live, long enough that sweeping across the grid doesn't load
// every style along the way.
const STYLE_PREVIEW_DELAY_MS = 200;

/**
 * StyleSelect is a grid of the styles available for this species, as pictures
 * of the pet itself, grouped by color.
 *
 * We lead with pictures rather than names, because there can be 100+ styles
 * for a species, and how a style looks is the whole point of it. (It also
 * means styles we haven't named yet are just as easy to pick as the others!)
 *
 * Resting the mouse on a style previews it on the pet, via `onPreview`. The
 * rule for that is simple: the preview follows the mouse, and *anything else*
 * the user does here (picking a style, typing in the filter, leaving the grid,
 * leaving this tab) ends it.
 */
function StyleSelect({
	selectedStyleId,
	altStyles,
	petColorId,
	isShowing,
	onChange,
	onPreview,
	initialFocusRef,
}) {
	const [query, setQuery] = React.useState("");

	// The style the mouse is currently over, to name it in the caption.
	// `undefined` means none; `null` means the "Default" option.
	const [hoveredStyleId, setHoveredStyleId] = React.useState(undefined);

	const groups = React.useMemo(
		() => groupAltStylesByColor(altStyles, { query, petColorId }),
		[altStyles, query, petColorId],
	);

	const previewTimeoutRef = React.useRef(null);
	const isShowingRef = React.useRef(isShowing);
	isShowingRef.current = isShowing;

	const endHover = React.useCallback(() => {
		setHoveredStyleId(undefined);
		clearTimeout(previewTimeoutRef.current);
		onPreview?.(undefined);
	}, [onPreview]);

	const startHover = React.useCallback(
		(e, altStyleId) => {
			// Touch devices fire these too, but there the "hover" would stick after
			// the tap. Tapping selects the style anyway, so skip it. (We also skip
			// it if we're on our way out, e.g. during the popover's fade.)
			if (e.pointerType !== "mouse" || !isShowingRef.current) {
				return;
			}

			// Previewing a style can mean loading new item layers, so we wait for
			// the mouse to settle before asking for it.
			setHoveredStyleId(altStyleId);
			clearTimeout(previewTimeoutRef.current);
			previewTimeoutRef.current = setTimeout(() => {
				if (isShowingRef.current) {
					onPreview?.(altStyleId);
				}
			}, STYLE_PREVIEW_DELAY_MS);
		},
		[onPreview],
	);

	// Picking a style ends the preview, so that the pet shows what's actually
	// selected. (This matters for the keyboard: arrow keys change the selection
	// while the mouse might still be resting on some other style.)
	const changeStyle = React.useCallback(
		(altStyleId) => {
			endHover();
			onChange(altStyleId);
		},
		[endHover, onChange],
	);

	// We won't get a pointer event if the grid goes away under the mouse (the
	// popover closes, the user switches tabs by keyboard, or we unmount), so
	// end the preview ourselves.
	React.useEffect(() => {
		if (!isShowing) {
			endHover();
		}
	}, [isShowing, endHover]);
	React.useEffect(() => endHover, [endHover]);

	const captionStyleId =
		hoveredStyleId !== undefined ? hoveredStyleId : selectedStyleId;
	const captionStyle = altStyles.find((s) => s.id === captionStyleId) ?? null;

	const groupHeaderBackground = useColorModeValue("white", "gray.700");

	return (
		<Flex
			as="form"
			direction="column"
			gap="2"
			onSubmit={(e) => e.preventDefault()}
		>
			<Input
				type="search"
				size="sm"
				borderRadius="md"
				placeholder={`Filter ${altStyles.length} styles…`}
				aria-label="Filter styles"
				value={query}
				onChange={(e) => {
					// The style under the mouse might be about to leave the grid.
					endHover();
					setQuery(e.target.value);
				}}
			/>
			<Box
				maxHeight={{ base: "40vh", md: "18rem" }}
				// Room for the focus ring, which would otherwise be clipped.
				padding="4px"
				overflow="auto"
				onPointerLeave={endHover}
				data-style-scroll-container="true"
			>
				{matchesDefaultStyle(query) && (
					<Box marginBottom="2">
						<StyleOption
							altStyle={null}
							checked={selectedStyleId == null}
							onChange={changeStyle}
							onHover={startHover}
							inputRef={selectedStyleId == null ? initialFocusRef : null}
							description="No style: your pet's regular look"
						/>
					</Box>
				)}
				{groups.map((group) => (
					<Box key={group.colorId} role="group" aria-label={group.colorName}>
						<Flex
							position="sticky"
							// Cover the scroll box's padding too, or tiles peek out above.
							top="-4px"
							zIndex="1"
							background={groupHeaderBackground}
							align="baseline"
							justify="space-between"
							gap="2"
							fontSize="xs"
							paddingY="1"
						>
							<Box fontWeight="bold">
								{group.colorName}
								{group.isPetColor && (
									<Box as="span" fontWeight="normal" opacity="0.7">
										{" "}
										· your pet's color
									</Box>
								)}
							</Box>
							<Box flex="0 0 auto" opacity="0.7">
								{group.altStyles.length}{" "}
								{group.altStyles.length === 1 ? "style" : "styles"}
							</Box>
						</Flex>
						<Box
							display="grid"
							gridTemplateColumns="repeat(auto-fill, minmax(48px, 1fr))"
							gap="1"
							marginBottom="2"
						>
							{group.altStyles.map((altStyle) => (
								<StyleOption
									key={altStyle.id}
									altStyle={altStyle}
									checked={selectedStyleId === altStyle.id}
									onChange={changeStyle}
									onHover={startHover}
									inputRef={
										selectedStyleId === altStyle.id ? initialFocusRef : null
									}
								/>
							))}
						</Box>
					</Box>
				))}
				{groups.length === 0 && !matchesDefaultStyle(query) && (
					<Box fontSize="sm" textAlign="center" opacity="0.7" paddingY="4">
						No styles match “{query.trim()}”.
					</Box>
				)}
			</Box>
			<StyleCaption altStyle={captionStyle} />
		</Flex>
	);
}

/**
 * StyleOption is one tile in the StyleSelect grid: a picture of the pet in
 * this style, backed by a radio input. Pass `altStyle={null}` for the
 * "Default" (no style) option.
 *
 * If `description` is given, the option is laid out as a row instead, with
 * the tile on the left and its name and description beside it.
 *
 * NOTE: This is memoized, because there can be 100+ of these, and the grid
 *       re-renders whenever the mouse moves from one to the next. Keep its
 *       props stable!
 */
const StyleOption = React.memo(function StyleOption({
	altStyle,
	checked,
	onChange,
	onHover,
	inputRef,
	description = null,
}) {
	const theme = useTheme();
	const selectedBorderColor = useColorModeValue(
		theme.colors.green["600"],
		theme.colors.green["300"],
	);
	const hoverBorderColor = theme.colors.gray["400"];
	const unlabeledBorderColor = useColorModeValue(
		theme.colors.gray["300"],
		theme.colors.gray["500"],
	);
	const tileBackground = useColorModeValue(
		theme.colors.gray["100"],
		theme.colors.whiteAlpha["200"],
	);
	const outlineShadow = useToken("shadows", "outline");

	const tileRef = React.useRef(null);
	const shouldLoadImage = useHasBeenNearView(tileRef);

	const id = altStyle?.id ?? null;
	const name = getStyleName(altStyle);
	const imageUrl = getStyleImageUrl(altStyle);
	const isLabeled = altStyle == null || altStyle.isLabeled;

	return (
		<ClassNames>
			{({ css }) => (
				<Box
					as="label"
					display={description != null ? "flex" : "block"}
					alignItems="center"
					gap="3"
					position="relative"
					cursor="pointer"
					onPointerEnter={(e) => onHover(e, id)}
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
						aria-label={name}
						value={id ?? ""}
						checked={checked}
						onChange={() => onChange(id)}
						ref={inputRef}
						// HACK: Without this, the page extends super long. I think this is
						//       because the VisuallyHidden just uses `position: absolute`,
						//       which makes it float invisibly *beyond* the scrolling
						//       container it's in, extending the page? But if we put it at
						//       the top-left corner instead, it doesn't.
						left="0"
						top="0"
						// When the keyboard scrolls this into view, don't leave it
						// hidden under the sticky group heading.
						style={{ scrollMarginTop: "2rem" }}
					/>
					<Box
						ref={tileRef}
						flex="0 0 auto"
						width={description != null ? "52px" : "auto"}
						borderRadius="md"
						overflow="hidden"
						className={css`
							aspect-ratio: 1;
							background: ${tileBackground};
							border: 2px ${isLabeled ? "solid" : "dashed"}
								${isLabeled ? "transparent" : unlabeledBorderColor};
							transition:
								border-color 0.2s,
								box-shadow 0.2s;

							label:hover > & {
								border-color: ${hoverBorderColor};
							}

							input:focus + & {
								box-shadow: ${outlineShadow};
							}

							input:checked + & {
								border: 2px solid ${selectedBorderColor};
							}
						`}
					>
						{imageUrl != null ? (
							<img
								// The grid can hold 100+ of these, and they're the full-size
								// pet layers (~50kb each), so we only load the ones scrolled
								// near view. (It's the same file the outfit preview uses, so
								// it's often already in the browser's cache by then.)
								src={shouldLoadImage ? imageUrl : undefined}
								alt=""
								loading="lazy"
								decoding="async"
								// The image's own size, so the browser can lay it out before
								// it loads.
								width="600"
								height="600"
								// The pet only fills the middle of its 600x600 canvas, so
								// zoom in. (This crops the very largest pets a little.)
								className={css`
									display: block;
									width: 100%;
									height: 100%;
									object-fit: contain;
									transform: scale(1.7);
								`}
							/>
						) : (
							<Flex align="center" justify="center" height="100%">
								<EmojiImage src={twemojiSmile} alt="" boxSize={20} />
							</Flex>
						)}
					</Box>
					{description != null && (
						<Box fontSize="sm" lineHeight="short">
							<Box fontWeight={checked ? "bold" : "normal"}>{name}</Box>
							<Box fontSize="xs" opacity="0.7">
								{description}
							</Box>
						</Box>
					)}
				</Box>
			)}
		</ClassNames>
	);
});

/**
 * useHasBeenNearView returns whether the element has ever been scrolled into
 * (or nearly into) view within the StyleSelect grid. Once true, it stays true.
 *
 * We use this instead of relying on `loading="lazy"` alone: browsers start
 * lazy images long before they're visible (Chrome: up to ~1250px away, even
 * inside a small scrolling box), which here meant fetching most of the grid
 * as soon as it opened.
 */
function useHasBeenNearView(ref) {
	const [hasBeenNearView, setHasBeenNearView] = React.useState(false);

	React.useEffect(() => {
		const element = ref.current;
		if (hasBeenNearView || element == null) {
			return;
		}

		// If we can't observe, just load. (`loading="lazy"` is still on the image.)
		if (typeof IntersectionObserver === "undefined") {
			setHasBeenNearView(true);
			return;
		}

		const observer = new IntersectionObserver(
			(entries) => {
				if (entries.some((entry) => entry.isIntersecting)) {
					setHasBeenNearView(true);
				}
			},
			{
				root: element.closest("[data-style-scroll-container]"),
				// About two rows of tiles ahead, so normal scrolling stays filled in.
				rootMargin: "120px 0px",
			},
		);
		observer.observe(element);
		return () => observer.disconnect();
	}, [ref, hasBeenNearView]);

	return hasBeenNearView;
}

/**
 * StyleCaption names the style that's hovered or selected, since the grid
 * itself is pictures only. It always takes up two lines, so the popover
 * doesn't jump around as the mouse moves.
 */
function StyleCaption({ altStyle }) {
	const { name, variantName } = getStyleNameParts(altStyle);

	return (
		<Box fontSize="sm" lineHeight="short" minHeight="2.75em">
			<Box fontWeight="bold">{name}</Box>
			<Box fontSize="xs" opacity="0.7">
				{variantName}
			</Box>
		</Box>
	);
}

/**
 * Split a style's name into its main name and its Prismatic variant, if any:
 * "Prismatic Cyan: Nostalgic Faerie" is "Nostalgic Faerie", in "Prismatic
 * Cyan".
 */
function getStyleNameParts(altStyle) {
	if (altStyle == null) {
		return { name: "Default", variantName: "No style" };
	}

	if (!altStyle.isLabeled) {
		// The server names these for us, like "Unnamed Faerie style".
		return {
			name: altStyle.adjectiveName,
			variantName: "We haven't named this one yet",
		};
	}

	const [variantName, ...rest] = altStyle.adjectiveName.split(": ");
	if (rest.length === 0) {
		return { name: altStyle.adjectiveName, variantName: "" };
	}
	return { name: rest.join(": "), variantName };
}

function getStyleName(altStyle) {
	const { name, variantName } = getStyleNameParts(altStyle);
	return altStyle?.isLabeled && variantName ? `${variantName}: ${name}` : name;
}

/**
 * The short label for the PosePicker button: the first word of the style's
 * main name, like "Nostalgic".
 */
function getStyleLabel(altStyle) {
	if (!altStyle.isLabeled) {
		return "Unnamed";
	}
	return getStyleNameParts(altStyle).name.split(/\s+/)[0];
}

/**
 * The picture for a style's tile: the pet layer itself. (Styles are almost
 * always a single layer. The NC item thumbnail is only a fallback, because
 * it's small, and new styles don't have one until we've labeled them.)
 */
function getStyleImageUrl(altStyle) {
	if (altStyle == null) {
		return null;
	}

	const layerImageUrl = altStyle.appearance.layers[0]?.imageUrl;
	return safeImageUrl(layerImageUrl ?? altStyle.thumbnailUrl);
}

// Whether every word of the filter query appears somewhere in the text.
function matchesQuery(text, query) {
	const lowerText = text.toLowerCase();
	const queryWords = query.toLowerCase().split(/\s+/).filter(Boolean);
	return queryWords.every((word) => lowerText.includes(word));
}

// Whether the "Default" option should show for this filter query. (It always
// shows when there's no query.)
function matchesDefaultStyle(query) {
	return matchesQuery("default no style", query);
}

/**
 * Group styles by color for the StyleSelect grid, keeping only the ones that
 * match the filter query. The pet's own color goes first, since those are the
 * styles people most often come looking for; then colors A-Z.
 */
function groupAltStylesByColor(altStyles, { query = "", petColorId }) {
	const groupsByColorId = new Map();
	for (const altStyle of altStyles) {
		// Match on the style's real name and color. Styles we haven't named yet
		// only have a color, plus "unnamed" and "new" as ways to find them.
		const searchText = altStyle.isLabeled
			? `${altStyle.adjectiveName} ${altStyle.colorName}`
			: `${altStyle.colorName} unnamed new`;
		if (!matchesQuery(searchText, query)) {
			continue;
		}

		if (!groupsByColorId.has(altStyle.colorId)) {
			groupsByColorId.set(altStyle.colorId, {
				colorId: altStyle.colorId,
				colorName: altStyle.colorName ?? "Other",
				isPetColor: altStyle.colorId === String(petColorId),
				altStyles: [],
			});
		}
		groupsByColorId.get(altStyle.colorId).altStyles.push(altStyle);
	}

	const groups = [...groupsByColorId.values()];
	groups.sort(
		(a, b) =>
			b.isPetColor - a.isPetColor || a.colorName.localeCompare(b.colorName),
	);

	// Within a color, keep the order the server gave us (by series, then by
	// Prismatic variant), but with the styles we haven't named yet at the end.
	for (const group of groups) {
		group.altStyles.sort((a, b) => b.isLabeled - a.isLabeled);
	}

	return groups;
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
		return twemojiHourglass;
	} else {
		return twemojiSmile;
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
		return "Retired UC";
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
