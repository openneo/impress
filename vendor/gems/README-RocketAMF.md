# RocketAMF Vendored Gem

_Fix and docs authored by Claude Code, with Matchu's supervision. I'm not super familiar with C extensions in Ruby, but the edit seems small and safe, and pet loading still works as expected!_

This directory contains a vendored, patched version of RocketAMF 1.0.0.

## Why Vendored?

RocketAMF is a critical dependency for DTI's "modeling" system - it enables communication with Neopets.com's legacy Flash/AMF (Action Message Format) API to fetch pet appearance data. However, the upstream gem has not been maintained for modern Ruby versions.

## What Was Changed?

**File modified**: `ext/rocketamf_ext/class_mapping.c`

**Problem**: Ruby 3.4 introduced stricter type checking for `st_foreach` callback functions. The original code used incorrect function pointer types that were accepted in older Ruby versions but rejected in Ruby 3.4+.

**Fix**: Updated the `mapping_populate_iter` callback function signature (line 340) to match Ruby 3.4's requirements:

```c
// BEFORE (Ruby < 3.4):
static int mapping_populate_iter(VALUE key, VALUE val, const VALUE args[2])

// AFTER (Ruby 3.4+):
static int mapping_populate_iter(st_data_t key_data, st_data_t val_data, st_data_t args_data) {
    VALUE key = (VALUE)key_data;
    VALUE val = (VALUE)val_data;
    const VALUE *args = (const VALUE *)args_data;
    // ... rest of function unchanged
}
```

The function body remains identical - we just cast the `st_data_t` parameters to the expected `VALUE` types at the start of the function.

## Upstream Status

**Repository**: https://github.com/rubyamf/rocketamf
**Last commit**: 2018
**Issue**: No active maintenance; Ruby 3.4 compatibility not addressed upstream

We chose to vendor this fix rather than maintain a full fork because:
1. RocketAMF functionality is stable - we don't expect to need updates
2. The community demand is low (Neopets' Flash API is legacy)
3. A vendored gem is simpler to maintain than a hosted fork

## Testing

After applying the fix, verified:
- ✅ Gem compiles successfully on ARM (aarch64-linux) with Ruby 3.4.5
- ✅ Gem loads without errors: `require 'rocketamf'`
- ✅ C extension works: `RocketAMF::ClassMapping.new`
- ✅ End-to-end Neopets API integration functional

## Updating This Gem

If you need to update RocketAMF in the future:

1. Clone the upstream repo: `git clone https://github.com/rubyamf/rocketamf.git`
2. Apply the fix to `ext/rocketamf_ext/class_mapping.c` (see above)
3. Build the gem: `gem build RocketAMF.gemspec`
4. Unpack to vendor: `gem unpack RocketAMF-X.X.X.gem`
5. Update the Gemfile path if version changed
6. Test thoroughly with `bundle install` and Neopets modeling functionality

## Alternative Solutions Considered

- **Fork to GitHub**: Too much maintenance overhead for a single file change
- **Downgrade Ruby**: Would miss out on Ruby 3.4+ features and security updates
- **Pure-Ruby AMF library**: None exist with active maintenance
- **Patch at runtime**: C extension issues can't be patched from Ruby

---

**Fix applied**: 2025-10-30
**Ruby version**: 3.4.5
**Architecture**: ARM64 (aarch64-linux)
