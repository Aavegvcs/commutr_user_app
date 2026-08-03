# Backend (.NET) Prompt — Support for Android Live Tracking Notification

> **How to use this document:** paste the whole thing as the opening prompt to a
> senior .NET engineer (or an AI coding assistant working on the Commutr backend).
> It states what the mobile app already consumes today, what it now needs, and
> what is explicitly out of scope.

---

## ROLE

You are a **SENIOR .NET BACKEND ENGINEER** working on the Commutr backend
(ASP.NET Core + SignalR). You are also acting as a mentor: explain your reasoning
and the trade-offs, don't just emit code.

**Work interactively. Do NOT start changing code immediately.**

1. Inspect the existing tracking hub, DTOs, and trip-status pipeline.
2. Explain what exists today and where the gaps are.
3. Propose a plan with a migration/compatibility story.
4. Wait for approval at each major phase.
5. Implement.
6. Test.
7. Explain what changed.

---

## CONTEXT — WHAT ALREADY EXISTS AND MUST NOT BREAK

The Android app has just shipped an **ongoing live-tracking notification**
(Uber/Zomato style) that updates as a trip progresses:

```
Pickup in 7 min  →  6 min  →  4 min  →  Driver has arrived
                 →  Trip started  →  Trip completed  →  notification ends
```

It is built **entirely on existing backend contracts** — no backend change was
required to ship it. Everything below is already in production and is consumed by
the app today. **Treat all of it as a hard compatibility constraint.**

### SignalR hub

| Item | Value |
|---|---|
| Hub URL | `{appBasePath}/hubs/route-tracking` |
| Join method | `JoinRouteTrackingGroup(int dsId)` |
| Leave method | `LeaveRouteTrackingGroup(int dsId)` |
| Server→client event | `ReceiveRouteLocation` |
| Auth | JWT bearer via `accessTokenFactory` |

The client uses `withAutomaticReconnect()` **plus** its own manual reconnect loop
with backoff `5s, 10s, 20s, 30s, 60s`, and a 25-second client-side heartbeat. On
reconnect it **re-invokes `JoinRouteTrackingGroup`** with the last `dsId`.

### `ReceiveRouteLocation` payload (consumed as-is)

```jsonc
{
  "dsId": 12345,
  "latitude": 28.5930,
  "longitude": 77.0490,
  "speed": 34.5,
  "gpsTime": "2026-08-03T09:14:22",
  "tripStatusCode": 3,
  "tripStatusName": "In Progress",
  "source": "device",
  "panic": false,
  "logId": 987654,
  "miscellaneous": { "speed": 34.5, "gpsLoss": false, "networkLoss": false, "bearing": 145.0 },
  "passengers": [
    {
      "empId": 777, "employeeID": "E777", "firstname": "Rahul", "lastName": "Sharma",
      "paxOrder": 2, "tripType": 1,
      "plannedLat": 28.61, "plannedLng": 77.20,
      "plannedScheduleTime": "2026-08-03T09:20:00",
      "EtaDeviationMinutes": 3,
      "paxTrackingStatus": "Not Picked Up",
      "empSigninTime": null, "empSignOutTime": null,
      "cabReachedTime": null, "reachedHomeTime": null,
      "noShow": false, "otp": 4821
    }
  ]
}
```

Notes on current client tolerance (**do not rely on these as licence to be
sloppy — they exist because the backend is currently inconsistent**):

- Nested objects/arrays are accepted either as real JSON **or as JSON-encoded
  strings**. The client defensively decodes both.
- `etaDeviationMinutes` is read from **either** `etaDeviationMinutes` **or**
  `EtaDeviationMinutes` (casing is inconsistent today).
- Numbers are accepted as number or string.

### REST endpoints

| Endpoint | Purpose |
|---|---|
| `POST /Tracking/status?DsId={tripId}` | Full trip status + passenger list |
| `GET  /UserApp/GetUserCabTracking` | Driver/vehicle/OTP detail |
| GPS route endpoint (`DsId` query) | `plannedRoutePolyline`, `actualRoutePolyline`, `latestGps` |

`POST /Tracking/status` returns (fields the notification depends on marked ⭐):

