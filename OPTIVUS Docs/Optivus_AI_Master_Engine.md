# Optivus — AI Rule Engine, Decision Engine & Coach Logic System

**Document type:** Master technical design — production-ready, ready to implement
**Author:** Senior systems architect + behavioral product design pass
**Audience:** Nairit (you), Antigravity (the coding agent doing the build), Claude (design + review)
**Companion to:** Optivus_PRD.md, Optivus_EventSystem.md, Optivus_ServiceContracts.md, code audit
**Date:** 26 April 2026
**Status:** Approved master design — single source of truth for the AI brain of Optivus

---

## Notes for Antigravity (the AI agent reading this to build it)

Read this whole file before writing any code. The spec has heavy internal cross-references — Rules in §3 depend on archetypes in §2.1 which depend on user states in §1.7 which depend on the context snapshot in §1.6. Skipping ahead breaks the design.

When you generate code from this spec, follow these absolute constraints:

1. **Build the Rule/Decision Engine first, then the Coach voice, then the LLM layer.** Do not build them together. The Engine is pure logic and unit-testable; build it with full test coverage before plugging in any LLM. Debugging "is the message bad because the gate fired wrong or because Claude wrote nonsense?" is a nightmare we don't need.
2. **Templates are code, not config.** Hardcode them in `coach_templates.dart`. Never put them in Firestore — a bad template shouldn't be shippable without a code review.
3. **Claude is called once at the end of the speak path, never to make routing decisions.** Section 7 is the only place that calls the LLM.
4. **The lists in §6.1 and §6.2 (stress and crisis markers) live in code only.** Never in Firestore. They cannot be remotely edited.
5. **Every speak writes to `coach_speak_log`** (§8). Don't skip this — it's how we'll debug the engine after launch.
6. **When in doubt, drop the message.** False negatives (missed coaching opportunity) are cheap. False positives (annoying spam) lose users.
7. **If anything in this spec is ambiguous, stop and ask Nairit before guessing.** The §11 open questions are intentionally not decided — flag any decision point you hit.

---

## Notes for Nairit

This spec is the *brain* behind the Coach tab. Today CoachTab opens with hardcoded "I noticed u smoked 2 cigarettes" demo bubbles and uses `GeminiService.startChat` directly for replies. After this is built:

- The hardcoded bubbles get deleted.
- The CoachTab becomes a thin renderer for the `coach_messages` Firestore collection.
- A new `CoachService` decides when to speak and what to say.
- User-typed replies still go through the LLM, but they also pass through the engine for crisis + stress detection.

The order of building matters. Per the audit, you need `EventService`, `HabitService`, `TaskService`, `StreakService` to exist *before* this. They generate the events the engine reacts to. Don't try to build the Coach before its inputs exist.

**Note on LLM choice:** the original product brief uses Gemini (`google_generative_ai` package), but this spec is written so you can swap in Claude via the Anthropic API in 1 file (§7). The decision is independent of everything else here. The prompt format in §7 is written for Claude, since Claude follows persona constraints more reliably than Gemini in our testing — but the same prompt works for Gemini with minor adjustments to the system message format.

---

# Table of Contents

1. **AI Rule Engine Architecture** — the full event → response pipeline
2. **Rule Schema** — the JSON contract for every rule in the system
3. **Core Rule Set** — the three raw cases (gym, Instagram, smoking) transformed into production-quality rules, plus the full case-by-case rule book
4. **Advanced Multi-Event Rules** — pattern detection across events (the "bad day" detector)
5. **Priority & Cooldown Logic** — gating and conflict resolution
6. **Stress & Crisis Detection** — the always-on safety layer
7. **Context Builder** — what we know about the user before deciding
8. **Prompt Engineering Layer** — the exact system prompt sent to Claude
9. **Output Format** — what the engine returns
10. **Design Principles** — the unbreakable behavioral rules
11. **Implementation Plan** — phased build order for Antigravity
12. **Open Design Questions** — explicitly undecided items

---

# Part 1 — AI Rule Engine Architecture

## 1.1 The pipeline

Every coach message in Optivus flows through this exact sequence. No shortcuts.

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  Event   │ ──→ │  Rule    │ ──→ │Condition │ ──→ │ Priority │
│ Arrives  │     │ Matching │     │ Eval     │     │ Selection│
└──────────┘     └──────────┘     └──────────┘     └──────────┘
                                                          │
                                                          ▼
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  Action  │ ←── │  Claude  │ ←── │  Prompt  │ ←── │ Context  │
│  Output  │     │ Response │     │Generator │     │ Builder  │
└──────────┘     └──────────┘     └──────────┘     └──────────┘
```

## 1.2 Each stage explained

### Stage 1 — Event Arrives
Source: `EventService` Firestore stream OR local Dart timer (Watched Conditions, see §1.4) OR Cloud Scheduler (scheduled checks).

Event structure (all events conform):
```json
{
  "event_id": "evt_01HX...",
  "user_id": "uid_abc",
  "type": "habit.bad_logged",
  "timestamp": "2026-04-26T14:23:00+05:30",
  "metadata": { "habit": "cigarettes", "count": 1 },
  "schema_version": 1
}
```

### Stage 2 — Rule Matching
For each event, the engine queries all rules where `rule.event == event.type` OR `rule.event == "*"` (wildcard). This produces a candidate set — typically 1–5 rules.

**Implementation:** static `Map<String, List<Rule>>` keyed by event type, loaded once at app start. O(1) lookup.

### Stage 3 — Condition Evaluation
For each candidate rule, evaluate `rule.conditions` against the user's `ContextSnapshot`. Conditions are pure boolean predicates over the snapshot — see §2.

A rule is *eligible* if all its conditions return true. Ineligible rules are dropped silently.

### Stage 4 — Priority Selection
Among eligible rules, pick the one with the highest `rule.priority`. Ties broken by `rule.id` lexicographic order (deterministic).

If no rule is eligible: emit no message. Log `coach.no_eligible_rule` for debugging.

### Stage 5 — Context Builder
Build the user-specific data that will be injected into the prompt. See §6 for the full schema. This is *richer* than the snapshot used for gating — includes recent message history, identity tags, time-of-day phrasing.

### Stage 6 — Prompt Generator
Combine the rule's `prompt_template` with the context, plus the hardcoded system prompt from §7. Produces a single string ready for the LLM.

### Stage 7 — Claude Response
Call the Anthropic API. Single round-trip. No streaming for coach messages (they're short — under 200 tokens). If the call fails, fall back to a deterministic message generated from the template body alone — see §7.4.

### Stage 8 — Action Output
The structured response (§9) is written to:
- `coach_messages/{uid}/messages/{messageId}` — what the user sees
- `coach_speak_log/{uid}/log/{logId}` — what the engine did and why

The user's CoachTab is subscribed to `coach_messages` and renders the new bubble.

## 1.3 Three event sources

The engine doesn't care where events come from, but the build does:

| Source | Latency | Examples |
|---|---|---|
| **Reactive** — Firestore event stream | <30s | habit logs, task completions, chat messages |
| **Watched** — local Dart timer (60s tick) | up to 60s | "Mission ring 0% with 90 min left in day" |
| **Scheduled** — Cloud Function on Pub/Sub schedule | exact | morning brief, midday pulse, day close, inactivity |

Reactive is the dominant path — most messages.

## 1.4 What the engine does NOT do

To keep the brain narrow:

- It does not call the LLM to decide whether to speak. The LLM only generates wording.
- It does not write user data. It only reads. (Writes go through services.)
- It does not own the chat UI. Coach messages are delivered by appending to a Firestore collection; the existing CoachTab listens and renders.
- It does not persist its state to Firestore. Engine state (cooldowns, budgets) lives in Hive, on-device. This makes it fast and survivable to network outages.

---

# Part 2 — Rule Schema

## 2.1 The Rule object

Every rule in the system conforms to this schema. Stored as a Dart constant in `coach_rules.dart`.

```typescript
interface Rule {
  // Identity
  id: string;                    // 'slip_cigarette_strict_on_track'
  description: string;           // human-readable for debugging

