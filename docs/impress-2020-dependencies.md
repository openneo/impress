# Impress 2020 Dependencies

This document tracks how the main DTI Rails app still depends on the separate Impress 2020 service, and what would need to be migrated to fully consolidate into a single Rails app.

## Background

In 2020, we started a NextJS rewrite called "Impress 2020" to modernize the frontend. We've since decided to consolidate back into the Rails app, but migration is ongoing. The Rails app now embeds the Impress 2020 React frontend (in `app/javascript/wardrobe-2020/`) for the outfit editor, but some functionality still calls back to the Impress 2020 GraphQL API.

## Current State

### What's Migrated to Rails

The following have been migrated to Rails REST API endpoints (in `app/javascript/wardrobe-2020/loaders/`):

- **Item search** (`/items.json`) - Searching for items with filters
- **Item appearances** (`/items/:id/appearances.json`) - Getting item layers for different bodies
- **Outfit save/load** (`/outfits.json`, `/outfits/:id.json`) - CRUD operations on outfits
- **Alt styles** (`/species/:id/alt-styles.json`) - Loading alternative pet appearances

### What Still Uses Impress 2020 GraphQL

The following GraphQL queries and mutations are still hitting the Impress 2020 service:

#### Core Wardrobe Functionality

- **`OutfitPetAppearance`** - Load pet appearance (biology layers) by species/color/pose
- **`OutfitPetAppearanceById`** - Load pet appearance by ID
- **`OutfitItemsAppearance`** - Load item appearances (object layers) for worn items
- **`OutfitStateItems`** - Load item metadata for the outfit state
- **`OutfitStateItemConflicts`** - Check for conflicting items in zones
- **`PosePicker`** - Load available poses for a species/color combination
- **`SpeciesColorPicker`** - Load all species and colors for the picker UI
- **`SearchToolbarZones`** - Load all zones for search filtering
- **`OutfitThumbnailIfCached`** - Check if an outfit thumbnail exists in the cache

#### Support/Admin Tools

These are staff-only features for managing modeling data:

- **`ItemSupportFields`** - Load item data for support drawer
- **`ItemSupportRestrictedZones`** - Load restricted zones for an item
- **`ItemSupportDrawerAllColors`** - Load all colors for support tools
- **`PosePickerSupport`** - Load pet appearance data for labeling
- **`PosePickerSupportRefetchCanonicalAppearances`** - Refresh canonical appearance data
- **`AllItemLayersSupportModal`** - Load all layers for an item (support view)
- **`AllItemLayersSupportModal_BulkAddProposal`** - Preview bulk layer additions
- **`WriteItemFromLoader`** - Write item data to Apollo cache (used after REST calls)

#### Support/Admin Mutations

- **`ItemSupportDrawerSetItemExplicitlyBodySpecific`** - Mark item as body-specific
- **`ItemSupportDrawerSetManualSpecialColor`** - Set manual special color for item
- **`PosePickerSupportSetPetAppearancePose`** - Update pet appearance pose label
- **`PosePickerSupportSetPetAppearanceIsGlitched`** - Mark pet appearance as glitched
- **`ApperanceLayerSupportSetLayerBodyId`** - Update layer's body ID
- **`AppearanceLayerSupportRemoveButton`** - Remove a layer
- **`AllItemLayersSupportModal_BulkAddMutation`** - Bulk add layers to bodies

### Image Services

Impress 2020 also provides image generation services:

- **Outfit thumbnails** - Generates PNG images of outfits at various sizes (150px, 300px, 600px)
- **Asset image rendering** - Runs a headless browser to convert HTML5 canvas movies to static images

These are served via:
- Production: `https://outfits.openneo-assets.net/outfits/:id/v/:timestamp/:size.png`
- Development: `Rails.configuration.impress_2020_origin + /api/outfitImage?id=...`

## Migration Strategy

There are two potential paths forward:

### Option A: Incremental GraphQL → REST Migration

Continue migrating GraphQL queries to Rails REST endpoints, keeping the React wardrobe.

**Pros**: Lower risk, incremental progress, preserves mobile-friendly UI

**Cons**: Maintains complexity of React app + dual API surface

### Option B: Wardrobe Rewrite (Rails + Turbo)

Rewrite the outfit editor as a Rails view with Turbo/Stimulus, similar to the item show page.

**Pros**: Massive simplification—remove React, GraphQL, and complex data fetching entirely

**Cons**: High risk (rewrites are dangerous), significant effort, potential UI regressions

**Note**: Simplicity has been DTI's most valuable architectural principle long-term. The complexity of maintaining the React wardrobe + its APIs is significant. But rewrites carry inherent risk.

---

### Option A: Priority 1 - Core Data Loading

The most important migrations to enable turning off Impress 2020 would be:

1. **Pet appearances** (`OutfitPetAppearance`, `OutfitPetAppearanceById`)
   - Backend: Create `/pet-types/:species/:color/appearances.json` or similar
   - Frontend: Update `useOutfitAppearance.js` to use REST loader

2. **Item appearance layers** (`OutfitItemsAppearance`)
   - May already be covered by `/items/:id/appearances.json`?
   - Need to verify if this is redundant with existing loader

3. **Species/Color/Zone metadata** (`SpeciesColorPicker`, `SearchToolbarZones`)
   - Backend: Create endpoints for species, colors, zones listings
   - Or embed this static data in the JS bundle

4. **Pose availability** (`PosePicker`)
   - Backend: Add pose data to pet type endpoints
   - Frontend: Update pose picker to use REST data

### Priority 2: Support Tools

Support tools could be migrated as Rails admin pages using Turbo/Stimulus:

- Pet state labeling (pose picker support)
- Item layer management
- Manual data corrections

These don't need to be React-based; simpler Rails views would work fine.

### Priority 3: Image Services

This is the most complex migration:

- Move headless browser rendering into a Rails service or separate microservice
- Set up image storage (S3 or similar)
- Update outfit image URLs to point to new service

## Deployment Architecture

### Current Setup

- **Main Rails app**: Primary VPS server, serves web traffic and API
- **Impress 2020**: Separate VPS in same datacenter, provides GraphQL API and image services
- **Database**: MySQL on main Rails server, accessed by both services
- **OpenNeo ID database**: Separate MySQL database (legacy, could be merged)

### After Full Migration

- **Single Rails app**: One VPS serving everything
- **Image service**: Either integrated into Rails or extracted as a simple microservice
- **Single MySQL database**: Merge OpenNeo ID schema into main database

## Notes

- The wardrobe-2020 frontend is already embedded in Rails (`app/javascript/wardrobe-2020/`)
- Many API calls have been successfully migrated from GraphQL to REST
- The GraphQL dependency is primarily in the core outfit rendering logic
- Support tools are the lowest priority since they're staff-only

## See Also

- [Customization Architecture](./customization-architecture.md) - Explains the data model
- `app/javascript/wardrobe-2020/loaders/` - Migrated REST API calls
- `config/routes.rb` - Rails API endpoints
