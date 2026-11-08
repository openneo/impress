# Impress 2020 Dependencies

This document maps everything the main DTI Rails app (and the outside world)
still needs from the separate Impress 2020 service, and what it would take to
turn Impress 2020 off and replace it with redirects.

_Last audited: November 2026._

## Background

In 2020, we started a NextJS rewrite called "Impress 2020" to modernize the
frontend. We've since consolidated back into the Rails app: the Impress 2020
React wardrobe now lives in Rails (`app/javascript/wardrobe-2020/`), and is
staying React for the foreseeable future. (A Rails/Turbo "Wardrobe V2" was
explored on the `feature/wardrobe-v2` branch; it's not merged, nothing on
`main` depends on it, and we're not pursuing it further.)

But the embedded wardrobe still calls back to Impress 2020 for some data, and
Impress 2020 still serves a few things nobody else does, mostly images.

**Why turn it off:** one site instead of two, a smaller maintenance surface, a
lower bill, and closing real security gaps. The Impress 2020 box runs Node 16,
connects to MySQL as a user with `ALL` on both `openneo_impress` and
`openneo_id`, and authorizes support tools with a shared secret embedded in
page HTML. (Also, it has a cron job that restarts it every 8 minutes, because
of memory leaks.)

## Inventory

### 1. GraphQL calls from the Rails wardrobe

All go through `apolloClient.js` → `impress-2020.openneo.net/api/graphql`.

**Core wardrobe** (blocks retirement):

| Operation | File | Notes |
|---|---|---|
| `OutfitPetAppearance`, `OutfitPetAppearanceById` | `components/useOutfitAppearance.js` | Biology layers. `/species/:id/colors/:id/pet_type.json` is a starting point. |
| `OutfitItemsAppearance` | `components/useOutfitAppearance.js` | Object layers for worn items. May mostly be covered by `/items/:id/appearances.json`. |
| `OutfitStateItems`, `OutfitStateItemConflicts` | `WardrobePage/useOutfitState.js` | Item metadata and zone conflicts. |
| `PosePicker` | `WardrobePage/PosePicker.js` | Available poses for a species/color. |
| `SpeciesColorPicker` | `components/SpeciesColorPicker.js` | All species and colors. Static enough to embed in the page. |
| `SearchToolbarZones` | `WardrobePage/SearchToolbar.js` | All zones. Static enough to embed in the page. |
| `OutfitThumbnailIfCached` | `WardrobePage/WardrobePreviewAndControls.js` | Placeholder while loading. Could just be dropped. |
| `WriteItemFromLoader` | `loaders/items.js` | Writes REST results into the Apollo cache. Goes away with Apollo. |

**Support tools**: see [Support tools](#support-tools) below.

Already migrated to Rails REST (`app/javascript/wardrobe-2020/loaders/`): item
search, item appearances, outfit save/load, alt styles.

### 2. Non-GraphQL calls from the Rails wardrobe

| Call | Where | Status |
|---|---|---|
| `GET /api/validPetPoses` (Impress 2020 origin) | `components/SpeciesColorPicker.js` | Live dependency, fetched on every wardrobe load. A binary bitfield of species × color × pose. Easy to port, but keep the exact format: dti.py parses it too. |
| `GET /api/readFromArchive` (**Rails** origin) | `util.js`, via the "prefer archive" toggle in `OutfitControls.js` | **Probably already broken.** It's a relative URL from when Impress 2020 served the wardrobe, and Rails has no such route. The archive it reads is an S3 bucket, separate from Rails' local `NeopetsMediaArchive`. Port it or remove the toggle. |
| `POST /api/uploadLayerImage` (**Rails** origin) | `support/AppearanceLayerSupportUploadModal.js` | **Probably already broken**, for the same reason. Remove it along with the other support tools unless someone asks for it. |
| `outfits.openneo-assets.net/outfits/...png` | `components/OutfitThumbnail.js` | Saved outfit thumbnails. See images below. |
| `buildImpress2020Url("/__error__...")` | `util.js` | Placeholder URLs for unparseable images. Cosmetic; any placeholder works. |

### 3. Images

This is the biggest piece, but Rails already has part of it:
`lib/outfit_image_renderer.rb` composites layer PNGs with libvips and serves
`/outfits/new.png?species=…&color=…&pose=…&objects[]=…` (dti.py already uses
it).

What's still on Impress 2020:

- **Saved outfit images.** `Outfit#image_versions` produces
  `outfits.openneo-assets.net/outfits/:id/v/:updated_at/:size.png`. That
  hostname is a CDN in front of Impress 2020's `/api/outfitImage`. These URLs
  are **embedded across the internet** (Neopets petpages, Discord, Open Graph
  previews), and also in our own Your Outfits cards, fundraising features, and
  `OutfitThumbnail.js`. They need to keep working forever. Plan: serve the same
  URL shape from Rails using `OutfitImageRenderer`, then repoint the CDN's
  origin. Nothing outside needs to change.
- **Canvas-movie PNGs.** When an asset's manifest has no PNG,
  `SwfAsset#image_url` (`app/models/swf_asset.rb`) falls back to Impress 2020's
  `/api/assetImage`, which renders the movie in headless Chromium on request.
  This affects `OutfitImageRenderer` itself, the `<img>` fallback inside
  `swf_assets/show` (the item-page iframes), and the PNG links in the support
  outfit viewer. Assets don't change once published, so the replacement can be
  a render-once job (headless Chromium against Rails' own `swf_assets#show`
  page, with the PNG cached on disk next to the media archive) instead of
  rendering on every request. **First, count how many assets have a JS manifest
  but no PNG.** If the number is small, a one-time backfill might be most of the
  work.
- **`impress-asset-images.openneo.net`.** This old Classic DTI hostname
  points at Impress 2020 (confirmed November 2026). Impress 2020 rewrites
  `/asset-images/:type/…/:size.png` to `/api/assetImageRedirect`, which
  redirects to the best image we have. Old embeds use these URLs, so Rails needs
  an equivalent route before the DNS moves. (Rails' own legacy URLs use
  `aws.impress-asset-images.openneo.net`, which is unaffected.)

### 4. Other Rails references

- `/privacy` redirects to Impress 2020 (`config/routes.rb`). See
  [Privacy policy](#privacy-policy).
- The "DTI 2020" resource link on item pages (`items/_item_header.html.haml`,
  `ItemsHelper#impress_2020_url_for`, locale key
  `items.show.resources.impress_2020`).
- `impress_2020_meta_tags` (origin plus support secret) in
  `layouts/application.html.haml` and `outfits/edit.html.haml`.
- `config.impress_2020_origin` in all three environments.
- `Rails.application.credentials.impress_2020.support_secret`.

### 5. Infrastructure

- **MySQL user `impress2020`** with `ALL` on both databases, and a ufw rule
  letting the Impress 2020 box reach MySQL (`deploy/setup.yml`). Removing these
  is the biggest single security win.
- **Cron `model-needed-items`** on the Impress 2020 box (every 10 minutes,
  still in the crontab). It models Blue, Baby, Maraquan, and Mutant bodies via
  the NC Mall try-on. Rails' `items:auto_model` (every 2 minutes, based on body
  IDs) does the same job, so the cron is probably redundant. There's no flag
  gating it in the script.

  Two notes for checking whether it actually does anything:
  - Its crontab entry is `… 2>&1 > model-needed-items.log`. That order sends
    stderr to cron's own output, not the log file, so the log only ever shows
    successes. A quiet log can mean "failing every run".
  - It writes a `modeling_logs` row (with `pet_name` like `@<hash>`) for each
    success, and Rails never writes to that table. So
    `SELECT COUNT(*), MAX(created_at) FROM modeling_logs WHERE pet_name LIKE '@%'`
    shows whether it has done anything lately.

  Either way, turning it off is low-risk: if auto-modeling stalls, it shows
  quickly, and nothing hard-breaks.
- **DNS and CDN:** `impress-2020.openneo.net`, `impress-2020-box.openneo.net`,
  `outfits.openneo-assets.net` (Fastly, with Impress 2020 as origin), and
  `impress-asset-images.openneo.net`.
- **Unrelated:** `pets.neopets-asset-proxy.openneo.net` (used by `util.js`)
  isn't part of the Impress 2020 deploy. Leave it alone.

## External consumers

We're not committing to legacy support for unknown public callers. The one we
care about is the /r/Neopets Discord server, via
[rneopets/dti.py](https://github.com/rneopets/dti.py) (actively maintained as of
October 2026). Plan: add the Rails endpoints it needs, then send them a PR,
instead of keeping GraphQL alive.

What dti.py uses today:

- **GraphQL** (`dti/constants.py`, `API_BASE` in `dti/http.py`), about 16
  queries:
  - all species and colors, and zones
  - item search, including "fits pet"
  - items by IDs or names
  - pet appearance by species/color/pose, by ID, or by multiple IDs
  - pet appearance with items, and alt-style items
  - all appearances for a color
  - an outfit by ID
  - `petOnNeopetsDotCom`: load a pet by name. Rails' `/pets/load.json` covers
    this.
- **`/api/validPetPoses`**, the binary bitfield. If Rails serves the same bytes,
  their change is just a URL.
- **`/api/outfitImage?layerUrls=…`** via `utils.build_layers_url`. This makes
  the client assemble layer URLs itself. It's exported, but dti.py's own models
  no longer call it.
- **Already on Rails:** `outfit_image_url` uses `impress.openneo.net/outfits/new.png`,
  and alt styles use Rails REST.
- **Saved outfit images** via `outfits.openneo-assets.net`. This keeps working
  if we keep the URL shape.

Much of their GraphQL usage boils down to "give me the layers for this pet plus
these items" and "render this outfit". That's better served by a couple of
outfit-state JSON and PNG endpoints in Rails than by recreating the GraphQL
schema. Design the Rails endpoints for the wardrobe's needs first, then check
them against this list.

Impress 2020 also serves `/api/allNCTradeValues` and `/api/allWakaValues`
(already marked deprecated). Nothing of ours uses them, and they can simply go
away.

## Support tools

Every Impress 2020 support mutation logs to the support Discord channel
(`src/server/types/MutationsForSupport.js`), so that channel is a complete
record of usage. **As of November 2026 it's been quiet since March, except for
two "Removed layer" entries on August 23, 2026** (`removeLayerFromItem`). Many
tools have been made unnecessary by better scraping and modeling rules.

Plan: remove the Impress 2020 support tools from the wardrobe, and rebuild only
what volunteers actually ask for, as plain Rails pages with session auth. That
also gets rid of the shared `support_secret`.

| Wardrobe tool (GraphQL) | Rails equivalent today | Suggested |
|---|---|---|
| Pet appearance pose/glitch labeling (`PosePickerSupport*`, `setPetAppearancePose`, `setPetAppearanceIsGlitched`) | `pet_states#edit` / `#update` (pose, glitched), with an "unlabeled appearance" queue | Remove; link to Rails. |
| Item "explicitly body-specific" (`ItemSupportDrawerSetItemExplicitlyBodySpecific`) | `items#edit` (`explicitly_body_specific`, `is_manually_nc`) | Remove; link to Rails. |
| Manual special color (`ItemSupportDrawerSetManualSpecialColor`) | none | Remove; rebuild if asked. |
| Layer body ID (`ApperanceLayerSupportSetLayerBodyId`) | none | Remove; rebuild if asked. |
| **Remove layer from item** (`AppearanceLayerSupportRemoveButton`) | none | **The only tool used recently.** Rebuild first, as a button on a Rails item/layer page. |
| Bulk add layers (`AllItemLayersSupportModal*`) | none | Remove; rebuild if asked. |
| Upload layer image (`/api/uploadLayerImage`) | none (already broken) | Remove. |

When rebuilding any of these, also log to Discord (Rails has `DiscordNotifier`,
currently only for Neologin alerts) so the channel stays a usage record.

## Privacy policy

`/privacy` currently redirects to Impress 2020's page
(`src/app/PrivacyPolicyPage.js` there). Much of it describes the Impress 2020
era and is out of date, so don't port it verbatim:

| Section | Today |
|---|---|
| Auth0 account management | **Obsolete.** Rails uses its own accounts (Devise) plus NeoPass sign-in (OpenID Connect via Neopets). This section was already conditional on Auth0 mode. |
| Plausible analytics | **Still true, but self-hosted** (`analytics.openneo.net`, `application/_analytics`). |
| Sentry error tracking | **Partly true.** The server reports to a self-hosted Sentry-compatible endpoint (`health.openneo.net`). The wardrobe JS no longer reports errors anywhere (`logAndCapture` just logs to the console). |
| Linode and Fastly hosting | Still true. Fastly is the CDN for `outfits.openneo-assets.net`. |
| Outfits (public by URL; sequential IDs) | Still true. |
| Item lists (private / public / trading) | Still true. |
| Modeling contributions (public credit) | Still true. |
| _Missing:_ email | Password resets and account emails go through Fastmail SMTP. |
| _Missing:_ donations | Stripe (`config/initializers/stripe.rb`). |
| _Missing:_ account deletion and data export | Now self-serve in Rails. This replaces "use the contact link" for removing your data. |
| _Missing:_ Neopets page imports | Users paste their own Neopets pages for import; worth a sentence on what we keep. |

So: write a shorter, current policy as a Rails page (next to `about#terms`),
not a port.

## Plan

**Phase 1: wardrobe data.** No user-visible change.
- Rails endpoints for:
  - species, colors and zones (or embed them in the page)
  - valid poses (same binary format as `/api/validPetPoses`)
  - pet appearance by species/color/pose and by ID
  - outfit item metadata and zone conflicts
- Switch the core wardrobe queries to those endpoints. After this, Apollo is
  only used by support tools.
- Remove the "DTI 2020" item-page link. Write the new privacy page.
- Fix or remove the "prefer archive" toggle.

**Phase 2: support tools.** Remove the Impress 2020 support UI and
`useSupport`/`support_secret`. Rebuild "remove layer from item" in Rails. Then
Apollo and `graphql` can leave the bundle entirely.

**Phase 3: images.**
- Serve `/outfits/:id/v/:updated_at/:size.png` (and the unversioned form) from
  Rails via `OutfitImageRenderer`.
- Replace the canvas-movie PNG fallback with render-once-and-cache.
- Point `Outfit#image_versions` and `OutfitThumbnail.js` at the new path, then
  repoint the `outfits.openneo-assets.net` CDN origin at Rails. Keep the
  hostname, because of embeds.
- Port `/asset-images/…` (the `assetImageRedirect` logic) to Rails, then move
  `impress-asset-images.openneo.net` DNS to Rails.

**Phase 4: dti.py.** Send rneopets/dti.py a PR moving them to the Rails
endpoints, ideally in time to land before shutdown.

**Phase 5: shutdown.**
- Redirect `impress-2020.openneo.net` to Rails:

  | Impress 2020 path | Rails path |
  |---|---|
  | `/`, `/outfits/new`, `/outfits/:id`, `/items/:id` | same |
  | `/items/search/:query` | `/items?q=:query` |
  | `/user/:id/lists`, `/user/:id/lists/{owns,wants}/:listId` | `/user/:id/closet` |
  | `/your-outfits`, `/modeling`, `/donate`, `/terms`, `/privacy` | same |
  | `/support/petAppearances` | the unlabeled-appearances flow |
  | `/conversion` | home, or drop it |
  | `/api/outfitImage?id=…` | Rails outfit image |
  | `/api/*` (everything else) | 410 Gone |

- Turn off the box and its cron jobs. (`model-needed-items` can be turned off
  earlier, any time.)
- Drop the `impress2020` MySQL user and ufw rule. Delete
  `impress_2020_origin`, `impress_2020_meta_tags`, `impress-2020-config.js`,
  `apolloClient.js`, the `impress_2020` credentials, and the matching
  `deploy/setup.yml` steps.

**Then:** the `openneo_id` → `openneo_impress` database consolidation is
unblocked. Its branch, `feature/consolidate-auth-database`, has no common
history with current `main`, so it will need re-landing (a rebase or
cherry-picks), not a merge.

## Open questions

- How many canvas-movie assets have no manifest PNG? (This sizes Phase 3.)

## See Also

- [Customization Architecture](./customization-architecture.md): explains the data model
- `app/javascript/wardrobe-2020/loaders/`: already-migrated REST calls
- `lib/outfit_image_renderer.rb`: Rails outfit image rendering