  // Trigger
  event: string;                 // 'habit.bad_logged' or '*' for wildcard
  conditions: Condition[];       // ALL must be true (AND semantics)

  // Routing
  priority: 1 | 2 | 3 | 4;       // 1 = critical, 4 = passive (see §5)
  cooldown_seconds: number;      // min seconds between same rule firing
  cooldown_topic: string;        // shared cooldown bucket key

  // Coach behavior
  ai_intent: string;             // 'check_in_after_slip' (one of a fixed enum)
  tone: ToneSpec;                // see below
  archetype_override?: string;   // force a specific archetype regardless of accountability

  // Generation
  prompt_template: string;       // intent description for Claude (NOT the user-facing text)
  example_outputs: string[];     // 2-4 example messages that match the intent (few-shot for Claude)
  fallback_message: string;      // exact text if Claude call fails

  // Post-message
  suggested_actions: ActionButton[];
  followup_policy: 'none' | 'check_in_2h' | 'check_in_24h' | 'check_in_after_routine';
}

interface Condition {
  field: string;                 // dot-path into ContextSnapshot, e.g. 'user_state'
  op: 'eq' | 'neq' | 'gt' | 'gte' | 'lt' | 'lte' | 'in' | 'nin' | 'contains';
  value: any;
}

interface ToneSpec {
  archetype_aware: boolean;      // if true, archetype determines tone
  override?: 'gentle' | 'direct' | 'celebratory' | 'neutral';
}

