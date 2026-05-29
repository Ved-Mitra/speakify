# Speakify

A decentralized, multi-device audio syncing app that transforms a cluster of smartphones into a unified, synchronized speaker system for your TV, console, or media player.

## 📱 The Problem
We’ve all experienced it: TV speakers that are too quiet, dialogue that gets washed out, or situations where you want to watch a late-night movie with friends without waking up the rest of the house. Existing solutions require expensive hardware transmitters or are locked into specific hardware ecosystems (e.g., Apple's Share Audio, which is limited to two pairs of AirPods). 

## 💡 The Solution
SyncCast allows a group of smartphones (up to 10) to act as a coordinated speaker array. 

1. **The Master Device:** Connects directly to the source media player (Television, Gaming Console, PC) via Bluetooth or an auxiliary input.
2. **The Slave Devices:** Connect seamlessly to the Master device.
3. **The Output:** The Master captures the external audio stream and dynamically broadcasts it to all connected phones in perfect, low-latency synchronization, creating an instant surround-sound or multi-headphone environment.

## 🛠️ Proposed Architecture
To overcome standard Bluetooth bandwidth limitations and ensure millisecond-accurate sync across varying hardware brands, the app utilizes a hybrid network model:

* **Audio Input:** Bluetooth Classic or Wired AUX (Source device ➡️ Master Phone)
* **Audio Distribution:** Wi-Fi Local Hotspot / Wi-Fi Direct (Master Phone ➡️ Slave Phones)
* **Sync Mechanism:** A custom dynamic latency-compensation algorithm to ensure zero audio-to-video drift ("lip-sync delay").

## ✨ Features (Roadmap)
- **Multi-Device Pairing:** Support for up to 10 simultaneous devices.
- **Dynamic Latency Adjustment:** Manual and automatic audio calibration controls to sync perfectly with actors' lips on-screen.
- **Individual Volume Control:** Every user can adjust the volume directly on their own device without affecting others.
- **Cross-Platform Compatibility:** Designed to bridge iOS and Android devices seamlessly over local Wi-Fi networks.