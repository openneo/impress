import { Box } from "@chakra-ui/react";

function OutfitThumbnail({ outfitId, updatedAt, ...props }) {
  const versionTimestamp = new Date(updatedAt).getTime();

  // NOTE: It'd be more reliable for testing to use a relative path, but
  //       generating these on dev is SO SLOW, that I'd rather just not.
  const thumbnailUrl150 = `https://outfits.openneo-assets.net/outfits/${outfitId}/v/${versionTimestamp}/150.png`;
  const thumbnailUrl300 = `https://outfits.openneo-assets.net/outfits/${outfitId}/v/${versionTimestamp}/300.png`;

  return (
    <Box
      as="img"
      src={thumbnailUrl150}
      srcSet={`${thumbnailUrl150} 1x, ${thumbnailUrl300} 2x`}
      {...props}
    />
  );
}

export default OutfitThumbnail;