interface ActionButton {
  label: string;                 // 'Talk to me'
  action: string;                // 'open_chat'
  params: Record<string, any>;
}
```

## 2.2 Why this schema

Three deliberate choices worth flagging:

1. **`prompt_template` is not the user-facing text.** It's a description of what Claude should produce. Claude generates the actual words. This means a single rule produces varied but on-brand messages every time — no robotic repetition.

2. **`example_outputs` is the few-shot anchor.** Claude is excellent at matching the *style* of examples. Three or four examples per rule is enough to lock tone without prescribing words.

3. **`fallback_message` is mandatory.** If Claude is down, the user still gets a coherent message. A degraded experience beats silence.

## 2.3 Example complete rule

```dart
const rule_slip_cigarette_strict_on_track = Rule(
  id: 'slip_cigarette_strict_on_track',
  description: 'First cigarette today, after a clean streak, user on track',
  event: 'habit.bad_logged',
  conditions: [
    {field: 'metadata.habit', op: 'eq', value: 'cigarettes'},
    {field: 'metadata.count_today', op: 'eq', value: 1},
    {field: 'streaks.cigarettes_clean', op: 'gte', value: 1},
    {field: 'user_state', op: 'eq', value: 'on_track'},
    {field: 'accountability', op: 'eq', value: 'strict'},
  ],
  priority: 2,
  cooldown_seconds: 5400,         // 90 min
  cooldown_topic: 'cigarettes',
  ai_intent: 'acknowledge_slip_no_shame',
  tone: ToneSpec(archetype_aware: true),
  prompt_template: '''
    The user just had their first cigarette after a clean streak.
    Acknowledge it specifically, without moralizing.
    Ask what triggered it. Offer a strategy for next time.
    Keep it under 3 sentences.
  ''',
  example_outputs: [
    "First one in 3 days — not nothing. What set it off today?",
    "There's the streak. Want to figure out what triggered it before the next one?",
    "Three days clean, then this. Talk me through what was happening.",
  ],
  fallback_message: "Noticed the slip. Want to talk through what triggered it?",
  suggested_actions: [
    ActionButton(label: 'Log trigger', action: 'log_trigger', params: {}),
    ActionButton(label: 'Set guard rail', action: 'set_guardrail', params: {}),
    ActionButton(label: 'Talk to me', action: 'open_chat', params: {}),
  ],
  followup_policy: 'check_in_2h',
);
```

---

# Part 3 — Core Rule Set

## 3.1 The three raw cases — transformed

Each transformation has three layers:
- **Raw idea** (what was originally written)
- **Why it doesn't work** (what would happen if shipped as-is)
- **Production rule** (the version that ships)

### Case 1 — Missed Gym

**Raw idea:** "what happened to you, are you felt weak or what?"

**Why it doesn't work:**
- "what happened to you" sounds like an interrogation
- "are you felt weak" assumes weakness — the user might have been busy, sick, or had a deliberate rest day
- Grammar errors break trust ("are you felt" → "did you feel")
- No actionable next step
- Doesn't account for whether this is a one-off or a pattern

**Production rule:**

```dart
const rule_missed_gym_one_off = Rule(
  id: 'missed_gym_one_off',
  description: 'User missed a single gym session, no recent pattern',
  event: 'routine.window_missed',
  conditions: [
    {field: 'metadata.routine', op: 'eq', value: 'gym'},
    {field: 'metadata.completion', op: 'eq', value: 0},
    {field: 'streaks.gym_miss_3day', op: 'lt', value: 2},  // not a pattern yet
  ],
  priority: 3,                     // awareness, not critical
  cooldown_seconds: 14400,         // 4h
  cooldown_topic: 'gym',
  ai_intent: 'open_inquiry_no_assumption',
  tone: ToneSpec(archetype_aware: true),
  prompt_template: '''
    The user missed today's gym session. This is a one-off, not a pattern.
    Open a conversation without assuming why they missed it.
    Do NOT assume they felt weak, lazy, or unmotivated — they might have been busy or chose rest.
    Ask one open question. Offer to reschedule or skip the day.
    Maximum 2 sentences.
  ''',
  example_outputs: [
    "Gym got skipped today — anything pulling at you, or just one of those days?",
    "Missed today's session. Want to push it later, or call it a rest day?",
    "No gym today. What got in the way, if anything?",
  ],
  fallback_message: "Missed today's gym. Want to reschedule or take it as rest?",
  suggested_actions: [
    ActionButton(label: 'Reschedule today', action: 'reschedule_routine', params: {'routine': 'gym'}),
    ActionButton(label: 'Mark as rest day', action: 'mark_rest', params: {}),
    ActionButton(label: 'Talk to me', action: 'open_chat', params: {}),
  ],
  followup_policy: 'none',
);
```

**What changed and why:**
- "Anything pulling at you" replaces "are you felt weak" — open-ended, no assumption
- Offers rest day as a legitimate option — respects user autonomy
- Two action buttons turn coaching into action, not chat
- Cooldown 4h prevents re-nagging if user opens app multiple times

### Case 2 — Instagram Overuse (4 hours)

**Raw idea:** "do you know that you used instagram 4 hours. Stop using for now and talk to me"

**Why it doesn't work:**
- "Stop using for now" is a command — violates user autonomy (Design Principle in §10)
- "Talk to me" is a demand, not an invitation
- Doesn't acknowledge the user might already know — assumes ignorance
- No reflective dimension — just a stop sign

**Production rule:**

```dart
const rule_instagram_overuse_first_breach = Rule(
  id: 'instagram_overuse_first_breach',
  description: 'User crossed daily Instagram limit, first time today',
  event: 'screen_time.exceeded',
  conditions: [
    {field: 'metadata.app', op: 'eq', value: 'instagram'},
    {field: 'metadata.minutes_today', op: 'gte', value: 240},  // 4h
    {field: 'topics_spoken_last_24h', op: 'nin', value: ['instagram_overuse']},
  ],
  priority: 2,                     // behavior, not critical
  cooldown_seconds: 21600,         // 6h
  cooldown_topic: 'instagram_overuse',
  ai_intent: 'reflective_awareness_no_command',
  tone: ToneSpec(archetype_aware: true),
  prompt_template: '''
    The user has spent 4 hours on Instagram today, exceeding their own limit.
    Bring this to their attention WITHOUT commanding them to stop.
    Frame it as a reflection — they set the limit, not you.
    Ask if it was intentional or background.
    Offer ONE optional action.
    Maximum 2 sentences. No exclamation marks.
  ''',
  example_outputs: [
    "4 hours on Instagram today. Was that intentional, or did it sneak up on you?",
    "Instagram passed your limit a while ago. Worth pausing for a sec, or is today different?",
    "Hit 4 hours on Instagram. Does that match what today felt like?",
  ],
  fallback_message: "Instagram is at 4 hours today. Worth a pause, or is today an exception?",
  suggested_actions: [
    ActionButton(label: 'Lock app for 1h', action: 'lock_app', params: {'app': 'instagram', 'duration': 3600}),
    ActionButton(label: 'Adjust my limit', action: 'edit_screentime_limit', params: {'app': 'instagram'}),
    ActionButton(label: 'Talk to me', action: 'open_chat', params: {}),
  ],
  followup_policy: 'none',
);
```

**What changed and why:**
- "Was that intentional, or did it sneak up on you" — gives the user dignity to decide
- "Worth pausing for a sec" — suggestion, not order
- Lock-app button is offered, not enforced — user must tap to engage
- Acknowledges "today might be different" — respects context the AI can't see

### Case 3 — Smoking 4 Cigarettes

**Raw idea:** "Are you sad? You can tell me what are you feeling."

**Why it doesn't work:**
- "Are you sad?" assumes the emotion — Design Principle: never assume feelings
- They might be stressed, bored, social-smoking, or in habit-mode — sad is one of dozens of possibilities
- Coming straight to "tell me what you're feeling" is therapy-speak that can feel intrusive when triggered by a behavior log
- Doesn't acknowledge the count itself

**Production rule:**

```dart
const rule_smoking_pattern_4_cigs = Rule(
  id: 'smoking_pattern_4_cigs',
  description: 'User logged 4th cigarette today — pattern emerging',
  event: 'habit.bad_logged',
  conditions: [
    {field: 'metadata.habit', op: 'eq', value: 'cigarettes'},
    {field: 'metadata.count_today', op: 'gte', value: 4},
    {field: 'eating_disorder_flag', op: 'eq', value: false},  // safety guard
  ],
  priority: 1,                     // critical — pattern, health risk
  cooldown_seconds: 7200,          // 2h
  cooldown_topic: 'cigarettes',
  ai_intent: 'pattern_check_in_no_assumption',
  tone: ToneSpec(override: 'gentle'),  // override archetype — never harsh on this
  archetype_override: 'forgiving',
  prompt_template: '''
    The user has smoked 4 cigarettes today.
    This is a pattern, not a single slip.
    Open a check-in WITHOUT assuming what they are feeling.
    Do NOT say "are you sad" — they could be stressed, bored, social, or in autopilot.
    Acknowledge the count. Ask what is going on, broadly.
    Offer a low-friction way to talk.
    Maximum 3 sentences.
  ''',
  example_outputs: [
    "Four today. Something on your mind, or is it just one of those days?",
    "That's the fourth. What's happening — stress, boredom, just the usual?",
    "Four cigarettes today. Want to break it down with me, or just leave it logged?",
  ],
  fallback_message: "Four today. What's going on — want to talk it through?",
  suggested_actions: [
    ActionButton(label: "Just stress", action: 'log_trigger', params: {'trigger': 'stress'}),
    ActionButton(label: "Just habit", action: 'log_trigger', params: {'trigger': 'habit'}),
    ActionButton(label: "Talk to me", action: 'open_chat', params: {}),
    ActionButton(label: "Leave it", action: 'dismiss', params: {}),
  ],
  followup_policy: 'check_in_2h',
);
```

**What changed and why:**
- "Something on your mind" — open question that fits any emotional state
- Listed possible triggers as buttons — gives the user vocabulary without putting words in their mouth
- "Leave it" is a button — explicitly respects the right to not engage
- Forced gentle archetype regardless of accountability setting — the user with "Ruthless" mode should not be shamed for smoking; that's counterproductive
- 2h cooldown means we don't pile on after a bad afternoon

## 3.2 The full case-by-case rule book

Below is the complete production rule book covering every behavioral case the coach handles. Each rule references conditions from §6 (Context Builder).

### Case A — Missed Routines (extends Case 1)

```
RULE A1 — single miss, on track
WHEN routine.window_missed AND completion == 0 AND user_state == 'on_track'
PRIORITY 3 (awareness)
ACTION: open inquiry, offer reschedule (see Case 1 above for gym variant)

RULE A2 — single miss, slipping
WHEN routine.window_missed AND completion == 0 AND user_state == 'slipping'
PRIORITY 2 (behavior)
ACTION: note the pattern gently, ask if routine timing is wrong
SUGGEST: [Adjust time], [Skip this week], [Talk to me]

RULE A3 — single miss, relapsing or recovering
WHEN routine.window_missed AND completion == 0 AND user_state IN ['relapsing','recovering']
PRIORITY 3 (awareness)
ARCHETYPE: forgiving (forced)
ACTION: no judgment; offer pause; ask what's been hardest
SUGGEST: [Pause routine 7 days], [Talk to me]

RULE A4 — partial completion
WHEN routine.window_missed AND completion >= 0.5
DO NOT SPEAK. Partial wins are wins.

