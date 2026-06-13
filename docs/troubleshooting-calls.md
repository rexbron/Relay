# Troubleshooting MatrixRTC calls

If your calls fail to connect, or connect but show no audio or video, this page walks you through capturing the data we need to diagnose the issue.

## Quick capture (3 minutes)

1. Open **Window → Activity Log** (or press `⌥⌘A`).
2. In the search bar, click the **filter chip** and limit to the **Call** category.
3. Leave the Activity Log window open and reproduce the failing call.
4. Once the call has failed (or you have media issues), press `⌘S` in the Activity Log window to export the filtered events.
5. Save the file (default name `relay-activity-log.json`) and attach it to your bug report.

That export is everything the developers need to triage a calling problem.

## What's in the export

The file is pretty-printed JSON: an array of events, each with `timestamp` (ISO 8601), `category` (will be `"call"` after filtering), `severity` (`debug` / `info` / `warning` / `error`), `source` (which subsystem logged it), `summary`, optional `detail`, optional `roomId`, and a `metadata` key-value map.

Sample event:

```json
{
  "timestamp": "2026-06-12T14:30:05.123Z",
  "category": "call",
  "severity": "info",
  "source": "LiveKitCredentialService",
  "summary": "SFU URL discovered",
  "roomId": "!abc:example.org",
  "metadata": {}
}
```

## What's safe to share

The export contains:

- Your Matrix room ID (`!…:server`) and device IDs
- Per-call membership UUIDs and key indices
- Your homeserver hostname
- SHA-256 fingerprints (first 8 hex chars) of encryption keys, **never the keys themselves**

It does **not** contain:

- Raw E2EE keys
- OpenID tokens or LiveKit JWTs
- Message contents, names, or avatars
- The OpenID access token used for SFU auth

If you don't want your room IDs or device IDs in a public bug report, ask the maintainers for a DM in [#relayapp:matrix.org](https://matrix.to/#/#relayapp:matrix.org) and share the file there.

## Reading the export yourself

A few specific log lines act as signposts. If your file contains any of these, you can pre-diagnose your own issue:

### Connection-time signals

| Look for | What it means |
| --- | --- |
| `Fetching call credentials` | The call attempt started; subsequent events should show whether discovery and token exchange succeeded. |
| `SFU URL discovered` | Your homeserver advertises a LiveKit SFU. Good. |
| `Failed to fetch call credentials` with `detail: "This homeserver has no LiveKit call server configured…"` | Your homeserver doesn't expose `org.matrix.msc4143.rtc_foci` in `.well-known/matrix/client`, and the unstable transports endpoint isn't supported. Ask your homeserver admin to configure MatrixRTC. |
| `Call credentials obtained` | Token exchange succeeded. If the call still fails after this, the problem is downstream of credential acquisition. |

### Connected-but-no-media signals

If the call reaches the **Connected to call** event but you can't see or hear anyone, the failure is in the encryption-key exchange or frame routing.

| Look for | What it means |
| --- | --- |
| `Distributed E2EE key to N user(s)` followed by `Received E2EE key from …` for each peer | Key exchange is happening. If you still have no media, the problem is in the frame-decoder routing — note the `Participant:` field in the `detail`, this is the identity LiveKit assigned to the peer. |
| No `Received E2EE key from …` events at all | Peers aren't sending you their keys, or the widget bridge isn't running. Check whether the room is configured as encrypted (E2EE is enabled only for encrypted Matrix rooms). |
| `Widget bridge started` but no later events | The widget driver is waiting for capability negotiation that never completes. Likely an SDK or homeserver-side issue. |

### Patterns worth flagging in a bug report

These specific event sequences point to a known class of failure:

1. **No `Call credentials obtained` event after `Fetching call credentials`.** Credential exchange is failing. Almost always a homeserver-side or SFU-side configuration problem; we'll need to know which homeserver you're on.

2. **`Connected to call` but no `Distributed E2EE key` event.** The Matrix call-member state event went out, but no peers existed at the time you connected, or our cache of call members is stale. If others were already in the call, this is a Relay bug worth reporting.

3. **`Received E2EE key from …` events present, but you still see no media from those peers.** Frame-cryptor routing is misaligned with the LiveKit participant identity. This is currently a known issue we're working on; please attach the export and note the LiveKit `Participant:` identity you see in those events' `detail` field.

## When the Activity Log isn't enough

For really hard cases (the SFU is rejecting our JWT with no useful error, or the LiveKit room itself never finishes initialising) we sometimes need a unified-log capture, which records the low-level RTC trace from inside the LiveKit SDK.

While the call is reproducing the issue, run in a terminal:

```sh
log stream --predicate 'subsystem == "RelayKit" AND category BEGINSWITH "Call"' \
           --level info > relay-call-trace.log
```

Stop with `^C` once the call has failed, then share `relay-call-trace.log` alongside the Activity Log JSON.

The unified-log capture contains more verbose internal trace including LiveKit SDK output. It's safe in the same way the Activity Log is (no key material, no tokens), but it does contain more verbose timing and routing data. Share it through the same channel you'd share the JSON.

## Reporting

File an issue at [github.com/subpop/Relay/issues](https://github.com/subpop/Relay/issues) or message [#relayapp:matrix.org](https://matrix.to/#/#relayapp:matrix.org). Please include:

- The `relay-activity-log.json` export (filtered to the Call category)
- Your homeserver hostname (e.g. `matrix.example.org`)
- Whether other clients (Element X, Element Web) succeed at calling on the same account
- A one-line description of what you saw: "fails to connect", "connects but no audio", "connects but no video", etc.

If you'd rather not put logs in a public issue, send them privately to maintainers in the Matrix room first.