```
dsId, isTripFound, locCode, dsDate, tripTypeCode, tripType ⭐, tripTypeName,
totalPax, scheduledStartTime, scheduledEndTime, actualStartTime, actualEndTime,
plannedRouteDistance, plannedTotalDuration, hasPlannedRoutePolyline,
transTripStatusCode, transTripStatusName,
latestGpsStatusCode, latestGpsStatusName,
effectiveTripStatusCode, effectiveTripStatusName,
latestLat, latestLng, latestSpeed, latestGpsTime, latestGpsSource, panic,
driverId, driverName ⭐, driverMobileNo, driverProfileImage,
vehicleId, vehicleNo ⭐, vehicleType, fuelType,
isActive, isCompleted ⭐, shouldUseSignalR ⭐, shouldUsePolyline,
isPassengerPickedUp, trackingMessage, trackingMode,
officeLocName, officeLat, officeLng, officeAddress, officeDisplayName,
passengers[] ⭐
```

### `paxTrackingStatus` — the string values the client parses

The client normalises case, hyphens, and underscores (so `En-Route`, `en_route`,
and `EN ROUTE` all match), then maps to a phase:

**LOGIN / pickup trips (`tripType = 1`)**
| String | Phase |
|---|---|
| `Pending`, `Not Picked Up` | pending |
| `Picked Up`, `Completed` | done |
| `No Show` | noShow |

**LOGOUT / drop trips (`tripType = 2`)**
| String | Phase |
|---|---|
| `Pending`, `Not Boarded` | pending |
| `En-Route`, `In-Cab` | inProgress |
| `Reached-Home`, `De-Boarded`, `Dropped`, `Trip-Completed`, `Completed` | done |
| `No Show` | noShow |

⚠️ Semantic rule the client already enforces and the backend must respect:
**`cabReachedTime` alone does NOT mean dropped.** The cab merely arrived; the
passenger is still En-Route until they de-board. `reachedHomeTime` is what means
dropped.

### FCM

The app sends `fcmToken` to the backend on `verifyOtp`. There is **no
"update device token" endpoint yet** — see Ask 5.

---

## WHAT THE APP DOES TODAY (so you know what you're supporting)

- While the tracking screen is open, the app derives the ETA **client-side**:
  remaining planned-route distance ÷ GPS speed (fallback 25 km/h).
- When the tracking screen is **closed**, an Android foreground service
  (`dataSync`) keeps the process alive and the app opens its own SignalR
  connection to keep the notification updating.
- In that screen-closed state the app **cannot** compute the granular ETA (it
  needs the route polyline the map owns), so it falls back to server-provided
  status + deviation. **This is the single biggest reason for Ask 1 below.**

---

## THE ASKS

Ordered by value. Each states the problem, the request, and the acceptance
criteria. Please confirm feasibility per item before implementing.

---

### ASK 1 — Server-computed per-passenger ETA ⭐ HIGHEST VALUE

**Problem.** ETA is computed on the device from polyline geometry and GPS speed.
Three consequences:

1. Every device computes it slightly differently — the notification, the map, and
   any future iOS client can disagree.
2. When the tracking screen is closed, the app cannot compute it at all, so the
   ongoing notification degrades to coarse status text instead of a countdown.
   **This is a visible product regression in exactly the scenario the feature
   exists for.**
3. The client fallback of 25 km/h when the cab is stationary is a guess with no
   traffic awareness.

**Request.** Add an authoritative, server-computed ETA to **each passenger** in
the `ReceiveRouteLocation` payload:

```jsonc
"passengers": [
  {
    "empId": 777,
    "etaMinutesToStop": 7,                          // int, minutes to THIS pax's stop
    "etaSecondsToStop": 412,                        // optional, for smooth countdown
    "etaCalculatedAtUtc": "2026-08-03T09:14:22Z",   // so client can age/extrapolate
    "etaSource": "osrm",                            // "osrm" | "google" | "haversine" | "planned"
    "etaConfidence": "high"                         // "high" | "medium" | "low"
  }
]
```

Also add trip-level ETA to the office on LOGIN trips:
`etaMinutesToOffice`, `etaCalculatedAtUtc`.