RULE A5 — third consecutive miss
WHEN routine.window_missed AND streaks.routine_miss_3day >= 3
PRIORITY 2 (escalates from 3)
ACTION: routine isn't fitting their life — offer to redesign or pause
SUGGEST: [Edit routine], [Pause], [Talk to me]
```

### Case B — Good Progress

```
RULE B1 — small streak (7, 14, 30 days)
WHEN streak.milestone WHERE value IN [7, 14, 30] AND user_state == 'on_track'
PRIORITY 3 (awareness, but positive)
ARCHETYPE: celebratory (overrides accountability)
ACTION: name the habit, name the count, name the next milestone

RULE B2 — big streak (60, 90, 100, 365 days)
WHEN streak.milestone WHERE value IN [60, 90, 100, 365]
PRIORITY 2 (behavior — identity-anchoring matters)
ARCHETYPE: celebratory + identity reinforcement
ACTION: anchor to identityTag — "A {tag} person doesn't do {behavior}, and you've proven that for {N} days"

RULE B3 — clean day at bedtime
WHEN routine.completion_today >= 0.95 AND time.hour >= 21 AND day_not_yet_closed
PRIORITY 4 (passive)
ACTION: one sentence. "Today was clean. Sleep well."
SUGGEST: []

RULE B4 — celebration crowding
WHEN streak.milestone fires AND topic 'celebration' spoken in last 4h
DEFER to morning brief next day. No stacked praise.
```

### Case C — Bad Habits (extends Cases 2 and 3)

```
RULE C1 — first slip after clean streak (cigarettes/junk/scrolling)
WHEN habit.bad_logged AND clean_streak >= 1 day AND count_today == 1
PRIORITY 2 (behavior)
ACTION: acknowledge specifically, ask trigger, offer next-time strategy

RULE C2 — escalating same-day count (3+ in 4h)
WHEN habit.bad_logged AND count_today >= 3 AND time_since_last < 7200
PRIORITY 1 (critical — safety net)
BYPASSES daily speak budget
ARCHETYPE: forgiving regardless of accountability
ACTION: pattern alert; ask trigger; offer 30-min lockout

RULE C3 — heavy scrolling
WHEN screen_time.exceeded AND minutes_session > 90 AND app IN user_blocked_apps
PRIORITY 2 (behavior)
ACTION: name app + time, ask if intentional, offer break (see Case 2 production rule)

RULE C4 — junk food after eating routine miss
WHEN habit.bad_logged WHERE habit='junk_food' AND last_eating_routine_completed == false
PRIORITY 2 (behavior)
ARCHETYPE: forgiving (forced — food shame backfires)
ACTION: connect dots gently; offer to schedule next real meal

RULE C5 — eating disorder safety lock
WHEN habit.bad_logged AND habit IN food-related AND user.eating_disorder_flag == true
DO NOT SPEAK. Skip the entire C-series for food. ALWAYS.
This rule overrides everything else in Case C.
```

### Case D — Stress / Overthinking

```
RULE D1 — stress markers in chat message
WHEN chat.user_message AND text contains §6.1 STRESS_MARKERS
PRIORITY 1 (critical — emotional)
ARCHETYPE: forgiving (forced)
ACTION: validate first, reflect back, ask "vent or plan?"
SUGGEST: [Just vent], [Help me plan], [5-min breathing]

RULE D2 — behavioral stress signal
WHEN scroll_minutes_in_window > 60 IN last_90_min AND no productive event in same window
PRIORITY 3 (awareness)
ARCHETYPE: forgiving
ACTION: one sentence. "Brain feels foggy — 5 min outside?"

RULE D3 — overthinking marker (long unsent message)
WHEN chat.composing_long > 90s AND chars > 300
PRIORITY 4 (passive)
ACTION: ghost text in composer (special UI hook): "Just send it. There's no wrong message here."
This is not a bubble — it's an inline hint.
```

### Case E — Crisis (priority 100, special)

```
RULE E1 — high-confidence crisis marker
WHEN chat.user_message AND text matches §6.2 CRISIS_MARKERS_HIGH
PRIORITY 1 (critical — overrides ALL gating)
ARCHETYPE: crisis (special, see §10)
ACTION: fixed non-LLM message:
  "I'm hearing something heavy. I'm an app — I can sit with you, but I want you to talk to someone real too. iCall (India): 9152987821. iCall is free and confidential. Want me to keep this thread quiet so you have a safe space here?"
SUGGEST: [Open iCall info], [Stay here, just listen]

RULE E2 — crisis aftermath lock
WHEN priority-1 crisis fired in last 24h
DO disable all proactive coaching for 24h.
The Coach goes into "listening mode" — only responds to user-initiated chat, never pushes.
Re-enable after 24h OR after user types "I'm ok" / "I want my coach back".
```

### Case F — Inactivity

```
RULE F1 — 24h inactive
WHEN user.inactive_24h fires (server-generated)
PRIORITY 4 (passive)
ACTION: low-key check-in, no guilt, sent as push notification + queued chat bubble

