# MatrixRTC: Relay vs Element Call deviations

Engineering reference for the MatrixRTC implementation. Maps every Relay call-path function to its Element Call / matrix-js-sdk counterpart and flags deviations that have either been confirmed against real-world traces or against the published MSCs.

## Sources used

- **MSC4143** ([toger5/matrixRTC](https://github.com/matrix-org/matrix-spec-proposals/blob/toger5/matrixRTC/proposals/4143-matrix-rtc.md)) — the not-yet-deployed `m.rtc.slot` / `m.rtc.member` sticky-event protocol. Production uses the legacy `m.call.member` shape.
- **MSC4195** ([hughns/matrixrtc-livekit](https://github.com/hughns/matrix-spec-proposals/blob/hughns/matrixrtc-livekit/proposals/4195-matrixrtc-livekit.md)) — the LiveKit `/get_token` endpoint and pseudonymous-identity scheme.
- **Element Call**, `src/livekit/openIDSFU.ts` ([livekit branch](https://github.com/element-hq/element-call/blob/livekit/src/livekit/openIDSFU.ts)) — the production credential-exchange path.
- **matrix-js-sdk**, `src/matrixrtc/` — the membership / encryption manager / LiveKit transport types.
- **lk-jwt-service**, `requests.go` + `handler.go` + `helper.go` ([element-hq/lk-jwt-service](https://github.com/element-hq/lk-jwt-service)) — the reference SFU auth service; what production homeservers actually run.

## File map

| Relay file | Responsibility | Element Call / js-sdk counterpart |
| --- | --- | --- |
| `RelayKit/Call/LiveKitCredentialService.swift` | Discover SFU URL, request OpenID token, exchange for LiveKit JWT | `element-call/src/livekit/openIDSFU.ts` |
| `RelayKit/Call/CallEncryptionService.swift` | Send `m.call.member` state event, derive HKDF keys, parse other peers from room state | `matrix-js-sdk/src/matrixrtc/MembershipManager.ts` + `RTCEncryptionManager.ts` |
| `RelayKit/Call/CallWidgetBridge.swift` | Speak the Widget API directly to the SDK's `WidgetDriver` to deliver Olm-encrypted to-device key payloads | `matrix-js-sdk/src/matrixrtc/ToDeviceKeyTransport.ts` (with SDK's `WidgetDriver` underneath) |
| `RelayKit/Call/CallViewModel.swift` | Orchestrate connect/disconnect sequencing, key install ordering, heartbeat | `matrix-js-sdk/src/matrixrtc/MatrixRTCSession.ts` |
| `RelayKit/Call/LiveKitLogBridge.swift` | Bridge LiveKit SDK logs into OSLog | (none — Element Call uses pino) |

## Per-function deviations

### `LiveKitCredentialService.fetchLiveKitTokenV2`

Lines 178–205 in `LiveKitCredentialService.swift`. Reference: `getLiveunitJWTWithDelayDelegation` in `openIDSFU.ts`.

| Field | Relay sends | Reference sends | Confirmed required by `lk-jwt-service`? |
| --- | --- | --- | --- |
| `room_id` | ✓ | ✓ | yes (`SFURequest.Validate()` in `requests.go`) |
| `slot_id` | **missing** | `"m.call#ROOM"` | **yes** (returns 400 `M_BAD_JSON` if missing) |
| `openid_token` | ✓ | ✓ | n/a (validated server-side) |
| `member.id` | `"<userID>:<deviceID>"` | `memberId` (a UUID generated at membership creation) | n/a (passed through to identity hash) |
| `member.claimed_user_id` | ✓ | ✓ | n/a |
| `member.claimed_device_id` | ✓ | ✓ | n/a |
| `delay_id` / `delay_timeout` / `delay_cs_api_url` | not sent | optionally sent if configured | optional |

**Resolution (2026-06-14)**: Item 1 was implemented (we sent `slot_id: "m.call#ROOM"`) but caused a regression: matrix-js-sdk's `CallMembership.parseFromEvent` computes `rtcBackendIdentity` differently depending on membership kind. For `MembershipKind.Session` (the legacy `org.matrix.msc3401.call.member` event we publish) it returns the plain concatenation `${sender}:${device_id}`, **not** the v2 hash. So peers running Element Call / Element X / Element Web read our membership event, expect us on LiveKit as `@user:server:device`, but lk-jwt-service had placed us under the v2 hash → peers couldn't reconcile our LiveKit participant with our Matrix call membership → no video routing.

**Current state**: `fetchLiveKitToken` tries legacy `/sfu/get` first and falls forward to v2 only if legacy fails. v2 only becomes viable once Relay also publishes MSC4143 sticky `m.rtc.member` events (a separate, larger change). `slot_id` and v2 identity remapping (Item 2) remain plumbed; they're inert on the legacy-first path but ready for the day we adopt sticky events.

### `LiveKitCredentialService.fetchLiveKitTokenLegacy`

Lines 207–230. Reference: `getLiveunitJWT` in `openIDSFU.ts`.

| Field | Relay sends | Reference sends |
| --- | --- | --- |
| `room` | ✓ | ✓ |
| `openid_token` | ✓ | ✓ |
| `device_id` | ✓ | ✓ |
| delay parts | not sent | optional |

Matches. ✓

### `LiveKitCredentialService.discoverSFUURL`

Lines 93–141.

| Source | Relay tries | Reference tries |
| --- | --- | --- |
| Transports endpoint | `/_matrix/client/unstable/org.matrix.msc4143/rtc/transports` | MSC4195 says stable `/v1/rtc/transports`. Most servers implement neither yet. |
| `.well-known` | `org.matrix.msc4143.rtc_foci` key | Same |
| Existing peers' `m.call.member` `foci_preferred[0]` | **not consulted** | matrix-js-sdk uses this as the third fallback |

**Impact**: On a homeserver with no `.well-known` configured, if there's already an active call with a SFU negotiated, Relay throws `sfuURLNotFound` instead of using the active SFU. **Tracked as Item 3.**

### `LiveKitCredentialService.fetchLiveKitToken` (fallback logic)

Lines 166–176.

Relay: try v2 inside `try?`, fall back to legacy on *any* error.
Reference: try v2, fall back to legacy on HTTP 404 specifically; bubble up other errors.

**Impact**: A v2 endpoint returning 5xx, 401, or our 400-due-to-missing-`slot_id` all silently route to legacy. The user sees `tokenExchangeFailed` with no detail. **Tracked as Item 4.**

### `CallEncryptionService.sendCallMemberEvent`

Lines 80–135. Reference: `SessionMembershipData` in `matrix-js-sdk/src/matrixrtc/membershipData/session.ts`.

| Field | Relay value | Reference shape |
| --- | --- | --- |
| `application` | `"m.call"` | string |
| `call_id` | `""` | string (may be empty) |
| `created_ts` | `Int64(Date.now * 1000)` | optional number |
| `device_id` | ✓ | string |
| `expires` | `14400000` (4h) | optional, default 4h |
| `focus_active.type` | `"livekit"` | `"livekit"` |
| `focus_active.focus_selection` | `"oldest_membership"` | `"oldest_membership"` \| `"multi_sfu"` |
| `foci_preferred[].type` | `"livekit"` | `"livekit"` |
| `foci_preferred[].livekit_service_url` | ✓ | string |
| `foci_preferred[].livekit_alias` | `roomID` | string |
| `m.call.intent` | `"video"` | optional |
| `membershipID` | UUID | optional |
| `scope` | `"m.room"` | optional `"m.room"` \| `"m.user"` |

Matches. ✓

State key: `_<userID>_<deviceID>_m.call`. Matches Element X's per-device convention. ✓

### `CallEncryptionService.fetchCallTargets`

Sources call participants from `RoomInfo.activeRoomCallParticipants` and
broadcasts our AES key to all of each user's devices via the to-device
`"*"` wildcard. Matches Element Call's
`matrix-js-sdk/src/matrixrtc/ToDeviceKeyTransport.ts` behaviour. The
SDK accessor is user-level only — no device IDs — so a few Olm
sessions to non-call devices get warmed up unnecessarily, but the key
itself is per-call and only consumed by a LiveKit cryptor that
expects it.

(History: previously walked raw `/rooms/{id}/state` REST to parse
per-device state keys. Switched in Item 5.)

### `CallWidgetBridge.handleIncomingToDevice` (key routing)

Lines 554–634.

Routes inbound keys to `participantId` (the LiveKit-side identity our cryptor uses) by trying:

1. `"<sender>:<claimed_device_id>"`
2. `"<sender>:<content.device_id>"`
3. `member.id` (the membership UUID)
4. `sender` alone

The comment in code asserts Element Call connects to LiveKit with identity `@user:server:device`. **This is only true on the legacy path.** On v2 the identity is `unpadded_base64(sha256(canonical_json([matrixID, claimedDeviceID, memberID])))`. The legacy assumption is hardcoded into all four entries above.

**Tracked as Item 2.** Fix requires capturing the JWT-side identity (from the JWT `sub` claim, or from `room.localParticipant.identity` after connect) and using it as the routing key when on v2.

### `CallViewModel.connect` (lines 282–303)

Local key install uses:
```swift
let localIdentity = "\(encryptionService.userID):\(encryptionService.deviceID)"
```

Comment cites `matrix-js-sdk CallMembership.ts line 101` — accurate for **legacy**. Same v2 mismatch.

There's already a runtime warning on line 293: `"LiveKit identity X != matrix identity Y — frame encryption may misroute"`. This currently *only logs* the mismatch without acting on it. Item 2 should make us key the cryptor under whichever identity LiveKit actually assigned.

### `CallViewModel.redistributeKey` (lines 590–617)

Splits the LiveKit participant identity by `:` to reconstruct `(userId, deviceId)`. Hard-fails on v2 hashes (no colons → `components.count < 3` → log + return). **Tracked as Item 2.**

### `CallViewModel.connect` — runtime instrumentation gap

After `state = .connected` (line 391), the Activity Log has **no further events** until `disconnect()`. The LiveKit `RoomDelegate` (`Delegate` inner class in this file) handles `participantDidJoin`, `participantDidLeave`, `didPublishTrack`, etc., but nothing flows to the Activity Log. Real-world failure reports for "connected but no media" show traces ending at `Connected to call` with nothing actionable after.

**Tracked as Item 0** (new — added after reviewing user `97853C31` activity log on 2026-06-13).

## Design note: MSC4143 sticky-event dual-publish (future work)

The legacy-first credential path landed on 2026-06-14 restored interop with the current ecosystem, but pins Relay to the legacy `org.matrix.msc3401.call.member` shape. matrix-js-sdk's `StickyEventMembershipManager` already publishes the MSC4143 `m.rtc.member` sticky shape in parallel with the legacy event on stacks that opt in. To unblock v2 `/get_token` (hashed identity) and remove the legacy-stack dependency, Relay will need to dual-publish too.

### Scope

1. **Membership UUID threading.** `CallEncryptionService` already generates a `membershipID` UUID for the m.call.member event. Extend it to be the canonical `member.id` and thread it into `LiveKitCredentialService.fetchLiveKitTokenV2` (currently we send `"<userID>:<deviceID>"` there). The same UUID must appear in the sticky `m.rtc.member` event so peers computing `computeRtcIdentityRaw(user_id, device_id, member.id)` get the same hash lk-jwt-service assigns.

2. **Sticky-event publish.** New code path in `CallEncryptionService` (or a peer file) that publishes the MSC4143 `m.rtc.member` shape via the SDK's future-event API (depends on Synapse MSC4140 — gate on a homeserver capability probe, skip silently if unsupported). This is *additive*: keep publishing the legacy event for peers that only read it.

3. **Reader merge.** `CallEncryptionService.fetchCallTargets` currently sources participants from `RoomInfo.activeRoomCallParticipants` (user-level). When sticky events ship, the SDK's accessor should already merge both event types — verify before assuming. If it doesn't, parse both event types and dedupe by `(user_id, device_id)`.

4. **Credential path selection.** With sticky publish in place, we can revert to `fetchLiveKitToken` trying v2 first again. Peers reading our sticky event compute hashed identity; peers reading only our legacy event compute colon identity. Both must work simultaneously — meaning lk-jwt-service must place us under *one* identity but peers reading the "wrong" event lose us. Mitigation: matrix-js-sdk peers prefer the sticky event when both are present (verify in `parseFromEvent` / its caller). So as long as we sticky-publish, hashed-identity peers find us; legacy-only peers (vicr123-style older Relay builds) won't, but that's the same tradeoff matrix-js-sdk made.

5. **Encryption key routing.** `CallWidgetBridge.handleIncomingToDevice` already registers under both identity shapes (Item 2 belt-and-braces). Keep. `CallViewModel.connect` and `redistributeKey` currently key off `room.localParticipant.identity` post-connect — that continues to work, since LiveKit tells us our actual identity directly regardless of which credential path won.

### Out of scope for this work

- Switching the to-device key transport from custom-payload Olm to the SDK's `ToDeviceKeyTransport`. Orthogonal.
- Replacing `MembershipManager` plumbing wholesale with the SDK's `StickyEventMembershipManager`. The Widget API doesn't expose that manager directly; we'd be reimplementing it on top of the same primitives. Out of scope until a clear interop bug forces the switch.

### Open questions

- **Does Synapse's MSC4140 implementation handle sticky events for E2EE rooms reliably?** matrix-js-sdk has had bugs here. Test against production homeservers before assuming.
- **Does Element X currently *publish* sticky events, or only read them?** If only reads, our dual-publish is purely forward-looking and we won't see immediate interop benefit until Element X also publishes.
- **What's the right capability probe?** No standard exists yet. Likely: try the publish, treat 400/404 with specific errcodes as "feature unavailable", cache the result per-homeserver.

### Files this will touch

- `RelayKit/Call/CallEncryptionService.swift` — membership UUID threading, sticky-event publish, optional reader merge
- `RelayKit/Call/LiveKitCredentialService.swift` — revert `fetchLiveKitToken` to v2-first, thread UUID into request body
- `RelayKit/Call/CallWidgetBridge.swift` — no changes expected (key routing already dual-registers)
- `RelayKit/Call/CallViewModel.swift` — no changes expected

## What this file is NOT

- Not user-facing — see `docs/troubleshooting-calls.md` for that.
- Not exhaustive — only documents deviations we've confirmed against real source code, real specs, or real user traces. If you find a new deviation that matches a user report, add it here with a citation.
- Not a roadmap — the task list on the `rtc-element-call-alignment` branch tracks priority and ordering.