**Notes.**
- `etaCalculatedAtUtc` is important: it lets the client extrapolate between
  pushes and detect a stale ETA rather than showing a frozen number.
- You already use **OSRM** for routing (per commit `ef1afda5`) — reuse it.
- Cap and clamp server-side (`0..1440`) so the client never renders nonsense.
- Return `null` rather than a fabricated value when it genuinely can't be
  computed; the client already handles a null ETA with a static headline.

**Acceptance criteria.**
- Field present on every passenger on every push, `null` allowed.
- Recomputed at least as often as the GPS push cadence.
- Monotonic-ish: no wild oscillation between consecutive pushes for a
  stationary cab (smooth/clamp server-side).

---

### ASK 2 — Explicit "driver arrived at this passenger's stop" signal

**Problem.** The mockup requires a distinct `Driver has arrived` state. The
client currently infers it from `paxTrackingStatus` strings, and I had to
guess-match `Arrived` / `Reached` / `Cab-Reached` because **no documented status
value means "cab is at the stop but the passenger hasn't boarded yet."**
`cabReachedTime` exists but, per the rule above, must not be treated as done.

**Request.** Either (preferred) emit an explicit `paxTrackingStatus` value for
this state — e.g. **`Arrived`** for pickups — **or** add a boolean:

```jsonc
{ "empId": 777, "hasCabArrivedAtStop": true, "cabArrivedAtStopUtc": "2026-08-03T09:19:40Z" }
```

**Please confirm which, and document the exact string**, so the client stops
guessing.

**Acceptance criteria.** A documented, stable signal that is true from the moment
the cab reaches the stop until the passenger boards or is marked no-show.

---

### ASK 3 — Trip lifecycle events on the hub (not just location)

**Problem.** The notification must react to `Trip Started` and
`Trip Completed`, and must **remove itself** when the trip ends. Today the client
learns about completion only by polling `POST /Tracking/status` for
`isCompleted`, or by inferring it when every stop is resolved. If a trip ends
while the app is backgrounded, **the ongoing notification can linger** until the
next poll.

**Request.** Add a lightweight server→client event on the same hub:

```jsonc
// event name: ReceiveTripStatusChange
{
  "dsId": 12345,
  "tripStatusCode": 5,
  "tripStatusName": "Completed",
  "changedAtUtc": "2026-08-03T10:02:11Z",
  "isTerminal": true          // client tears the notification down on true
}
```

Fire on: trip started, trip completed, trip cancelled, and any driver/vehicle
reassignment.

**Why a separate event rather than reusing `ReceiveRouteLocation`:** when a trip
completes, GPS pushes stop — so the terminal state can never arrive on the
location channel. That is precisely the case that leaves a stuck notification.

**Acceptance criteria.**
- Delivered to the `dsId` group.
- `isTerminal: true` for completed/cancelled.
- Sent **even when no further GPS is available**.

---

### ASK 4 — Vehicle model name

**Problem.** The notification is specced to show `DL01AB3453 • Honda City`. The
API exposes `vehicleNo` and an **integer** `vehicleType`, but no model-name
string, so the app currently shows the registration number only.

**Request.** Add to `POST /Tracking/status` and to the SignalR payload:

```jsonc
{ "vehicleModelName": "Honda City", "vehicleMake": "Honda", "vehicleColor": "White" }
```

`vehicleModelName` alone unblocks the UI. If `vehicleType` already maps to a
lookup table, exposing the resolved display string is sufficient.

**Acceptance criteria.** Nullable string; app falls back to `vehicleNo` when absent.

---

### ASK 5 — FCM data-message fallback + device-token endpoint

**Problem.** Two gaps:

1. **`main.dart` has a TODO**: FCM tokens rotate (reinstall, cleared data, FCM
   server rotation), and there is **no endpoint to push a refreshed token**. Today
   a rotated token silently stops receiving notifications until the next
   `verifyOtp`. This is an existing production bug, independent of this feature.
2. Android may kill the foreground service on aggressive OEM ROMs (Xiaomi, Oppo,
   Vivo). When that happens the socket dies and the notification freezes. An FCM
   data message is the only thing that can revive it.

