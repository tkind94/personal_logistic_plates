# Personal Logistic Plates

Factorio 2.x compatible.

## Overview

Personal Logistic Plates is a Factorio mod that adds special plates which transfer items from nearby containers to the player's inventory based on logistic requests.

## Usage

1. Craft and place a Personal Logistic Plate within range of containers.
2. Set up your logistic requests in the player inventory.
3. Step on the plate to transfer items from nearby containers to your inventory.

## Plate Tiers

- Tier 1: Base range from the mod setting.
- Tier 2: 2x the base range, larger footprint, higher crafting cost.
- Tier 3: 3x the base range, largest footprint, highest crafting cost.

## Transfer Behavior

- Plates pull from standard and logistic chest-style containers in range.
- Transfers are rate-limited per tier instead of instant:
	- Tier 1: 30 items/second
	- Tier 2: 90 items/second
	- Tier 3: 180 items/second
- Successful transfers render moving item sprites with light pulses from source container to player.
- Runtime uses movement-triggered plate detection plus short-lived per-plate container caching to reduce lag.


## License

This mod is licensed under the MIT License.