RULE F2 — 48h inactive (escalation)
WHEN user.inactive_48h fires AND F1 already fired
ACTION: chat bubble only, no push (push limit: 1 per 72h max)
```

---

# Part 4 — Advanced Multi-Event Rules

The engine becomes useful when it can see *patterns* across events, not just individual triggers. These rules look back at the last 24h of context, not just the firing event.

## 4.1 The "Bad Day" detector

A bad day isn't one missed gym session — it's a *combination*. The detector watches for 3 or more of these in the last 24h:

- Routine completion < 40% so far today
- Bad habit logged 2+ times today
- Screen time > 200% of daily limit on any blocked app
- Mission ring < 25% by midday
- Stress markers in any chat message today
- 3+ task abandonments today
- Sleep last night < 5 hours

```dart
const rule_bad_day_pattern = Rule(
  id: 'bad_day_pattern',
  description: 'Multiple negative signals stacking — pattern intervention',
  event: '*',                    // wildcard, evaluated on every event
  conditions: [
    {field: 'derived.bad_day_signal_count', op: 'gte', value: 3},
    {field: 'topics_spoken_last_24h', op: 'nin', value: ['bad_day']},
  ],
  priority: 1,                   // critical
  cooldown_seconds: 21600,       // 6h
  cooldown_topic: 'bad_day',
  ai_intent: 'compassionate_pattern_acknowledgement',
  tone: ToneSpec(override: 'gentle'),
  archetype_override: 'forgiving',
  prompt_template: '''
    The user is having a bad day. Multiple things are off — list them in your head:
    {{bad_day_signals}}.
    Do NOT enumerate the failures. Do NOT shame.
    Acknowledge that today is hard, ask if they want to reset or just rest.
    Maximum 2 sentences. No exclamation marks.
  ''',
  example_outputs: [
    "Today's been a lot. Want to reset something small, or just call it and start fresh tomorrow?",
    "Heavy day. Pick one thing to win at right now, or close the day early?",
    "Not your day. Want one small win, or rest?",
  ],
  fallback_message: "Today's been heavy. Want one small win, or just rest?",
  suggested_actions: [
    ActionButton(label: "One small win", action: 'pick_quick_task', params: {}),
    ActionButton(label: "Close the day", action: 'early_day_close', params: {}),
    ActionButton(label: "Talk to me", action: 'open_chat', params: {}),
  ],
  followup_policy: 'check_in_24h',
);
```

**Why this matters:** without this rule, the engine fires a separate message for each negative signal — gym miss, then smoking message, then screen time message. The user feels nagged. With this rule, the engine *steps back*, says "this is a bad day pattern," and replaces the chorus of small messages with one compassionate one. Cooldown of 6h prevents re-firing the same day.

## 4.2 The "Recovery Streak" detector

The opposite — when the user is climbing out of a bad week:

```dart
const rule_recovery_acknowledgment = Rule(
  id: 'recovery_acknowledgment',
  description: 'User on bad streak last week, last 2 days improving',
  event: 'day.closed',
  conditions: [
    {field: 'user_state', op: 'eq', value: 'recovering'},
    {field: 'derived.consecutive_recovery_days', op: 'gte', value: 2},
    {field: 'topics_spoken_last_24h', op: 'nin', value: ['recovery_ack']},
  ],
  priority: 2,                   // behavior — identity-shaping
  cooldown_seconds: 86400,       // 24h
  cooldown_topic: 'recovery_ack',
  ai_intent: 'quiet_acknowledgment_of_climb',
  tone: ToneSpec(override: 'gentle'),
  archetype_override: 'forgiving',
  prompt_template: '''
    The user had a hard week and the last 2 days are showing improvement.
    Quietly acknowledge the climb. Don't be loud about it — recovery is fragile.
    Don't list what they did. Just say you noticed. Maximum 2 sentences.
  ''',
  example_outputs: [
    "Two days in a row holding it together. That's not nothing.",
    "Quieter week than last week. Whatever you're doing, keep doing it.",
    "Things look steadier the last couple days.",
  ],
  fallback_message: "Things look steadier the last couple days.",
  suggested_actions: [
    ActionButton(label: "Thanks", action: 'dismiss', params: {}),
  ],
  followup_policy: 'none',
);
```

## 4.3 The "Stuck Routine" detector

Same routine, missed 4+ times in 7 days:

```dart
const rule_stuck_routine = Rule(
  id: 'stuck_routine',
  description: 'Same routine missed 4+ days in last 7 — design issue',
  event: 'routine.window_missed',
  conditions: [
    {field: 'derived.routine_miss_count_7d', op: 'gte', value: 4},
    {field: 'topics_spoken_last_24h', op: 'nin', value: ['stuck_routine']},
  ],
  priority: 2,
  cooldown_seconds: 86400,
  cooldown_topic: 'stuck_routine',
  ai_intent: 'redesign_offer_no_blame',
  prompt_template: '''
    The user has missed the same routine 4+ times in 7 days.
    This is a design problem, not a discipline problem.
    Suggest the routine itself isn't fitting their life.
    Offer to: change time, simplify steps, or pause for a week.
    No blame. Maximum 3 sentences.
  ''',
  example_outputs: [
    "{routine} keeps slipping — 4 misses this week. Probably the routine, not you. Want to change the time, simplify it, or pause it?",
    "Four misses on {routine} this week. Wrong time of day, too long, or just the wrong week to push?",
  ],
  fallback_message: "{routine} keeps slipping — want to redesign it or pause?",
  suggested_actions: [
    ActionButton(label: "Change time", action: 'edit_routine_time', params: {}),
    ActionButton(label: "Simplify steps", action: 'edit_routine_steps', params: {}),
    ActionButton(label: "Pause 7 days", action: 'pause_routine', params: {'days': 7}),
  ],
  followup_policy: 'check_in_after_routine',
);
```

## 4.4 Detector implementation note

Multi-event rules use `derived.*` fields in their conditions — these are *computed* during context building (§6), not stored in events. Examples:

- `derived.bad_day_signal_count` — count of negative signals in last 24h
- `derived.routine_miss_count_7d` — count of misses for this specific routine in 7d
- `derived.consecutive_recovery_days` — number of recent days meeting recovery threshold

Antigravity: implement these as pure functions in `context_builder.dart`. They take the raw event log and return ints. Unit-test each one with synthetic event sequences before wiring into rules.

---

# Part 5 — Priority & Cooldown Logic

## 5.1 Priority scale

The brief specifies 4 levels:

| Priority | Class | Examples | Behavior |
|---:|---|---|---|
| **1** | Emotional / Critical | Crisis markers, bad-day pattern, 3+ smoking in 4h | Bypasses budget, can break silence windows (crisis only) |
| **2** | Behavior | First slip after clean streak, screen time exceeded, missed gym (slipping state) | Respects budget, respects silence |
| **3** | Awareness | Single missed routine, mid-streak milestone, mild scroll alert | Easily dropped if budget tight |
| **4** | Passive | Bedtime "good day" note, inactivity check, ghost-text composer hint | First to be dropped under any pressure |

## 5.2 Conflict resolution

When multiple rules match the same event:

```
Step 1: Filter by eligibility (all conditions true)
Step 2: Among eligible, take highest priority (lowest number wins; 1 > 2 > 3 > 4)
Step 3: If tie, take rule with most specific conditions (more conditions = more specific)
Step 4: If still tie, lexicographic by rule.id (deterministic, debuggable)
Step 5: Drop the rest. Do not queue.
```

**Why drop, not queue:** if the same event triggers both "missed gym" (priority 3) and "bad day pattern" (priority 1), the user should hear ONE message about the bad day — not the gym message a few minutes later when context has shifted.

## 5.3 Cross-rule cooldown

Some rules share a `cooldown_topic`. After any rule with topic `cigarettes` fires, no rule with that topic can fire for the cooldown window — regardless of which specific rule.

Default cooldowns (override per rule as needed):

| Topic | Cooldown |
|---|---|
| `cigarettes`, `junk_food`, `scrolling`, etc. (per-habit) | 90 min |
| Specific routine (e.g. `gym`, `meditation`) | 4 hours |
| `streak_milestone` | 6 hours |
| `bad_day` | 6 hours |
| `inactivity` | 12 hours |
| `crisis` | 24 hours (E2 lockout) |
| `recovery_ack` | 24 hours |
| Generic motivation | 24 hours (effectively once daily) |

## 5.4 Daily speak budget

| Accountability mode | Max coach messages per day |
|---|---:|
| Forgiving | 4 |
| Strict | 7 |
| Ruthless | 10 |

User can override in settings as "Light / Standard / Heavy."

**Budget exceptions:** Priority 1 (Critical) bypasses budget. Priority 2 respects it. Priority 3 and 4 are first dropped when budget is tight.

## 5.5 Per-message rate limit

No more than one message every 15 minutes regardless of priority — except priority-1 crisis.

## 5.6 Silence windows (override)

Time ranges when proactive messaging is forbidden:

| Window | Source | Override |
|---|---|---|
| Sleep | `fixedBlocks[id='sleep']` | Crisis only |
| Class | per-day `fixedBlocks[id='classes']` | Crisis only |
| User-marked focus | `customTasks` with `isFocus: true` | Crisis only |
| Just spoke | last 90s | Unbreakable, even crisis |
| Sleep deficit | last sleep < 5h, until +1h after wake | Crisis only |

---

# Part 6 — Stress & Crisis Detection

These are pattern-match lists used by Rules D1 and E1. They live in code (`coach_safety_lists.dart`), never Firestore.

## 6.1 Stress markers

Used by Rule D1. Substring case-insensitive match on user-typed text only:

```dart
const STRESS_MARKERS = [
  // Direct
  'overwhelmed', 'overwhelm', 'cant cope', "can't cope",
  'too much', 'breaking down', 'falling apart',
  'stressed', 'stress out', 'panic',
  'cant sleep', "can't sleep", 'cant breathe', "can't breathe",

  // Cognitive
  'cant focus', "can't focus", 'cant think', "can't think",
  'spinning', 'going in circles', 'in my head',
  'overthinking', 'over thinking',

  // Avoidant
  'cant face', "can't face", 'dont want to', "don't want to",
  'whats the point', "what's the point", 'no point',

  // Hindi-English mixed (PRD persona is Indian)
  'tension hai', 'pareshan', 'dimag kharab', 'mood off',
];
```

False positives are fine here — sending "you ok?" to someone who said "stressed" colloquially is low-cost.

## 6.2 Crisis markers

Used by Rule E1. Two-tier:

```dart
const CRISIS_MARKERS_HIGH = [        // exact phrase, fire immediately
  'kill myself', 'kill me', 'end it', 'end my life',
  'dont want to live', "don't want to live",
  'better off dead', 'no reason to live',
  'suicide', 'suicidal',
  'hurt myself', 'hurting myself', 'self harm', 'cut myself',
];

