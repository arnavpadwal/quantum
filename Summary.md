# Project Quantum: Summary

## 🌟 Project Purpose

**Quantum** is a decentralized, serverless, and **post-quantum resistant** peer-to-peer (P2P) messaging application built with Flutter. Its primary goal is to provide a secure communication platform that is resilient against both contemporary privacy threats and future attacks from large-scale quantum computers.

By leveraging the massive address space of **IPv6**, Quantum enables direct device-to-device communication without the need for central servers or complex NAT traversal mechanisms. All cryptographic operations happen locally; no data ever touches a third-party server.

---

## 🛠️ Key Technical Concepts

### 1. Post-Quantum Cryptography (PQC)
The core innovation of Quantum is its forward-thinking security model:
- **CRYSTALS-Kyber (Kyber768)**: A NIST-standardized (FIPS 203), lattice-based Key Encapsulation Mechanism (KEM). Used to securely exchange symmetric keys, safe from both classical and quantum adversaries, guarding against "harvest now, decrypt later" attacks.
- **AES-256-GCM**: Used for symmetric message encryption and authenticated integrity once the shared secret is established via Kyber.

### 2. Pure TCP/IPv6 P2P Networking
- **Direct Addressing**: Utilizes global unicast IPv6 addresses to bypass the need for STUN/TURN servers or NAT traversal.
- **Protocol**: Fully refactored to **TCP (Transmission Control Protocol)** for reliable, ordered communication between peers. Newline-framed JSON is transmitted over persistent `Socket` connections.
- **Port**: Listens on TCP port **8888** on `[::]` (all IPv6 interfaces).
- **Dynamic IP Tracking**: When a handshake arrives from a known public key at a new IP, the contact record is silently updated, maintaining connections through IP changes.

### 3. QR Code-Based Contact Exchange
- Contacts are added by scanning a QR code, which encodes the peer's **public key + IPv6 address** as JSON.
- This eliminates manual key/IP entry and enables a clean UX flow.

### 4. Decentralized Architecture
- **Serverless**: No central server stores messages, manages users, or brokers connections.
- **Local-First**: All data (messages, keys, contacts) is stored entirely on-device using **Hive**, a fast, encrypted NoSQL database.
- **Settings Box**: A dedicated `settings` Hive box tracks onboarding status and persistent user preferences.

---

## 🚀 Current Progress (v0.5.0-alpha)

### ✅ Completed
- **TCP P2P Networking**: Fully functional `ServerSocket`/`Socket`-based P2P service with real-time connection management and network-change re-initialization.
- **Post-Quantum Security**: Kyber768 KEM with AES-256-GCM message encryption. Tie-breaking handshake protocol prevents race conditions when both sides connect simultaneously.
- **QR Contact Exchange**: `share_contact_screen.dart` generates a live QR; `add_contact_screen.dart` uses `mobile_scanner` to decode and add contacts.
- **Onboarding Flow**: Animated `PageView` carousel on first launch covering Post-Quantum Security, Pure P2P, and Zero Cloud Harvesting.
- **Material 3 UI Revamp**: Complete removal of all glassmorphism (backdrop filters, gradients, blurs). All screens now use clean flat Material 3 components with `#0b8ce9` blue accent, supporting system Light/Dark mode.
- **Profile Setup**: Automatic Kyber768 key pair generation, display name + avatar selection.
- **Messaging UI**: Real-time chat with sent/delivered/read receipts, date separators, and empty-state illustration.
- **Encrypted Local Storage**: Hive-based persistence for profiles, contacts, messages, and settings.
- **Routing Logic**: `FutureBuilder` in `main.dart` routes to Onboarding → Profile Setup → Chats Home based on `hasSeenOnboarding` and profile existence.

### 🔧 In Progress
- **Notification Service**: Local push notifications work on Linux; Android delivery reliability under investigation.
- **TCP Connection Recovery**: Devices on the same LAN successfully connect after app restart; investigating `Connection Refused (errno 111)` edge cases that occur when the remote app is not yet listening.

---

## 🧠 Important Decisions Made

1. **TCP over UDP**: The project began with UDP (matching a successful Python prototype), but was definitively migrated to TCP for reliable ordered delivery, which is critical for the cryptographic handshake sequence.
2. **IPv6 Native**: Selected over IPv4 to ensure direct public routability and avoid NAT traversal complexity that typically cripples P2P mobile apps.
3. **Kyber over RSA/ECC**: Proactive adoption of NIST FIPS 203 post-quantum algorithms protects against the "harvest now, decrypt later" threat, where adversaries store encrypted traffic for future quantum decryption.
4. **Local-Only Storage**: Decided against any cloud synchronization to maintain absolute user privacy and data ownership.
5. **QR Code Contact Exchange**: Replaced the original manual public key + IP entry with a QR scan flow to eliminate transcription errors and dramatically improve UX.
6. **Material 3 Flat Design**: Replaced iOS-style glassmorphism (backdrop filters, translucent layers) with the clean, flat Fintracker-inspired Material 3 aesthetic for a more professional, cross-platform look.
7. **Kotlin Session Dir Fix**: Added `kotlin.project.persistent.dir=/tmp/kotlin_persistent_dir` to `~/.gradle/gradle.properties` to fix a crash caused by Kotlin daemons attempting to write session files inside the read-only system Flutter installation at `/usr/lib/flutter/`.

---

## 📝 TODO / Future Roadmap

### **Immediate Fixes**
- [ ] **Notification Service**: Repair and optimize the background notification system for Android.
- [ ] **Code Hygiene**: Refactor placeholders, remove dead code and files, add meaningful inline documentation.
- [ ] **Real-Time IP/QR Updates**: Ensure QR and IP display refresh immediately on network interface changes.

### **Near-Term Features**
- [ ] **Connection Robustness**: Improve TCP retry/reconnect logic; add exponential backoff for handshake failures.
- [ ] **File Sharing**: Extend the P2P session to support encrypted file transfers as a streaming blob.
- [ ] **Group Chats**: Design and implement a decentralized multi-party chat protocol.

### **Advanced Goals**
- [ ] **Decentralized Discovery Ledger**: Publish `Encrypt(IP_A, PK_B)` onto a shared ledger so only `B` can decrypt `A`'s IP. Prevents IP leakage in QR codes while enabling remote peer discovery without a central server.
- [ ] **Dynamic Per-Contact Keys**: Each contact receives a unique key derivative, making the social graph traceable with authorization while preserving deniability externally.
- [ ] **SIM-Bound Alphanumeric IDs**: 6-character human-readable IDs tied to SIM for account verification — planned only for mobile builds so desktop operation remains unaffected.
- [ ] **Tor Routing**: Optional onion routing layer for enhanced anonymity when global IPv6 routing is undesirable.

---

> [!NOTE]
> This project is currently in an **Alpha** state (v0.5.0-alpha). The cryptographic foundations (Kyber768 + AES-256-GCM) are solid and functional. The TCP P2P layer is operational on both Android and Linux desktop. Active work is focused on connection reliability and notification delivery.
