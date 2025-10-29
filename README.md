<img src="https://i.imgur.com/mZ2FCfX.png" width="200" height="200" alt="Dress to Impress beach logo" />

# Dress to Impress

Dress to Impress (DTI) is a tool for designing Neopets outfits. Load your pet, browse items, and see how they look together—all with a mobile-friendly interface!

## Architecture Overview

DTI is a Rails application with a React-based outfit editor, backed by MySQL databases and a crowdsourced data collection system.

### Core Components

- **Rails backend** (Ruby 3.4, Rails 8.0): Serves web pages, API endpoints, and manages data
- **MySQL databases**: Primary database (`openneo_impress`) + legacy auth database (`openneo_id`)
- **React outfit editor**: Embedded in `app/javascript/wardrobe-2020/`, provides the main customization UI
- **Modeling system**: Crowdsources pet/item appearance data by fetching from Neopets APIs when users load their pets

### The Impress 2020 Complication

In 2020, we started a NextJS rewrite ("Impress 2020") to modernize the frontend. We've since consolidated back into Rails, but **Impress 2020 still provides essential services**:

- **GraphQL API**: Some outfit appearance data still loads via GraphQL (being migrated to Rails REST APIs)
- **Image generation**: Runs a headless browser to render outfit thumbnails and convert HTML5 assets to PNGs

See [docs/impress-2020-dependencies.md](./docs/impress-2020-dependencies.md) for migration status.

## Key Concepts

### Customization Data Model

The core data model powers outfit rendering and item compatibility. See [docs/customization-architecture.md](./docs/customization-architecture.md) for details.

**Quick summary**:
- `body_id` is the key compatibility constraint (not species or color directly)
- Items have different `swf_assets` (visual layers) for different bodies
- Restrictions are subtractive: start with all layers, hide some based on zone restrictions
- Data is crowdsourced through "modeling" (users loading pets to contribute appearance data)

### Modeling (Crowdsourced Data)

DTI doesn't pre-populate item/pet data. Instead:

1. User loads a pet (via pet name lookup)
2. DTI fetches appearance data from Neopets APIs (legacy Flash/AMF protocol)
3. New `SwfAsset` records and relationships are created
4. Over time, the database learns which items fit which pet bodies

This "self-sustaining" approach means the site stays up-to-date as Neopets releases new content, without manual data entry.

## Directory Map

### Key Application Files

```
app/
├── controllers/
│   ├── outfits_controller.rb       # Outfit editor + CRUD
│   ├── items_controller.rb         # Item search, pages, and JSON APIs
│   ├── pets_controller.rb          # Pet loading (triggers modeling)
│   └── closet_hangers_controller.rb # User item lists ("closets")
│
├── models/
│   ├── item.rb                     # Items + compatibility prediction logic
│   ├── pet_type.rb                 # Species+Color combinations (has body_id)
│   ├── pet_state.rb                # Visual variants (pose/gender/mood)
│   ├── swf_asset.rb                # Visual layers (biology/object)
│   ├── outfit.rb                   # Saved outfits + rendering logic (visible_layers)
│   ├── alt_style.rb                # Alternative pet appearances (Nostalgic, etc.)
│   └── pet/
│       └── modeling_snapshot.rb    # Processes Neopets API data into models
│
├── services/
│   ├── neopets/
│   │   ├── custom_pets.rb          # Neopets AMF/Flash API client (pet data)
│   │   ├── nc_mall.rb              # NC Mall item scraping
│   │   └── neopass.rb              # NeoPass OAuth integration
│   ├── neopets_media_archive.rb    # Local mirror of images.neopets.com
│   └── lebron_nc_values.rb         # NC item trading values (external API)
│
├── javascript/
│   ├── wardrobe-2020/              # React outfit editor (extracted from Impress 2020)
│   │   ├── loaders/                # REST API calls (migrated from GraphQL)
│   │   ├── WardrobePage/           # Main editor UI
│   │   └── components/             # Shared React components
│   └── application.js              # Rails asset pipeline entrypoint
│
└── views/
    ├── outfits/
    │   └── edit.html.haml          # Outfit editor page (loads React app)
    ├── items/
    │   └── show.html.haml          # Item detail page
    └── closet_hangers/
        └── index.html.haml         # User closet/item lists
```

### Configuration & Docs

```
config/
├── routes.rb                       # All Rails routes
├── database.yml                    # Multi-database setup (main + openneo_id)
└── environments/
    └── *.rb                        # Env-specific config (incl. impress_2020_origin)
```

**Documentation:**
- [docs/customization-architecture.md](./docs/customization-architecture.md) - Deep dive into data model & rendering
- [docs/impress-2020-dependencies.md](./docs/impress-2020-dependencies.md) - What still depends on Impress 2020 service

**Tests:**
- `test/` - Test::Unit tests (privacy features)
- `spec/` - RSpec tests (models, services, integrations)
  - Coverage is focused on key areas: modeling, prediction logic, external APIs
  - Not comprehensive, but thorough for critical behaviors

## Tech Stack

- **Backend**: Ruby on Rails (Ruby 3.4, Rails 8.0)
- **Frontend**: Mix of Rails views (Turbo/HAML) and React (for outfit editor)
- **Database**: MySQL (two databases: `openneo_impress`, `openneo_id`)
- **Styling**: CSS, Sass (moving toward modern Rails conventions)
- **External Integrations**:
  - **Neopets.com**: Legacy Flash/AMF protocol for pet appearance data (modeling)
  - **Neopets NC Mall**: Web scraping for NC item availability/pricing
  - **NeoPass**: OAuth integration for Neopets account linking
  - **Neopets Media Archive**: Local filesystem mirror of `images.neopets.com` (never discards old files)
  - **Lebron's NC Values**: Third-party API for NC item trading values ([lebron-values.netlify.app](https://lebron-values.netlify.app))
  - **Impress 2020**: GraphQL for some outfit data, image generation service (being phased out)

## Development Notes

### OpenNeo ID Database

The `openneo_id` database is a legacy from when authentication was a separate service ("OpenNeo ID") meant to unify auth across multiple OpenNeo projects. DTI was the only project that succeeded, so the apps were merged—but the database split remains for now.

**Implication**: Rails is configured for multi-database mode. User auth models live in `auth_user.rb` and connect to `openneo_id`.

### Rails/React Hybrid

Most pages are traditional Rails views using Turbo for interactivity. The **outfit editor** (`/outfits/new`) is a full React app that:

- Loads into a `#wardrobe-2020-root` div
- Uses React Query for data fetching
- Calls both Rails REST APIs (in `loaders/`) and Impress 2020 GraphQL (being migrated)

The goal is to simplify this over time—either consolidate into Rails+Turbo, or commit fully to React. For now, we're in a hybrid state.

## Deployment

- **Main app**: VPS running Rails (Puma, MySQL)
- **Impress 2020**: Separate VPS in same datacenter (NextJS, GraphQL, headless browser for images)
- Both services share the same MySQL database (Impress 2020 makes SQL calls over the network)

---

**Project maintained by [@matchu](https://github.com/matchu)** • **[OpenNeo.net](https://openneo.net)**