**Request 5a — device token endpoint.**
```
POST /UserApp/UpdateDeviceToken
{ "empId": 777, "fcmToken": "...", "platform": "android", "appVersion": "1.0.13+15" }
```

**Request 5b — silent data-only FCM on meaningful trip changes.**

```jsonc
{
  "data": {
    "type": "live_trip_update",
    "dsId": "12345",
    "empId": "777",
    "etaMinutes": "7",
    "paxTrackingStatus": "Not Picked Up",
    "tripStatusName": "In Progress",
    "isTerminal": "false",
    "vehicleNo": "DL01AB3453",
    "driverName": "Rahul"
  },
  "android": { "priority": "high" }
}
```

**Critical requirements:**
- **`data`-only. No `notification` block.** A `notification` block makes Android
  render its own banner, which would appear *alongside* the ongoing notification
  — the user would see two. The app must render it itself.
- Send on **meaningful change only** — status transitions, ETA crossing a
  threshold (e.g. every 2 min, or the 10/5/2/arrived boundaries) — **not** per GPS
  ping. FCM throttles high-frequency sends and this would drain battery.
- Always send the terminal event so the notification can be cleared.

**Acceptance criteria.** Data-only payload; all values as strings (FCM data
values must be strings); one message per meaningful change; terminal guaranteed.

---

### ASK 6 — Contract hygiene (low effort, removes client hacks)

These exist to delete defensive code the client currently carries:

1. **Fix `EtaDeviationMinutes` casing.** The client reads both
   `etaDeviationMinutes` and `EtaDeviationMinutes`. Pick **camelCase**
   (`etaDeviationMinutes`) consistently. Keep the old key as a duplicate for one
   release so old app versions don't break, then drop it.
2. **Always send nested objects as real JSON**, never JSON-encoded strings. The
   client decodes both; that tolerance should become unnecessary.
3. **Never send `0` / `0.0` as a placeholder for "unknown"** coordinates or
   schedule times. Send `null`. The client currently special-cases `lat != 0`,
   which would break for a genuine location near the equator/prime meridian.
4. **Document the authoritative `tripStatusCode` → `tripStatusName` enum.** The
   client currently has three overlapping status fields
   (`transTripStatus*`, `latestGpsStatus*`, `effectiveTripStatus*`) with no
   documentation of precedence. **Please state which one is authoritative for
   "is this trip live".**

---

## OUT OF SCOPE

- iOS Live Activities (a later phase; the APNs push-to-start channel will be a
  separate ask).
- Changing the existing SignalR hub URL, method names, or event names.
- Any breaking change to `POST /Tracking/status` — **additive fields only.**

---

## HARD CONSTRAINTS

1. **Backward compatibility is non-negotiable.** Production app versions are live
   and parse these payloads today. **Additive changes only** — do not rename,
   retype, or remove any existing field. A rename ships a broken app to every
   user who hasn't updated.
2. Every new field must be **nullable** and safe to omit; the client must keep
   working when it's absent.
3. Do not increase `ReceiveRouteLocation` push frequency. The client already
   throttles its own notification updates to ~15 s; more pushes cost battery
   without improving UX.
4. Payload size matters — this streams to mobile over cellular. Prefer adding a
   handful of scalars over nesting new objects.

---

## DELIVERABLES

1. A short written analysis of the current tracking pipeline and where each ask
   fits (which service, which DTO, which SignalR hub method).
2. A phased implementation plan, sequenced by value and risk, with the
   compatibility story for each phase.
3. Updated DTOs / hub methods / FCM sender.
4. Unit tests for the ETA computation, especially: stationary cab, missing GPS,
   passenger already dropped, and the clamping bounds.
5. Updated API documentation, **including the authoritative
   `paxTrackingStatus` and `tripStatusCode` enums** — the client is currently
   string-matching against undocumented values, which is the single largest
   source of fragility in this integration.

---

## FIRST STEP

**Do not write code yet.** Start by reporting:

1. Which asks are already partially supported by existing fields I may have missed.
2. Which asks are cheap versus expensive, and why.
3. Your recommended sequencing.
4. For **Ask 1** specifically: where per-passenger ETA should be computed
   (existing OSRM integration? a new service? cached per trip and refreshed on a
   cadence?), and what that costs per push at current trip volume.