const CRISIS_MARKERS_AMBIGUOUS = [   // require additional signal
  'disappear', 'gone forever', 'whats the point of anything', 'no future',
  // Trigger only if combined with: depression keywords, OR
  // user_state == 'relapsing' for 7+ days, OR
  // night-time (22:00–04:00 local)
];
```

When CRISIS_MARKERS_HIGH match → fire E1 immediately, bypass everything.
When CRISIS_MARKERS_AMBIGUOUS match alone → fire D1 (stress), but log to `coach_review` collection for human pattern review.
When CRISIS_MARKERS_AMBIGUOUS match with secondary signal → fire E1.

This list is hardcoded, code-only, version-controlled. It cannot be changed at runtime.

---

# Part 7 — Context Builder

The engine builds a `ContextSnapshot` before every decision. This is what gets evaluated against rule conditions and what gets injected into the Claude prompt.

## 7.1 Full ContextSnapshot schema

```json
{
  "user_id": "uid_abc",
  "schema_version": 1,

  "identity": {
    "coach_name": "Sensei",
    "coach_style": "supportive",
    "accountability": "strict",
    "identity_tags": ["Strong Body", "Inner Peace"],
    "eating_disorder_flag": false,
    "coach_enabled": true
  },

  "now": {
    "timestamp": "2026-04-26T14:23:00+05:30",
    "local_time_hhmm": "14:23",
    "day_of_week": "Sunday",
    "current_routine_block": null,
    "in_silence_window": false,
    "current_silence_window": null
  },

  "today": {
    "events": [
      {"type": "habit.bad_logged", "habit": "cigarettes", "ts": "11:42"},
      {"type": "routine.completed", "routine": "morning_skin_care", "ts": "07:30"}
    ],
    "habit_logs": {"cigarettes": 1, "scroll_minutes": 47},
    "routine_completion": 0.45,
    "tasks_completed": 4,
    "tasks_abandoned": 1,
    "screen_time_by_app": {"instagram": 87, "youtube": 22}
  },

  "last_7_days": {
    "streaks": {
      "cigarettes_clean": 0,
      "gym": 5,
      "meditation": 12
    },
    "routine_completion_daily": [0.8, 0.9, 0.6, 0.7, 0.5, 0.4, 0.45],
    "user_state_history": ["on_track","on_track","slipping","slipping","slipping","relapsing","slipping"]
  },

  "coach_history": {
    "last_spoke_at": "2026-04-26T10:00:00+05:30",
    "topics_spoken_last_24h": ["morning_brief"],
    "messages_today_count": 1,
    "speak_budget_remaining": 6,
    "deferred_messages": []
  },

  "user_state": "slipping",

  "derived": {
    "bad_day_signal_count": 2,
    "routine_miss_count_7d": {"gym": 4, "meditation": 1, "skin_care": 0},
    "consecutive_recovery_days": 0,
    "clean_streak_for_active_habit": 3,
    "scroll_minutes_in_window": 0
  }
}
```

## 7.2 Build order

```
1. Read identity from UserModel (cached)
2. Compute now block from system clock + routine
3. Stream-aggregate today's events from events_recent (last 24h)
4. Aggregate last_7_days from events_recent + day_close documents
5. Read coach_history from local Hive boxes
6. Classify user_state per §1.7 (using last_7_days)
7. Compute derived fields (multi-event detectors)
8. Freeze the snapshot — pass to engine
```

The snapshot is immutable. The engine reads it; it does not modify.

## 7.3 What gets sent to Claude

Not the whole snapshot — only the slice needed for the specific rule. See §8 for prompt assembly.

---

# Part 8 — Prompt Engineering Layer (Claude)

This is the only place the LLM is called. Rules have already determined topic, archetype, intent, and example outputs by this point.

## 8.1 Single-shot, non-streaming, JSON-out

The Coach uses one Anthropic API call per message. We use Claude Haiku for cost efficiency — coach messages are short and don't need the largest model. Output is JSON for safe parsing.

## 8.2 The system prompt template

This is hardcoded in `coach_prompt_builder.dart`:

```
You are {coach_name}, a personal coach inside the Optivus app.
The user named you. They chose your coaching style as: {coach_style_description}.

CORE BEHAVIORAL RULES — these are absolute, never violate:
1. Never assume what the user is feeling. Ask, don't tell.
2. Never command. Suggest, invite, ask.
3. Never moralize about food, weight, or appearance.
4. Never enumerate the user's failures.
5. Never use exclamation marks unless the message is a celebration.
6. Match the energy of the trigger — small slip = small response.
7. Keep responses under 3 sentences unless the user asked a question.
8. Never start a response with "I".
9. The user is an adult. Their autonomy is sacred.

TONE FOR THIS MESSAGE:
- Archetype: {archetype}              ('forgiving' | 'strict' | 'celebratory' | 'gentle')
- Intent: {ai_intent}                  (description of what to accomplish)

THE USER:
- Goals they're pursuing: {identity_tags}
- Their current state: {user_state_description}     (we never tell them this label)

CONTEXT:
{context_summary}                      (1-3 lines, see §8.3)

EXAMPLES OF MESSAGES THAT MATCH THE INTENT (match this style, do not copy verbatim):
{example_outputs}

PROMPT FOR THIS SPECIFIC EVENT:
{prompt_template}

