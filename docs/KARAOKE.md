# Karaoke

## Confirmed genuinely absent — not another "already mostly real" phase

Unlike Voice and Music, this one really is greenfield. Searched both repos for "karaoke" case-insensitively: it appears in exactly 4 places, none of them a feature — `interest_options.dart` (a profile "interests" tag, same list as "Hiking" or "Cooking"), `seedDefaults.js` (backend seed data, same tag), `party_session.dart`'s `PartyMode.karaoke` enum value (never constructed — see `VOICE.md`'s role-model section for the same dead-enum pattern), and this session's own `media_source.dart` comment. No lyrics data, no pitch/vocal-scoring code, no recording pipeline, no karaoke-specific socket events, nothing.

## Why nothing was built this phase

Spec Step 14 asks for: an authorized karaoke track, a lyrics timeline, microphone input, vocal processing, scoring (pitch/timing/rhythm/consistency), solo/duet/group singing, audience, reactions, gifts, performance recording, and clip creation. Two pieces of that are substantial, independent bodies of work that don't have a "quick, safe version":

1. **A licensed backing-track-plus-lyrics-timeline catalog.** Karaoke fundamentally needs synchronized lyrics data paired with a track that's actually licensed for karaoke use (vocals removed or attenuated, timing markers). Fling has no such catalog and no rights relationship with any music provider for this — this is a content-licensing and data problem, not a code problem, and isn't something to fabricate or stub convincingly.
2. **Real-time vocal scoring (pitch/timing/rhythm/consistency).** This is genuine audio DSP/ML work — pitch detection against a reference melody in real time, scored and displayed live. It's a meaningfully sized feature on its own, not a function to bolt onto the existing Agora voice pipeline. And this environment has no microphone-capable device to test it against at all (confirmed repeatedly across this whole engagement: no Android emulator, no physical device) — building real-time audio analysis code with zero ability to hear whether it works would be exactly the "claim completion because it compiles" the request explicitly warns against, several times over for something this sensitive to actual audio behavior.

## What would be safe to reuse if this gets built later

- **Voice transport**: the existing Agora integration (`VoiceChatController`, now with real error/status reporting as of the Voice phase) already provides real-time audio infrastructure — a karaoke session's mic input is the same kind of problem, not a new transport to build.
- **Party mode**: `PartyMode.karaoke` already exists as a value; wiring a real mode-switch (see `VOICE.md`/`PARTY.md`'s note that `PartyEngine.changeMode()` currently throws `UnimplementedError`) is a prerequisite shared with every other non-watch mode, not karaoke-specific work.
- **Gifts/reactions during a performance**: the existing gift/reaction infrastructure (already real per `FLING_AUDIT.md` §2) should attach to a karaoke session the same way it already does to a watch party — no new economy plumbing needed, just a new context to fire it from.

The two genuinely new pieces — a real track+lyrics catalog and real-time vocal scoring — are what an actual karaoke build needs to start with, and neither is something to attempt without a licensing decision (for the first) and real device/microphone testing (for the second).
