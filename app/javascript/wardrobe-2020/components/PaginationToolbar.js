import React from "react";
import { Box, Button, Flex, Select } from "@chakra-ui/react";

function PaginationToolbar({
  isLoading,
  numTotalPages,
  currentPageNumber,
  goToPageNumber,
  buildPageUrl,
  size = "md",
  ...props
}) {
  const pagesAreLoaded = currentPageNumber != null && numTotalPages != null;
  const hasPrevPage = pagesAreLoaded && currentPageNumber > 1;
  const hasNextPage = pagesAreLoaded && currentPageNumber < numTotalPages;

  const prevPageUrl = hasPrevPage ? buildPageUrl(currentPageNumber - 1) : null;
  const nextPageUrl = hasNextPage ? buildPageUrl(currentPageNumber + 1) : null;

  return (
    <Flex align="center" justify="space-between" {...props}>
      <LinkOrButton
        href={prevPageUrl}
        onClick={
          prevPageUrl == null
            ? () => goToPageNumber(currentPageNumber - 1)
            : undefined
        }
        _disabled={{
          cursor: isLoading ? "wait" : "not-allowed",
          opacity: 0.4,
        }}
        isDisabled={!hasPrevPage}
        size={size}
      >
        ← Prev
      </LinkOrButton>
      {numTotalPages > 0 && (
        <Flex align="center" paddingX="4" fontSize={size}>
          <Box flex="0 0 auto">Page</Box>
          <Box width="1" />
          <PageNumberSelect
            currentPageNumber={currentPageNumber}
            numTotalPages={numTotalPages}
            onChange={goToPageNumber}
            marginBottom="-2px"
            size={size}
          />
          <Box width="1" />
          <Box flex="0 0 auto">of {numTotalPages}</Box>
        </Flex>
      )}
      <LinkOrButton
        href={nextPageUrl}
        onClick={
          nextPageUrl == null
            ? () => goToPageNumber(currentPageNumber + 1)
            : undefined
        }
        _disabled={{
          cursor: isLoading ? "wait" : "not-allowed",
          opacity: 0.4,
        }}
        isDisabled={!hasNextPage}
        size={size}
      >
        Next →
      </LinkOrButton>
    </Flex>
  );
}

function LinkOrButton({ href, ...props }) {
  if (href != null) {
    return <Button as="a" href={href} {...props} />;
  } else {
    return <Button {...props} />;
  }
}

function PageNumberSelect({
  currentPageNumber,
  numTotalPages,
  onChange,
  ...props
}) {
  const allPageNumbers = Array.from({ length: numTotalPages }, (_, i) => i + 1);

  const handleChange = React.useCallback(
    (e) => onChange(Number(e.target.value)),
    [onChange],
  );

  return (
    <Select
      value={currentPageNumber}
      onChange={handleChange}
      width="7ch"
      variant="flushed"
      textAlign="center"
      {...props}
    >
      {allPageNumbers.map((pageNumber) => (
        <option key={pageNumber} value={pageNumber}>
          {pageNumber}
        </option>
      ))}
    </Select>
  );
}

export default PaginationToolbar;
