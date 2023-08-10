import React from "react";
import gql from "graphql-tag";
import { useQuery } from "@apollo/client";
import {
  Box,
  IconButton,
  Input,
  InputGroup,
  InputLeftAddon,
  InputLeftElement,
  InputRightElement,
  Tooltip,
  useColorModeValue,
} from "@chakra-ui/react";
import {
  ChevronDownIcon,
  ChevronUpIcon,
  CloseIcon,
  SearchIcon,
} from "@chakra-ui/icons";
import { ClassNames } from "@emotion/react";
import Autosuggest from "react-autosuggest";

import useCurrentUser from "../components/useCurrentUser";
import { logAndCapture } from "../util";

export const emptySearchQuery = {
  value: "",
  filterToZoneLabel: null,
  filterToItemKind: null,
  filterToCurrentUserOwnsOrWants: null,
};

export function searchQueryIsEmpty(query) {
  return Object.values(query).every((value) => !value);
}

const SUGGESTIONS_PLACEMENT_PROPS = {
  inline: {
    borderBottomRadius: "md",
  },
  top: {
    position: "absolute",
    bottom: "100%",
    borderTopRadius: "md",
  },
};

/**
 * SearchToolbar is rendered above both the ItemsPanel and the SearchPanel,
 * and contains the search field where the user types their query.
 *
 * It has some subtle keyboard interaction support, like DownArrow to go to the
 * first search result, and Escape to clear the search and go back to the
 * ItemsPanel. (The SearchPanel can also send focus back to here, with Escape
 * from anywhere, or UpArrow from the first result!)
 */
