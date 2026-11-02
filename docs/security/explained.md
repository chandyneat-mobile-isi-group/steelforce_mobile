# App Security, Explained Simply

> A plain-language guide to how the SteelForce app protects itself.
> For each attack it explains **what the attacker tries**, **what stops them**,
> and **where that protection lives in the code**.
>
> Want the short technical version? Read [the security overview](README.md).

---

## Contents

1. [The big idea: layers](#1-the-big-idea-layers)
2. [Attack 1: someone steals the phone](#2-attack-1-someone-steals-the-phone)
3. [Attack 2: copying data through a backup](#3-attack-2-copying-data-through-a-backup)
4. [Attack 3: spying on the network](#4-attack-3-spying-on-the-network)
5. [Attack 4: reverse engineering the app](#5-attack-4-reverse-engineering-the-app)
6. [Attack 5: tampering with the app](#6-attack-5-tampering-with-the-app)
7. [Attack 6: attacking the API directly](#7-attack-6-attacking-the-api-directly)
8. [Attack 7: faking a visit location](#8-attack-7-faking-a-visit-location)
9. [Attack 8: secrets leaking through logs](#9-attack-8-secrets-leaking-through-logs)
10. [How the Keychain migration works](#10-how-the-keychain-migration-works)
11. [Rules for every developer](#11-rules-for-every-developer)
12. [What you still need to do](#12-what-you-still-need-to-do)
13. [Glossary](#13-glossary)
14. [FAQ](#14-faq)

---

## 1. The big idea: layers

No single protection is perfect. Good security stacks **several layers**, so an
attacker who gets past one still meets the next. Think of a bank: a locked
door, then a guard, then a vault, then a camera.

```
            ┌───────────────────────────────────────────┐
 Layer 4    │  BACKEND checks every request             │  ← the only layer an
            │  (who are you? are you allowed?)          │    attacker cannot remove
            ├───────────────────────────────────────────┤
 Layer 3    │  NETWORK: encrypted, pinned connection    │
            ├───────────────────────────────────────────┤
 Layer 2    │  APP: obfuscated, integrity-checked       │
            ├───────────────────────────────────────────┤
 Layer 1    │  DEVICE: encrypted database, secure keys  │
            └───────────────────────────────────────────┘
```

**The most important rule:** everything inside the app can be studied by an
attacker eventually. The app can make attacks **slow and expensive**. Only the
**backend** can make them **fail**. Remember this while reading the rest.

---

## 2. Attack 1: someone steals the phone

### What the attacker tries
A rep loses a phone in the steel yard. Someone picks it up, connects it to a
computer, and copies the app's files to read the customer list, prices and
orders.

### What stops them: the database is encrypted

All business data is stored in an **encrypted SQLite database (SQLCipher)**.
Without the key, the file is random bytes.

The key is built from **two halves**:

```
   Half 1: SALT                    Half 2: DEVICE KEY
   (built into the app)            (random, made on first launch)
         │                                │
         │                                │  stored in the phone's
         │                                │  secure hardware
         │                                │  (Keychain / Keystore)
         └──────────────┬─────────────────┘
                        ▼
                SHA-256( salt + device key )
                        ▼
               DATABASE PASSWORD
       (computed in memory, never saved)
```

**Why two halves?**
- The **salt** is inside the app, so an attacker can find it. On its own it is
  useless.
- The **device key** sits in the phone's secure hardware (iOS Keychain or
  Android Keystore). Copying the app's files does **not** copy it.
- The attacker needs **both**, so stealing the database file alone gets them
  nothing.

**Tokens** (the "you are logged in" proof) are also kept in secure hardware,
never in normal files.

📁 Code: [`lib/core/database/secure/`](../../lib/core/database/secure)
• Status: ✅ **Strong**

---

## 3. Attack 2: copying data through a backup

### What the attacker tries
Phones back themselves up (to iCloud or Google, or straight to a new phone
during setup). If the app's data goes into a backup, someone with access to
that backup, or to the new phone, gets the data **and possibly the keys**.

### What stops them

| Phone | Protection | What it means |
|---|---|---|
| Android | `allowBackup="false"` | No cloud backup of app data |
| Android 12+ | `data_extraction_rules.xml` **(new)** | Phone-to-phone transfer is blocked too. On Android 12+, `allowBackup` alone does **not** block it |
| iOS | Keychain set to **"this device only"** **(new)** | Tokens and the database key **never** leave this phone, not in a backup and not in a transfer |

**What does a rep see on a new phone?** They sign in, and the app downloads
their data from the server. That is the intended behaviour.

📁 Code: [`app_secure_storage.dart`](../../lib/core/database/secure/app_secure_storage.dart),
[`data_extraction_rules.xml`](../../android/app/src/main/res/xml/data_extraction_rules.xml)
• Status: ✅ **Strong**

---

## 4. Attack 3: spying on the network

### What the attacker tries
The attacker sits **between the phone and the server**. This is called a
"man-in-the-middle" (MITM). They might use a fake Wi-Fi hotspot, or a tool like
Burp Suite on their own phone. Their goal is to **read** traffic (tokens,
prices) or **change** it (alter an order).

```
   Phone  ──────►  ATTACKER  ──────►  Server
                   reads and
                   changes data
```

### Protection 1: HTTPS (TLS) everywhere ✅

HTTPS encrypts traffic between the phone and the server. On fake Wi-Fi the
attacker sees only scrambled bytes.
- **(New)** A release build **refuses to start** if the API address is
  `http://` (not secure). Nobody can ship a mistake by accident.
- **(New)** Android release builds block plain `http://` for every part of the
  app, including plugins.

### Protection 2: don't trust user-installed certificates ✅ (Android)

To read HTTPS traffic, the attacker installs **their own certificate** on the
phone, which tells the phone "trust me". **(New)** Android release builds now
ignore user-installed certificates, so this trick stops working.

### Protection 3: certificate pinning ⚠️ built, not switched on yet

HTTPS trusts **any** of the roughly 150 certificate authorities (CAs) in the
world. **Pinning** means: "for our API, trust **only** the certificate
authority **we** chose." A fake certificate from anyone else is rejected, even
if the phone otherwise trusts it.

**Why we check during the handshake (an important detail):**

```
  ❌ The common way (dio's validateCertificate):

     1. Connect
     2. SEND the request  ← token already sent to the attacker!
     3. Check the certificate → "bad!"  (too late)

  ✅ Our way (trust anchored in the TLS handshake):

     1. Connect → check the certificate → "bad!" → STOP
     2. (nothing is ever sent)
```

A test proves it: with a wrong certificate, the server receives **zero**
requests.

**Why is it off?** Pinning needs the real certificates of **your** API's
certificate authority. If we guess wrong, **every app stops working**. You must
add them (see [§12](#12-what-you-still-need-to-do)).

📁 Code: [`api_trust_anchors.dart`](../../lib/core/network/transport/api_trust_anchors.dart),
[`http_transport_native.dart`](../../lib/core/network/transport/http_transport_native.dart),
[`network_security_config.xml`](../../android/app/src/main/res/xml/network_security_config.xml)

---

## 5. Attack 4: reverse engineering the app

### What the attacker tries
They download the APK or IPA and use decompiler tools to read how the app
works: the API endpoints, the business rules, and any secrets hidden inside.

### Protection 1: obfuscation ✅ (new build script)

Obfuscation **renames everything** to meaningless names, so the code becomes
very hard to understand.

```
   Before obfuscation                After obfuscation
   ─────────────────                 ─────────────────
   class AuthInterceptor        →    class a5
   refreshToken()               →    b7()
   class DynamicKeyStore        →    class Kq
```

We checked the real release build: names such as `AuthInterceptor` and
`DynamicKeyStore` **no longer appear** in the app binary.

**How to use it:** always build releases with the script:

```bash
tool/build_release.sh appbundle    # Play Store
tool/build_release.sh apk
tool/build_release.sh ipa          # App Store
```

⚠️ A plain `flutter build appbundle --release` does **not** obfuscate the Dart
code. Always use the script.

### The "symbols" folder: keep it secret

Obfuscation makes crash reports unreadable too (`a5.b7` crashed…). The script
saves a **translation file** to `build/symbols/…` that turns them back into
real names.
- **Keep it** for every release, or you can never read that release's crashes.
- **Keep it private.** Anyone holding it can undo the obfuscation.

### Protection 2: no real secrets inside the app ✅

The API URL and the database salt are hidden (Envied obfuscation), but they are
**not treated as secrets**. Remember the rule: *anything in the app is public
eventually.* Real secrets stay on the server only.

📁 Code: [`tool/build_release.sh`](../../tool/build_release.sh) • Status: ⚠️ **Good,
not perfect.** Obfuscation slows attackers down; it does not stop them.

---

## 6. Attack 5: tampering with the app

### What the attacker tries
- **Modify the app:** decompile it, remove checks (for example the fake-GPS
  block), rebuild it, and install it.
- **Hook the app while it runs:** use a tool like **Frida** to change what
  functions return. For example, make "is location fake?" always answer "no".
- **Run on a rooted or jailbroken phone**, where the normal protections are
  switched off.

### What protects us today

| Protection | Status | What it does |
|---|---|---|
| **Firebase App Check** (Android) | ✅ | Google checks "is this the real app on a real phone?" before Firebase services such as SMS login answer |
| **Firebase App Check** (iOS) with **App Attest** | ✅ **(fixed)** | Apple's hardware proves the app is genuine. The missing setting (entitlement) is now added; before, iOS was using a weaker check |
| Release signing guard | ✅ | A release can never be signed with the debug key |

### What is still missing ❌

Nothing in the app checks for **root, jailbreak, Frida, debuggers or a modified
app**. The recommended fix is a library called **freeRASP** (free, made for
Flutter). It detects all of those and lets us react.

**Why not added yet:** it needs information only you have (see
[§12](#12-what-you-still-need-to-do)), and a **business decision**: what
should happen on a rooted phone? Options:

| Response | Good | Bad |
|---|---|---|
| Close the app | Strongest | Angry reps; false alarms block real work |
| **Warn, report to the backend, block orders and check-ins** (recommended) | Balanced | Takes more work to build |
| Only report silently | No impact on reps | Attacker continues |

---

## 7. Attack 6: attacking the API directly

### What the attacker tries
This one is the **most dangerous**. The attacker skips the app entirely and
talks to the server directly with a tool like Postman, using a real login.

```
   Normal:    Rep ──► App ──► API
   Attack:    Attacker ──► Postman / script ──► API   (no app at all!)
```

Then they might try:

| Attack | Example |
|---|---|
| **IDOR**: read other people's data | Change `/depots/123` to `/depots/124`, and see another rep's customer |
| **Price manipulation** | Send an order with `price: 1` instead of `price: 1000` |
| **Brute force** | Try thousands of passwords |
| **Replay** | Send the same "create order" request 50 times |
| **Scraping** | Download the whole customer list with a script |

### Why the app cannot fix this alone

Every protection inside the app (obfuscation, App Check, root detection) can be
**skipped**, because the attacker doesn't use the app. **Only the backend can
defend this.** Ask the backend team to confirm each of these:

| The backend must… | Stops |
|---|---|
| Check **"does this item belong to this user?"** on every request | IDOR |
| **Recalculate** prices and totals itself, never trusting the app's numbers | Price manipulation |
| **Limit** login attempts and request rates | Brute force, scraping |
| Reject **duplicate** requests (idempotency key) | Replay |
| **Verify App Check tokens** on important endpoints | "No app" attacks |

The last row needs the app and backend to work together: the app attaches a
proof ("I am the genuine app") and the backend checks it. **Today the app only
sends this proof to Firebase, not to our own API.** This is the #1 item to fix.

---

## 8. Attack 7: faking a visit location

### What the attacker tries
A rep uses a "fake GPS" app to check in at a customer they never visited.

### What stops them ✅
- Release builds **always block** mock GPS locations.
- Accuracy must be better than 50 m, and travel speed below 150 km/h (no
  teleporting).
- A VPN detector exists (switched off by default).
- An override needs a written reason, so there is an audit trail.

⚠️ These checks run **on the phone**, so a tampered app could skip them. The
backend should also check whether locations make sense.

📁 Code: [`fraud_policy.dart`](../../lib/features/my_visits/domain/entities/fraud_policy.dart)

---

## 9. Attack 8: secrets leaking through logs

### The risk
Developers print data to debug. Logs end up in bug reports, screenshots and
chats. On older Android phones other apps could even read them. A logged token
or password is a stolen account.

### What stops it ✅
- The app's logger **automatically hides** sensitive values: by name
  (`password`, `token`, `phone`…) **and** by shape (anything that looks like a
  JWT, an email or a phone number).
- Request and response bodies are **never** logged in release builds.
- Android release builds strip native debug logs.

📁 Code: [`app_logger.dart`](../../lib/core/logging/app_logger.dart)

---

## 10. How the Keychain migration works

This is the trickiest part of the upgrade.

### The problem
On iOS, you **cannot change** a saved item's protection level. You have to
**delete it and save it again**. If the app crashes **between** the delete and
the save, the item is **gone**.

For most items that is a small problem. For the **database key** it is a
disaster: lose it, and the encrypted database can never be opened again. Every
unsynced visit and order would be lost.

### The solution: back up first, then swap

```
  Step 1   Copy the value to a BACKUP slot           ┐
  Step 2   Delete and re-save the real item          │  crash here?
           (now protected "this device only")        │  → backup still exists
  Step 3   Read it back and compare                  │
  Step 4   Only if they match → delete the backup    ┘

  Next app start:
     Backup exists but real item is missing?  → restore from backup ✅
     Backup exists and real item is fine?     → just delete the backup
```

It runs **once**, on iOS only, at startup. If the phone is locked or anything
fails, it does nothing and tries again on the next launch. It **never** crashes
the app.

📁 Code: [`keychain_accessibility_migration.dart`](../../lib/core/database/secure/keychain_accessibility_migration.dart)
• Tests cover every crash point:
[`keychain_accessibility_migration_test.dart`](../../test/core/database/secure/keychain_accessibility_migration_test.dart)

---

## 11. Rules for every developer

### ✅ Always
- Build releases with `tool/build_release.sh`.
- Keep the `build/symbols/` folder of every release, privately.
- Store tokens and keys **only** through `appSecureStorage()`.
- Add any **new** secure-storage key to `SecureStorageKeys.all` (so the
  migration covers it).
- Use `https://` for every server.
- Ask: *"What if the attacker skips the app?"* If the answer is bad, it needs a
  backend check.

### ❌ Never
- Put a real secret (password, private key, admin token) in the app.
- Log tokens, passwords, phone numbers, prices or customer names.
- Store sensitive data in Hive's plain box, SharedPreferences or plain files.
- Commit `.env`, `env.g.dart`, `google-services.json`, keystores or
  `key.properties`.
- Copy `src/debug/.../network_security_config.xml` into `src/main`. The debug
  version is unsafe on purpose.
- Trust a price, total or permission that came from the app, on the backend.

---

## 12. What you still need to do

In order of importance:

| # | Task | Who | Why |
|---|---|---|---|
| 1 | **Make the backend verify App Check tokens** on login, order and check-in endpoints | Backend + App | Stops attackers calling the API without the real app ([§7](#7-attack-6-attacking-the-api-directly)) |
| 2 | **Switch on pinning:** get the API's root certificate and a backup root (PEM files) and paste them into `api_trust_anchors.dart` | You | Blocks traffic interception ([§4](#4-attack-3-spying-on-the-network)) |
| 3 | **Confirm the backend checks** in the [§7](#7-attack-6-attacking-the-api-directly) table | Backend | Only the backend can stop API abuse |
| 4 | **Add freeRASP.** Collect: the Play App Signing SHA-256 (Play Console → App integrity), the Apple Team ID, a security email, and the response decision | You + Product | Detects root, jailbreak, Frida and modified apps ([§6](#6-attack-5-tampering-with-the-app)) |
| 5 | **Check old leaks:** confirm the old Google Maps key was replaced and restricted. `env.g.dart` was once committed (commit `4978d40`) | DevOps | Old secrets in git history stay readable forever |
| 6 | Decide on **screenshot blocking** and a **fingerprint/PIN lock** | Product | Protects data on screen and on unlocked phones |
| 7 | **Test on a real iPhone:** install the old build, sign in, install the new build, and confirm you stay signed in with offline data intact | You | Verifies the Keychain migration on a real device |

---

## 13. Glossary

| Word | Meaning |
|---|---|
| **API** | The server address the app talks to, to get and send data |
| **App Attest** | Apple's way to prove "this is the genuine app on a real iPhone" |
| **App Check** | Firebase's service that asks Apple or Google for that proof |
| **CA (Certificate Authority)** | A company that issues HTTPS certificates (for example Let's Encrypt or Google Trust Services) |
| **Certificate pinning** | Trusting only specific CAs for our API instead of all of them |
| **Encryption** | Scrambling data so it can only be read with a key |
| **Frida** | A tool that changes how an app behaves while it runs |
| **IDOR** | Reading someone else's data by changing an ID in a request |
| **Jailbreak / Root** | Removing the phone maker's security limits |
| **Keychain / Keystore** | The secure vault inside iPhone / Android for keys and passwords |
| **MITM** | "Man-in-the-middle": an attacker between the phone and the server |
| **Obfuscation** | Renaming code to meaningless names so it's hard to understand |
| **RASP** | "Runtime protection": the app checks its own environment while running |
| **Salt** | Extra data mixed into a key so it can't be guessed from one part alone |
| **SQLCipher** | An encrypted version of the SQLite database |
| **TLS / HTTPS** | Encryption for data travelling over the network |
| **Token** | The digital "pass" that proves a user is logged in |

---

## 14. FAQ

**Is the app "hack-proof" now?**
No app is. The app is now **much harder** to attack on the phone and on the
network. The remaining big risk is **direct API abuse**, which only the backend
can close ([§7](#7-attack-6-attacking-the-api-directly)).

**Will reps notice any of these changes?**
No. Everything runs in the background. One difference: on a **new phone**, data
is not copied over; reps sign in and sync.

**Why is pinning built but switched off?**
Because a wrong pin breaks **every** installed app until it's updated. It needs
the real certificate files of your API's certificate authority, plus a backup.

**Can I still use `http://` and a proxy (Charles or Proxyman) while
developing?**
Yes, in **debug** builds. Release builds block both, on purpose.

**What if I lose the `build/symbols` folder?**
Crash reports from that release can't be decoded. Nothing breaks for users,
but debugging that release gets very hard. Archive it every time.

**Why does the Android build warn "unobfuscated DWARF debugging
information"?**
That warning is about a temporary file. We checked the final APK: it contains
no debug information. You can ignore it.

**Where are the technical details?**
[the security overview](README.md) has the technical summary and release checklist.
[docs/skills/security.md](../skills/security.md) has the engineering rules.
