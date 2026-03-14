# Personal Logistic Plates

## Overview

Personal Logistic Plates adds special floor plates that automatically transfer requested items from nearby containers directly into your inventory when you step on them. It provides a straightforward, localized way to handle personal resupply without a full logistic network.

![Mod Demonstration](../assets/plp_demo.webm)

## Usage

1. Craft a Personal Logistic Plate and place it on the ground near your storage containers.
2. Set your desired item requests in your personal logistic slots.
3. Step on the plate. Items will automatically transfer from nearby containers to fulfill your requests.

## Plate Tiers

- Tier 1: Base range from the mod setting.
- Tier 2: 3x the base range, larger footprint, higher crafting cost.
- Tier 3: 7x the base range, largest footprint, highest crafting cost.
- Tier 4 (Vehicle Plate): Massive 5x5 plate designed for drive-on vehicle resupply with 12x the base range functionality.

## Transfer Behavior

- Plates pull from standard and logistic chest-style containers in range.
- Holding any plate provides a real-time area of effect visual radius indicator for positioning.
- Trash management: Unwanted items from your personal or vehicle trash slots are automatically pulled and deposited into directly touching containers, falling back to any nearby Active Provider chests.
- Transfers are rate-limited per tier instead of instant:
  - Tier 1: 30 items/second
  - Tier 2: 90 items/second
  - Tier 3: 210 items/second
  - Tier 4: 450 items/second
- Transfer throughput scales with plate quality:
  - Normal: 1.0x
  - Uncommon: 1.3x
  - Rare: 1.6x
  - Epic: 1.9x
  - Legendary: 2.2x
- Successful transfers render moving item sprites with light pulses from source container to player.
- Runtime uses movement-triggered plate detection plus short-lived per-plate container caching to reduce lag.

## License

This mod is licensed under the MIT License.