function SearchToolbar({
  query,
  searchQueryRef,
  firstSearchResultRef = null,
  onChange,
  autoFocus,
  showItemsLabel = false,
  background = null,
  boxShadow = null,
  suggestionsPlacement = "inline",
  ...props
}) {
  const [suggestions, setSuggestions] = React.useState([]);
  const [advancedSearchIsOpen, setAdvancedSearchIsOpen] = React.useState(false);
  const { isLoggedIn } = useCurrentUser();

  // NOTE: This query should always load ~instantly, from the client cache.
  const { data } = useQuery(gql`
    query SearchToolbarZones {
      allZones {
        id
        label
        depth
        isCommonlyUsedByItems
      }
    }
  `);
  const zones = data?.allZones || [];
  const itemZones = zones.filter((z) => z.isCommonlyUsedByItems);

  let zoneLabels = itemZones.map((z) => z.label);
  zoneLabels = [...new Set(zoneLabels)];
  zoneLabels.sort();

  const onMoveFocusDownToResults = (e) => {
    if (firstSearchResultRef && firstSearchResultRef.current) {
      firstSearchResultRef.current.focus();
      e.preventDefault();
    }
  };

  const suggestionBgColor = useColorModeValue("white", "whiteAlpha.100");
  const highlightedBgColor = useColorModeValue("gray.100", "whiteAlpha.300");

  const renderSuggestion = React.useCallback(
    ({ text }, { isHighlighted }) => (
      <Box
        fontWeight={isHighlighted ? "bold" : "normal"}
        background={isHighlighted ? highlightedBgColor : suggestionBgColor}
        padding="2"
        paddingLeft="2.5rem"
        fontSize="sm"
      >
        {text}
      </Box>
    ),
    [suggestionBgColor, highlightedBgColor]
  );

  const renderSuggestionsContainer = React.useCallback(
    ({ containerProps, children }) => {
      const { className, ...otherContainerProps } = containerProps;
      return (
        <ClassNames>
          {({ css, cx }) => (
            <Box
              {...otherContainerProps}
              boxShadow="md"
              overflow="auto"
              transition="all 0.4s"
              maxHeight="48"
              width="100%"
              className={cx(
                className,
                css`
                  li {
                    list-style: none;
                  }
                `
              )}
              {...SUGGESTIONS_PLACEMENT_PROPS[suggestionsPlacement]}
            >
              {children}
              {!children && advancedSearchIsOpen && (
                <Box
                  padding="4"
                  fontSize="sm"
                  fontStyle="italic"
                  textAlign="center"
                >
                  No more filters available!
                </Box>
              )}
            </Box>
          )}
        </ClassNames>
      );
    },
    [advancedSearchIsOpen, suggestionsPlacement]
  );

  // When we change the query filters, clear out the suggestions.
  React.useEffect(() => {
    setSuggestions([]);
  }, [
    query.filterToItemKind,
    query.filterToZoneLabel,
    query.filterToCurrentUserOwnsOrWants,
  ]);

  let queryFilterText = getQueryFilterText(query);
  if (showItemsLabel) {
    queryFilterText = queryFilterText ? (
      <>
        <Box as="span" fontWeight="600">
          Items:
        </Box>{" "}
        {queryFilterText}
      </>
    ) : (
      <Box as="span" fontWeight="600">
        Items
      </Box>
    );
  }

  const allSuggestions = getSuggestions(null, query, zoneLabels, isLoggedIn, {
    showAll: true,
  });

  // Once you remove the final suggestion available, close Advanced Search. We
  // have placeholder text available, sure, but this feels more natural!
  React.useEffect(() => {
    if (allSuggestions.length === 0) {
      setAdvancedSearchIsOpen(false);
    }
  }, [allSuggestions.length]);

  const focusBorderColor = useColorModeValue("green.600", "green.400");

  return (
    <Box position="relative" {...props}>
      <Autosuggest
        suggestions={advancedSearchIsOpen ? allSuggestions : suggestions}
        onSuggestionsFetchRequested={({ value }) => {
          // HACK: I'm not sure why, but apparently this gets called with value
          //       set to the _chosen suggestion_ after choosing it? Has that
          //       always happened? Idk? Let's just, gate around it, I guess?
          if (typeof value === "string") {
            setSuggestions(
              getSuggestions(value, query, zoneLabels, isLoggedIn)
            );
          }
        }}
        onSuggestionSelected={(e, { suggestion }) => {
          onChange({
            ...query,
            // If the suggestion was from typing, remove the last word of the
            // query value. Or, if it was from Advanced Search, leave it alone!
            value: advancedSearchIsOpen
              ? query.value
              : removeLastWord(query.value),
            filterToZoneLabel: suggestion.zoneLabel || query.filterToZoneLabel,
            filterToItemKind: suggestion.itemKind || query.filterToItemKind,
            filterToCurrentUserOwnsOrWants:
              suggestion.userOwnsOrWants ||
              query.filterToCurrentUserOwnsOrWants,
          });
        }}
        getSuggestionValue={(zl) => zl}
        alwaysRenderSuggestions={true}
        renderSuggestion={renderSuggestion}
        renderSuggestionsContainer={renderSuggestionsContainer}
        renderInputComponent={(inputProps) => (
          <InputGroup boxShadow={boxShadow} borderRadius="md">
            {queryFilterText ? (
              <InputLeftAddon>
                <SearchIcon color="gray.400" marginRight="3" />
                <Box fontSize="sm">{queryFilterText}</Box>
              </InputLeftAddon>
            ) : (
              <InputLeftElement>
                <SearchIcon color="gray.400" />
              </InputLeftElement>
            )}
            <Input
              background={background}
              autoFocus={autoFocus}
              {...inputProps}
            />
            <InputRightElement
              width="auto"
              justifyContent="flex-end"
              paddingRight="2px"
              paddingY="2px"
            >
              {!searchQueryIsEmpty(query) && (
                <Tooltip label="Clear">
                  <IconButton
                    icon={<CloseIcon fontSize="0.6em" />}
                    color="gray.400"
                    variant="ghost"
                    height="100%"
                    marginLeft="1"
                    aria-label="Clear search"
                    onClick={() => {
                      setSuggestions([]);
                      onChange(emptySearchQuery);
                    }}
                  />
                </Tooltip>
              )}
              <Tooltip label="Advanced search">
                <IconButton
                  icon={
                    advancedSearchIsOpen ? (
                      <ChevronUpIcon fontSize="1.5em" />
                    ) : (
                      <ChevronDownIcon fontSize="1.5em" />
                    )
                  }
                  color="gray.400"
                  variant="ghost"
                  height="100%"
                  aria-label="Open advanced search"
                  onClick={() => setAdvancedSearchIsOpen((isOpen) => !isOpen)}
                />
              </Tooltip>
            </InputRightElement>
          </InputGroup>
        )}
        inputProps={{
          placeholder: "Search all items…",
          focusBorderColor: focusBorderColor,
          value: query.value || "",
          ref: searchQueryRef,
          minWidth: 0,
          "data-test-id": "item-search-input",
          onChange: (e, { newValue, method }) => {
            // The Autosuggest tries to change the _entire_ value of the element
            // when navigating suggestions, which isn't actually what we want.
            // Only accept value changes that are typed by the user!
            if (method === "type") {
              onChange({ ...query, value: newValue });
            }
          },
          onKeyDown: (e) => {
            if (e.key === "Escape") {
              if (suggestions.length > 0) {
                setSuggestions([]);
                return;
              }
              onChange(emptySearchQuery);
              e.target.blur();
            } else if (e.key === "Enter") {
              // Pressing Enter doesn't actually submit because it's all on
              // debounce, but it can be a declaration that the query is done, so
              // filter suggestions should go away!
              if (suggestions.length > 0) {
                setSuggestions([]);
                return;
              }
            } else if (e.key === "ArrowDown") {
              if (suggestions.length > 0) {
                return;
              }
              onMoveFocusDownToResults(e);
            } else if (e.key === "Backspace" && e.target.selectionStart === 0) {
              onChange({
                ...query,
                filterToItemKind: null,
                filterToZoneLabel: null,
                filterToCurrentUserOwnsOrWants: null,
              });
            }
          },
        }}
      />
    </Box>
  );
}