OUTPUT FORMAT — return ONLY this JSON, no other text:
{
  "message": "<the message you would send, max 400 chars>",
  "type": "<one of: check_in | nudge | celebration | reflection | safety>",
  "priority": <1-4 matching the rule's priority>
}
```

## 8.3 Context summary — keeping it short

The prompt does NOT receive the full ContextSnapshot. It receives a 1–3 line summary built per-rule. Examples:

For Rule `slip_cigarette_strict_on_track`:
```
First cigarette today after 3 clean days. User had a 70%-completion morning routine.
Last coach message was 4 hours ago about morning brief. Strict accountability mode.
```

For Rule `bad_day_pattern`:
```
Today: 2 missed routines, 4 cigarettes, 95 min Instagram, 1 stress marker in chat.
Last 7 days completion: dropping (80%→45%). User state: slipping for 4 days.
No coach message in 6 hours. Forgiving mode forced (override).
```

This is built by a small helper per rule (`buildContextSummaryFor(rule, snapshot)`). Keeps the prompt tight, focuses Claude on what matters.

## 8.4 Fallback when Claude fails

Three fallback layers, tried in order:

1. **Retry once with 1-second backoff** — 90% of transient failures resolve here.
2. **Use `rule.fallback_message` directly** — the rule's hardcoded text with placeholders filled in.
3. **Skip the message entirely, log the failure** — only if both above also fail. The user gets nothing rather than something incoherent.

Latency budget: 5 seconds end-to-end. If Claude hasn't responded in 5s, drop to fallback. Coach messages are not worth keeping the user waiting.

## 8.5 Why these constraints in the system prompt

Each numbered rule in §8.2 maps to a specific failure mode we've seen in coaching/chatbot products:

- Rule 1 (don't assume feelings) → fixes Case 3 raw idea ("Are you sad?")
- Rule 2 (don't command) → fixes Case 2 raw idea ("Stop using")
- Rule 3 (don't moralize about food) → prevents triggering disordered eating
- Rule 5 (no exclamation marks except celebration) → kills the "fake hype" tone
- Rule 6 (match energy) → prevents catastrophizing minor slips
- Rule 8 (don't start with "I") → "I noticed..." is the most-overused AI opener; banning it forces freshness

These rules have been hammered through PRD persona testing. Don't soften them.

---

# Part 9 — Output Format

Every coach message produces exactly this structured object, written to `coach_messages/{uid}/messages/{messageId}`:

```json
{
  "message_id": "msg_01HX...",
  "user_id": "uid_abc",
  "timestamp": "2026-04-26T14:23:42+05:30",
  "schema_version": 1,

  "message": "First one in 3 days — not nothing. What set it off today?",
  "type": "check_in",
  "priority": 2,

  "rule_id": "slip_cigarette_strict_on_track",
  "trigger_event_id": "evt_01HX...",

  "suggested_actions": [
    {"label": "Log trigger", "action": "log_trigger", "params": {}},
    {"label": "Set guard rail", "action": "set_guardrail", "params": {}},
    {"label": "Talk to me", "action": "open_chat", "params": {}}
  ],

  "followup_scheduled_at": "2026-04-26T16:23:42+05:30",
  "ai_generated": true,
  "fallback_used": false
}
```

The CoachTab subscribes to `coach_messages/{uid}/messages` ordered by `timestamp DESC` and renders new bubbles as they arrive.

The `coach_speak_log` collection (§1) gets a parallel write with the full debug context — what rule fired, what context was built, what prompt was sent, what Claude returned, why fallback was or wasn't used. This is the audit trail that lets us answer "why did the coach say that?" three months from now.

---

# Part 10 — Design Principles

These are the non-negotiables. Every rule, every message, every refactor must respect them. If you find a conflict between a rule and a principle, the principle wins — change the rule.

## 10.1 The ten principles

### 1. Never assume what the user is feeling
Don't say "you're sad," "you're stressed," "you're frustrated." Ask. Use open language: "what's going on," "anything pulling at you," "what set this off."

### 2. Never command
"Stop scrolling" is wrong. "Want to take a break?" is right. The user is an adult who set their own goals — coach reminds, doesn't enforce.

### 3. Match the energy
A small slip gets a small response. A 7-day streak gets a measured nod, not a parade. A bad day gets quiet acknowledgement, not a pep rally. This builds trust — the coach is calibrated, not theatrical.

### 4. Short by default
Unless the user asks a question, default response is 1–3 sentences. Short messages feel human. Long messages feel like therapy bots.

### 5. Acknowledge before suggesting
If you're going to suggest action, name what just happened first. "Four cigarettes today. Want to figure out what's driving it?" — not "Have you tried deep breathing?"

### 6. Never moralize about food, weight, or appearance
This category causes more harm than help. Eating disorder safety guard (§3 Rule C5) hard-locks the entire food coaching path when flagged. Even without the flag, food coaching uses forgiving archetype always.

### 7. Respect user-set rules, not coach-imposed ones
The user said "limit Instagram to 2 hours" — the coach reminds when they crossed THEIR limit, not a coach-invented one. Frame: "you crossed your limit," not "you're using too much."

### 8. Make dismissal easy
Every message has a way to walk away — "Talk to me" is an option, not a requirement. Some messages have an explicit "Leave it" button. The user must always feel they can ignore the coach without consequence.

### 9. The coach is not a friend or therapist
It's a coach. Friendly, helpful, but bounded. Don't fake intimacy ("I really care about you"). Don't pretend therapeutic capability ("this could be deeper trauma"). When stakes get high (crisis markers), refer out — that's what Rule E1 is for.

### 10. Silence is a feature
Not speaking is often the right answer. Cooldowns, silence windows, the bad-day detector that consolidates messages — these all exist because the alternative (more messages) makes the product worse. When in doubt, drop the message.

## 10.2 Anti-patterns to never ship

Specific phrasings that fail the principles. Hard-block these in the system prompt OR add a post-generation regex check:

| Anti-pattern | Why it fails |
|---|---|
| "I noticed..." (as opener) | AI cliché; rule 8 in §8.2 forbids opening with "I" |
| "Are you feeling X?" | Assumes the emotion (Principle 1) |
| "You should..." | Commands (Principle 2) |
| "You need to..." | Commands (Principle 2) |
| "It's important that you..." | Soft commands (Principle 2) |
| "I'm here for you ❤️" | Fake intimacy (Principle 9) |
| "Let's crush today!" | Fake hype (Principle 3) |
| "Take a deep breath and..." | Therapy-speak (Principle 9) |
| "Don't be hard on yourself" | Patronizing; tells user how to feel (Principle 1) |

If the LLM produces any of these, fall back to `rule.fallback_message`.

---

# Part 11 — Implementation Plan (for Antigravity)

Build phases in this order. Each phase has an exit criterion before the next phase starts.

## Phase 1 — Engine skeleton, no LLM (1–2 days)

Build:
- `ContextSnapshot` class
- `Rule`, `Condition`, `ToneSpec`, `ActionButton` classes
- Rule loader from `coach_rules.dart` (static const list)
- `RuleEngine.evaluate(event, snapshot) → Decision`
- Priority resolution per §5.2
- Cooldown check (Hive-backed) per §5.3
- Speak budget check per §5.4
- Silence window check per §5.6

Tests:
- Every example in §1.8 produces the documented decision
- Every rule in §3.2 unit-tested with synthetic snapshots
- Cooldown enforcement tested with time mocking

**Exit:** all tests pass, no LLM called, no Firestore writes, full coverage.

## Phase 2 — Coach voice, fallback messages only (1 day)

Build:
- `CoachTemplate` class with `prompt_template`, `example_outputs`, `fallback_message`
- `CoachLogic.selectTemplate(rule, snapshot) → CoachTemplate`
- `template.fillPlaceholders(snapshot) → string` — renders the fallback

Tests:
- Every rule has a fallback that renders correctly
- Placeholder substitution works on all snapshot fields

**Exit:** Coach can speak using only fallback messages, no LLM, for every rule.

## Phase 3 — Wire into CoachService (1–2 days)

Build:
- `CoachService.onEvent(event)` per §1.1 pipeline
- Hive boxes: `coach_budget`, `coach_last_spoke`, `coach_deferred`
- Subscribe to `EventService` event stream
- Write to `coach_messages` Firestore collection
- Write to `coach_speak_log` per §1.2 stage 8

Tests:
- Integration test: fire a real event, see a coach message in Firestore

**Exit:** end-to-end flow works without LLM. CoachTab renders fallback messages.

## Phase 4 — Add Claude generation layer (1–2 days)

Build:
- `claude_client.dart` — Anthropic API wrapper, server-side via Cloud Function (per audit P0-2, never client-side keys)
- `coach_prompt_builder.dart` — system prompt template per §8.2
- `buildContextSummaryFor(rule, snapshot)` per §8.3
- 5-second timeout, retry once, fall back per §8.4
- Anti-pattern post-check per §10.2

Tests:
- Mock Claude response → verify prompt structure
- Simulate Claude timeout → verify fallback fires
- Simulate Claude returns "I noticed..." → verify regex catches and falls back

**Exit:** identical routing decisions as Phase 3, but messages now LLM-varied.

## Phase 5 — Scheduled checks (Cloud Function) (1 day)

Build:
- Cloud Function on Pub/Sub schedule
- Morning brief, midday pulse, day close, inactivity 24h, inactivity 48h
- Each is a synthetic event sent to the regular pipeline

**Exit:** scheduled messages appear at the right times.

## Phase 6 — Watched conditions (1 day)

Build:
- Local Dart timer, 60s tick
- Evaluate conditions in a registry (`watched_conditions.dart`)
- Each true condition emits a synthetic event

Conditions to start with (keep under 10 total):
- Mission ring 0% with 90 min left in day → streak rescue
- Scrolling > 60 min in 90 min window with no productive event → D2
- User in routine setup screen 5+ min with no save → "want help finishing?"

**Exit:** the streak-rescue-after-8pm scenario fires correctly in manual test.

## Phase 7 — Polish (2–3 days)

- Suggested-action button rendering in CoachTab
- Followup scheduling per §3.1 `followup_policy`
- "Listening mode" UI when crisis E2 is active
- Multi-event detector tuning (`derived.*` fields)
- Anti-pattern regex hardening

**Total estimated build time:** 8–12 days for a focused solo dev. Less if multiple workstreams in parallel.

---

# Part 12 — Open Design Questions

These are intentionally NOT decided. Antigravity must NOT silently pick one — flag any decision point and ask Nairit.

### Q1. Where does the engine run?
On-device (Dart) or in a Cloud Function?

**Recommendation:** on-device for reactive (events) and watched (timer); Cloud Function for scheduled checks. Reactive needs <30s latency that a function call can't beat. Scheduled benefits from server reliability.

### Q2. Are rules code or config?
Could rules live in Firestore, allowing remote tuning?

**Recommendation:** code. A bad rule shouldn't be shippable without code review. Rules change with releases, not at runtime.

### Q3. How does the user turn the coach off?
Profile setting `coachEnabled: bool` (default true). When false, all priorities < 1 are suppressed. Crisis (priority-1 + crisis archetype) still fires. Needs to be added to `UserModel` (which currently doesn't even hold these fields per audit).

### Q4. Replies to coach messages — new flow or chat flow?
**Recommendation:** reply enters chat as `chat.user_message` event, gets evaluated by D1 (stress) and E1 (crisis). Otherwise normal chat reply via `GeminiService.startChat` (or Claude Haiku — see Q5). No new flow.

### Q5. Claude or Gemini in production?
Spec is written for Claude. Existing code uses Gemini. Switching is one file (the LLM client) but requires:
- Anthropic API key managed server-side (Cloud Function)
- Per-user rate limits
- Token cost monitoring

**Recommendation:** Claude Haiku for coach (better persona discipline). Keep Gemini Flash for the routine task suggestions (already working). Two LLMs, two responsibilities, two cost lines.

### Q6. Multi-language support?
PRD persona is Indian → Hinglish stress markers in §6.1. Expansion to other locales requires per-locale marker lists. Not in v1.

### Q7. Anti-pattern enforcement — regex or LLM-as-judge?
The §10.2 anti-pattern list could be enforced two ways:
- **Regex post-check:** fast, free, but brittle (fails on near-matches)
- **LLM-as-judge:** accurate but doubles cost and latency

**Recommendation:** start with regex. Monitor false-positive rate via `coach_speak_log`. Upgrade to LLM-judge only if regex misses too much.

---

# Part 13 — What this changes about the existing codebase

Per the audit:

1. **`EventService` doesn't exist yet.** Build it first. It's the input layer for everything in this document.
2. **`HabitService`, `TaskService`, `StreakService` don't exist.** Their events are what the engine reacts to.
3. **`CoachService` is new** — the home for everything in this document.
4. **`coach_messages` and `coach_speak_log` Firestore collections are new.**
5. **`CoachTab` will be rewritten** as a thin renderer for `coach_messages`. Its current hardcoded demo bubbles get deleted.
6. **The Anthropic API key must move server-side.** Per audit P0-2, the existing Gemini key is shipped client-side via `String.fromEnvironment` — extractable from any APK. This is a P0 security issue regardless of which LLM you choose.
7. **The `AiRoutinePanel` in the routine tab stays as-is.** It's task-suggestion, not coaching. Independent flow. Keep it on Gemini for now.

---

# End of master spec

This document is the single source of truth for the Optivus AI brain. When implementing:

- §1–4 define *what fires* (rule engine + advanced detectors)
- §5–6 define *what gets through* (priority/cooldown + safety)
- §7–8 define *what gets said* (context + prompt to Claude)
- §9 defines *what comes out* (structured message)
- §10 defines *the unbreakable rules*
- §11 defines *how to build it*
- §12 flags *what's still undecided*

Do not edit any single section without checking dependencies. §3 depends on §1.7 (user states), which depends on §6 (context). §4 depends on §6 derived fields. §8 depends on §3 (rule outputs) and §10 (anti-patterns). It's a connected system.

If you ship it well, the user gets a coach that feels human, calibrated, and respectful — not a chatbot that nags. That's the bar.
