# Dress to Impress: Customization System Architecture

Dress to Impress (DTI) models Neopets's pet customization system: layered 2D images of pets wearing clothing items. This guide explains how DTI's data models represent the customization system and how they combine to render outfit images.

## Core Models

The customization system is built on these key models:

### Species and Color
- **Species**: The type of Neopet (Acara, Zafara, etc.)
- **Color**: The paint color applied to a pet (Blue, Maraquan, Halloween, etc.)
- Colors have flags: `basic` (starter colors like Blue/Red), `standard` (follows typical body shape), `nonstandard` (unusual shapes)

### PetType
**PetType = Species + Color**

- Represents the combination of a species and color (e.g., "Blue Acara", "Maraquan Acara")
- **Contains the critical `body_id` field**: the physical shape/compatibility ID
- Body ID determines what clothing items are compatible with this pet
- Example: "Blue Acara" and "Red Acara" share the same body_id (they have the same shape), but "Maraquan Acara" has a different body_id (different shape)

### PetState
**PetState = A visual variant of a PetType**

- Represents different presentations: gender (feminine/masculine) and mood (happy/sad/sick)
- Standard poses: `HAPPY_FEM`, `HAPPY_MASC`, `SAD_FEM`, `SAD_MASC`, `SICK_FEM`, `SICK_MASC`
- Special case: `UNCONVERTED` - legacy pets from before the customization system (now mostly replaced by Alt Styles)
- Has many `swf_assets` (the actual visual layers for the pet's appearance)

### Item
- Represents a wearable clothing item
- Can have different appearances for different body IDs
- Tracks `cached_compatible_body_ids`: which bodies this item has been seen on
- Tracks `cached_occupied_zone_ids`: which zones this item's layers occupy

### Item.Appearance
**Not a database model** - a `Struct` that represents "this item on this body"

- Created on-the-fly when rendering
- Contains: the item, the body (id + species), and the relevant `swf_assets`
- Why it exists: items can look completely different on different bodies

### SwfAsset
**The actual visual layer** - a single image in the final composite

- Two types (via `type` field):
  - `'biology'`: Pet appearance layers (tied to PetStates)
  - `'object'`: Item appearance layers (tied to Items)
- Has a `body_id`: either a specific body, or `0` meaning "fits all bodies"
- Belongs to a `Zone` (which determines rendering depth/order)
- Contains URLs for the image assets (Flash SWF legacy, HTML5 canvas/SVG modern)
- Has `zones_restrict`: a bitfield indicating which zones this asset restricts

### Zone
- Defines a layer position in the rendering stack
- Has a `depth`: lower depths render behind, higher depths render in front
- Has a `label`: human-readable name (e.g., "Hat", "Background")
- Multiple zones can share the same label but have different depths (for items that "wrap around" pets)

### AltStyle
**Alternative pet appearance** - a newer system for non-standard pet looks

- Used for "Nostalgic" (pre-customization) appearances and other special styles
- Replaces the pet's normal layers entirely (not additive)
- Has its own `body_id` (distinct from regular pet body IDs)
- Most items are incompatible - only `body_id=0` items work with alt styles
- Example: "Nostalgic Grey Zafara" is an AltStyle, not a PetState

---

## The Rendering Pipeline

This is the core of DTI's customization system: how we turn database records into layered outfit images.

### Overview

**Input**: An `Outfit` (a pet appearance + a list of worn items)
**Output**: A sorted list of `SwfAsset` layers to render, bottom-to-top

### Step 1: Choose the Biology Layers

```ruby
# If alt_style is present, use its layers; otherwise use pet_state's layers
biology_layers = outfit.alt_style ? outfit.alt_style.swf_assets : outfit.pet_state.swf_assets
```

- Alt styles completely replace pet layers (they don't layer on top)
- Regular pets use their pet_state's layers
- All biology layers have `type = 'biology'`

### Step 2: Load Item Appearances

```ruby
# Get how each worn item looks on this body
body_id = outfit.alt_style ? outfit.alt_style.body_id : outfit.pet_type.body_id
item_appearances = Item.appearances_for(outfit.worn_items, body_id)
item_layers = item_appearances.flat_map(&:swf_assets)
```

- For each worn item, find the `swf_assets` that match this body
- Matching logic: asset's `body_id` must equal the pet's `body_id`, OR asset's `body_id = 0` (fits all)
- For alt styles: only `body_id=0` items will match (body-specific items are incompatible)
- All item layers have `type = 'object'`

### Step 3: Apply Restriction Rules

This is where it gets complex. We need to hide certain layers based on zone restrictions.

#### Rule 3a: Items Restrict Pet Layers

```ruby
# Collect all zones that items restrict
item_restricted_zone_ids = item_appearances.flat_map(&:restricted_zone_ids)

# Hide pet layers in those zones
biology_layers.reject! { |layer| item_restricted_zone_ids.include?(layer.zone_id) }
```

**Example**: The "Zafara Agent Hood" restricts the "Hair Front" and "Head Transient Biology" zones.

**How it works**:
- Items have a `zones_restrict` bitfield indicating which zones they restrict
- When an item restricts zone 5, all pet layers in zone 5 are hidden
- This allows items to "replace" parts of the pet's appearance

#### Rule 3b: Pets Restrict Body-Specific Item Layers

This rule is asymmetric and more complex!

> Note: This is a legacy rule, originally built for Unconverted pets.
> Now, Unconverted pets don't exist… but pet states *do* still technically
> support zone restrictions. We should examine whether any existing pet
> states still use this feature, and consider simplifying it out of the
> system if not.

```ruby
# Collect all zones that the pet restricts
pet_restricted_zone_ids = biology_layers.flat_map(&:restricted_zone_ids)

# Special case: Unconverted pets can't wear ANY body-specific items
if pet_state.pose == "UNCONVERTED"
  item_layers.reject! { |layer| layer.body_specific? }
else
  # Other pets: hide body-specific items only in restricted zones
  item_layers.reject! do |layer|
    layer.body_specific? && pet_restricted_zone_ids.include?(layer.zone_id)
  end
end
```

**Example**: Unconverted pets can wear backgrounds (body_id=0) but not species-specific clothing.

**Key distinction**:
- Items restricting zones → hide **pet** layers
- Pets restricting zones → hide **body-specific item** layers
- Unconverted pets are special: they reject ALL body-specific items, regardless of zone

**Why `body_specific?` matters**:
- Items with `body_id=0` fit everyone and are never hidden by pet restrictions
- Items with specific body IDs are "body-specific" and can be hidden

#### Rule 3c: Pets Restrict Their Own Layers

```ruby
# Pets can hide parts of themselves too
biology_layers.reject! { |layer| pet_restricted_zone_ids.include?(layer.zone_id) }
```

**Example**: The Wraith Uni has a horn asset, but its zone restrictions hide it.

**Why this exists**: Sometimes the pet data includes layers that shouldn't be visible, probably to enable the Neopets team to more easily manage certain kinds of appearance assets. This allows the pet's metadata to control which of its own layers render.

### Step 4: Sort by Depth and Render

```ruby
all_layers = biology_layers + item_layers
all_layers.sort_by(&:depth)
```

- Pet layers first, then item layers (maintains order for same-depth assets)
- Sort by zone depth: lower depths behind, higher depths in front
- The sorted list is the final render order: first layer on bottom, last layer on top

**Important**: When a pet layer and item layer share the same zone (and thus the same depth), the item appears on top. This is achieved by putting item layers second in the concatenation and relying on sort stability.

---

## Understanding Compatibility

### Why body_id Is the Key

You might expect items to be compatible with a *species* (all Acaras) or a *color* (all Maraquan pets). But the system uses **body_id** instead.

**Why?**
- Some colors share the same body shape across species (e.g., most "Blue" pets follow a standard shape)
- Some colors have unique body shapes (e.g., Maraquan pets are aquatic and need different clothing)
- Some species have unique shapes even in "standard" colors
- Body ID captures the actual physical compatibility, regardless of color or species

**Example**:
- Blue Acara (body_id: 93) and Red Acara (body_id: 93) → same body, share items
- Blue Acara (body_id: 93) and Maraquan Acara (body_id: 112) → different bodies, different items
- An item compatible with body 93 fits both Blue and Red Acaras

### Body ID 0: Fits All

- Items with `body_id=0` assets fit every pet
- Examples: backgrounds, foregrounds, trinkets
- These are the only items compatible with alt styles

### Standard vs. Nonstandard Bodies

- **Standard bodies**: Follow typical species shapes (usually "Blue" or other basic colors)
- **Nonstandard bodies**: Unusual shapes (Maraquan, Baby, Mutant, etc.)
- This distinction helps with modeling predictions (more on that below)

### How Compatibility Is Discovered

DTI doesn't know in advance which items fit which bodies. Instead, **users contribute compatibility data through "modeling"**:

1. A user loads their pet wearing an item
2. DTI's backend calls Neopets APIs to fetch the pet's appearance data
3. The response includes which asset IDs are present
4. DTI records: "Item X has asset Y for body_id Z"
5. Over time, the database learns which items fit which bodies

This crowdsourced approach is why DTI is "self-sustaining" - users passively contribute data just by using the site.

---

## Modeling and Data Sources

### The Modeling Process

**"Modeling"** is DTI's term for crowdsourcing appearance data from users:

1. User submits a pet name, often to use as the base of a new outfit
2. DTI makes an API request to Neopets using the legacy Flash/AMF protocol
3. Response contains:
   - Pet's species, color, mood, gender
   - List of biology asset IDs (the pet's appearance)
   - List of object asset IDs (items the pet is wearing)
   - Metadata for each asset (zone, manifest URLs, etc.)
4. DTI creates/updates records:
   - `PetType` (if new species+color combo)
   - `PetState` (if new pose/mood/gender combo)
   - `SwfAsset` records for each asset
   - `ParentSwfAssetRelationship` linking assets to pets/items

See `app/models/pet/modeling_snapshot.rb` for the full implementation.

### Potential Upgrade: Auto-Modeling

We are currently not making full use of a recently-discovered Neopets feature: **we no longer need a real pet to model
the item**. There's an NC Mall feature that supports previews of *any* item, not just those sold in the Mall.

See the `pets:load` task for implementation details.

We still need users to show us new items in the first place, to learn their item IDs and what body types they might
fit. But once we have that, we can proactively attempt to model the pet on all relevant body types.

Let's pursue this in two steps:

1. [x] Create a backfill Rake task to attempt to load any models we suspect we need, based on the same logic as the
   `-is:modeled` item search filter. 
   - Consider having this task auto-update the `modeling_status_hint` field on the item, if we've demonstrated that
     the item is almost certainly completely modeled, despite our heuristic indicating it is not. This will keep the
     `is:modeled` filter clean and approximately empty.
   - As part of this, let's refactor the logic out of `pets:load`, to more simply construct an "image hash" ("sci")
     from a pet type + items combination.
2. [ ] Set this as a cron job to run very frequently, to quickly load in new items.
   - If we're able to reliably keep `is:modeled` basically empty, this could even be safe to run every, say, 2–5min.

### Cached Fields

To avoid expensive queries, several models cache computed data:

- **Item**:
  - `cached_compatible_body_ids`: Which bodies we've seen this item on
  - `cached_occupied_zone_ids`: Which zones this item's assets occupy
  - `cached_predicted_fully_modeled`: Whether we think we've seen all compatible bodies

- **PetState**:
  - `swf_asset_ids`: Direct list of asset IDs (for avoiding duplicate states)

These fields are updated automatically when new modeling data arrives.

### Prediction Logic

DTI tries to predict which bodies an item *should* work on, based on which bodies we've already seen it modeled on. This helps prioritize modeling work and estimate how "complete" an item's data is.

#### The Maraquan Mynci Problem

The core challenge is avoiding **false positives**. Consider: most Maraquan pets have unique, aquatic body shapes and wear special Maraquan-themed items. But the Maraquan Mynci shares the same body_id as basic Myncis - it can wear any standard Mynci item.

**Naive approach**: "We saw this item on a Maraquan pet, so predict it fits all Maraquan pets"

**Problem**: Most items fit the Maraquan Mynci but NOT other Maraquan pets!

#### The Solution: Unique Body Detection

For each item, we check whether **this item's modeling data** shows a color in a "modelable" way: the item must fit at least one body_id that ONLY that color uses (not shared with any other color).

**Example 1 - Real Maraquan item**:
- Modeled on: Maraquan Acara (body 112), Maraquan Zafara (body 98)
- Both bodies are unique to Maraquan (no basic pets share them)
- **Prediction**: This fits all Maraquan pets ✓

**Example 2 - Standard Mynci item**:
- Modeled on: Blue Mynci (body 47), Maraquan Mynci (body 47)
- Body 47 is shared by basic and Maraquan
- Maraquan has NO unique body for this item
- **Prediction**: This is a standard item for Myncis, not a Maraquan item ✓

**Example 3 - Maraquan item on Mynci**:
- Modeled on: Maraquan Acara (body 112), basic Mynci (body 47)
- Body 112 is unique to Maraquan
- Maraquan HAS a unique body (the Acara)
- **Prediction**: This fits all Maraquan pets (including Mynci) ✓

#### Basic Color Handling

Basic colors (Blue, Red, Green, etc.) always share the same body IDs in practice, so they're treated as a group. An item is predicted to fit all basic pets if we find at least one basic body that doesn't also fit any of the modelable colors identified above.

This prevents false positives: if an item fits both a unique Maraquan body AND a basic/Maraquan shared body (like the Mynci), we treat it as a Maraquan item, not a universal basic item.

#### Edge Cases

The algorithm has several early exits:

1. **Manual override**: If `modeling_status_hint` is set to "done", trust current data is complete
2. **Fits all** (`body_id=0`): Item fits everyone, prediction complete
3. **Single body**: Only one body seen - could be species-specific, stay conservative
4. **No data**: No bodies yet - optimistically predict all basic bodies for recently-released items

#### Why This Works

This approach is **self-sustaining**: no manual color flagging needed. As users model items, the unique body pattern emerges naturally, and predictions improve automatically.

See `Item#predicted_body_ids` in `app/models/item.rb:306-373` for the full implementation.

### Flash → HTML5 Transition

Neopets originally used Flash (SWF files) for customization. Over time, they've migrated to HTML5 (Canvas/SVG).

**SwfAsset fields**:
- `url`: Legacy SWF file URL (mostly unused now)
- `manifest_url`: JSON manifest for HTML5 assets
- `has_image`: Whether we generated a PNG from the SWF (legacy)

**Modern rendering**:
1. Load the manifest JSON from `manifest_url`
2. Parse it to find canvas library JS, SVG files, or PNG images
3. Use Impress 2020 (the frontend) to render them

**Fallbacks**:
- If `manifest_url` is missing or 404s, fall back to legacy PNG images
- If those are missing too, the asset can't be rendered

---

## Summary: Key Takeaways

1. **body_id is the compatibility key**, not species or color
2. **Restrictions are subtractive**: start with all layers, then hide some via restriction rules
3. **Restrictions are asymmetric**: items hide pet layers, pets hide body-specific items
4. **Unconverted pets are special**: they reject all body-specific items (and are no longer available on Neopets)
5. **Alt styles replace pet layers** and only work with body_id=0 items
6. **Data is crowdsourced** through user modeling, not pre-populated
7. **The system evolved over time**: Flash→HTML5, UC→Alt Styles, etc.

---

## Code References

- **Rendering logic**: `Outfit#visible_layers` in `app/models/outfit.rb`
- **Item appearances**: `Item.appearances_for` in `app/models/item.rb`
- **Modeling**: `Pet::ModelingSnapshot` in `app/models/pet/modeling_snapshot.rb`
- **Body compatibility**: `Item#compatible_body_ids`, `Item#predicted_body_ids` in `app/models/item.rb`
- **Pet state poses**: `PetState#pose`, `PetState.with_pose` in `app/models/pet_state.rb`