function getSuggestions(
  value,
  query,
  zoneLabels,
  isLoggedIn,
  { showAll = false } = {}
) {
  if (!value && !showAll) {
    return [];
  }

  const words = (value || "").split(/\s+/);
  const lastWord = words[words.length - 1];
  if (lastWord.length < 2 && !showAll) {
    return [];
  }

  const suggestions = [];

  if (query.filterToItemKind == null) {
    if (
      wordMatches("NC", lastWord) ||
      wordMatches("Neocash", lastWord) ||
      showAll
    ) {
      suggestions.push({ itemKind: "NC", text: "Neocash items" });
    }

    if (
      wordMatches("NP", lastWord) ||
      wordMatches("Neopoints", lastWord) ||
      showAll
    ) {
      suggestions.push({ itemKind: "NP", text: "Neopoint items" });
    }

    if (
      wordMatches("PB", lastWord) ||
      wordMatches("Paintbrush", lastWord) ||
      showAll
    ) {
      suggestions.push({ itemKind: "PB", text: "Paintbrush items" });
    }
  }

  if (isLoggedIn && query.filterToCurrentUserOwnsOrWants == null) {
    if (wordMatches("Items you own", lastWord) || showAll) {
      suggestions.push({ userOwnsOrWants: "OWNS", text: "Items you own" });
    }

    if (wordMatches("Items you want", lastWord) || showAll) {
      suggestions.push({ userOwnsOrWants: "WANTS", text: "Items you want" });
    }
  }

  if (query.filterToZoneLabel == null) {
    for (const zoneLabel of zoneLabels) {
      if (wordMatches(zoneLabel, lastWord) || showAll) {
        suggestions.push({ zoneLabel, text: `Zone: ${zoneLabel}` });
      }
    }
  }

  return suggestions;
}

function wordMatches(target, word) {
  return target.toLowerCase().includes(word.toLowerCase());
}

function getQueryFilterText(query) {
  const textWords = [];

  if (query.filterToItemKind) {
    textWords.push(query.filterToItemKind);
  }

  if (query.filterToZoneLabel) {
    textWords.push(pluralizeZoneLabel(query.filterToZoneLabel));
  }

  if (query.filterToCurrentUserOwnsOrWants === "OWNS") {
    if (!query.filterToItemKind && !query.filterToZoneLabel) {
      textWords.push("Items");
    } else if (query.filterToItemKind && !query.filterToZoneLabel) {
      textWords.push("items");
    }
    textWords.push("you own");
  } else if (query.filterToCurrentUserOwnsOrWants === "WANTS") {
    if (!query.filterToItemKind && !query.filterToZoneLabel) {
      textWords.push("Items");
    } else if (query.filterToItemKind && !query.filterToZoneLabel) {
      textWords.push("items");
    }
    textWords.push("you want");
  }

  return textWords.join(" ");
}

/**
 * pluralizeZoneLabel hackily tries to convert a zone name to a plural noun!
 *
 * HACK: It'd be more reliable and more translatable to do this by just
 *       manually creating the plural for each zone. But, ehh! ¯\_ (ツ)_/¯
 */
function pluralizeZoneLabel(zoneLabel) {
  if (zoneLabel.endsWith("ss")) {
    return zoneLabel + "es";
  } else if (zoneLabel.endsWith("s")) {
    return zoneLabel;
  } else {
    return zoneLabel + "s";
  }
}

/**
 * removeLastWord returns a copy of the text, with the last word and any
 * preceding space removed.
 */
function removeLastWord(text) {
  // This regex matches the full text, and assigns the last word and any
  // preceding text to subgroup 2, and all preceding text to subgroup 1. If
  // there's no last word, we'll still match, and the full string will be in
  // subgroup 1, including any space - no changes made!
  const match = text.match(/^(.*?)(\s*\S+)?$/);
  if (!match) {
    logAndCapture(
      new Error(
        `Assertion failure: pattern should match any input text, ` +
          `but failed to match ${JSON.stringify(text)}`
      )
    );
    return text;
  }

  return match[1];
}

export default SearchToolbar;
