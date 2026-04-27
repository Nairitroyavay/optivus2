# Optivus — Product Requirements Document (PRD)

**Tagline:** *Plan. Execute. Become.*
**Document version:** 1.0
**Last updated:** April 2026
**Status:** Active development

---

## 1. App Overview

Optivus is an AI-powered **life operating system** built for people who feel stuck, scattered, or stagnant — and want to come back to themselves. It combines four things most apps split apart: a **daily routine planner**, a **habit & recovery tracker**, a **long-term identity-goals system**, and a **personal AI coach** that knows the user's goals, failures, schedule, and patterns.

Where calendar apps tell you *when*, and habit apps tell you *what*, Optivus tells you *who you're becoming* — and walks alongside you while you become it. Every screen, from the morning routine to the late-night reflection, ties back to a single question: *Is what I'm doing today moving me closer to the person I said I wanted to be?*

The product is structured around six tabs: **Home, Routine, Tracker, Coach, Goals, Profile**, each rendered in a distinctive iOS-inspired liquid-glass design system that signals "this isn't another to-do app — this is a living interface for your life."

---

## Technical Constraints

The product vision above is what Optivus aims to be. This section is the engineering reality v1 ships within. These constraints align product expectations with what the team can actually build, ship, and maintain.

- **MVP built using Flutter + Firebase.** Single Flutter codebase targeting Android first. Firebase handles auth, Firestore for data, Crashlytics for monitoring. No custom backend in v1.
- **Event-driven architecture.** Every user action emits an event. Streaks, mission rings, and analytics are all derived from the events log — not from independent counters that could drift out of sync.
- **Offline-first support.** The app must function without a network connection for core flows (routine, habit logging, journaling). Writes queue locally and sync when network returns.
- **AI coach is NOT part of MVP (phase 2).** v1 ships with rule-based notifications and fallback messages only. The full AI coach (Decision Engine + LLM-generated wording) is a phase-2 feature that builds on the event system once it is stable in production.

These constraints can be revisited at the v2 planning cycle, but they are firm for v1.

---

## 2. Problem Statement

### The pain we're solving

Modern young people — especially students and early-career professionals — are drowning in **fragmented self-improvement tools** while still falling apart on the inside.

A typical user has:
- A **calendar app** for classes
- A **notes app** for goals
- A **habit tracker** for streaks
- A **screen-time tool** that scolds them
- A **journaling app** they abandoned in week two
- And, when things get bad, a **chatbot** they vent to at 2 AM

None of these tools talk to each other. None of them know that the user smoked today *because* they missed gym yesterday *because* they doom-scrolled until 3 AM the night before. Each tool sees one symptom; nobody sees the human.

### The deeper problem

People don't fail because they lack tools — they fail because:

1. **Bad habits compound silently.** Smoking, doom-scrolling, junk food, procrastination — they each look small in isolation, but they corrode identity over months.
2. **Good habits don't stick** without daily friction reduction and personalized accountability.
3. **Long-term identity goals** ("become fit", "top student", "financially free") feel disconnected from the 9 AM Tuesday they're actually living.
4. **Overthinking and decision fatigue** kill execution. People know what to do — they just can't get themselves to do it consistently.
5. **There is no one watching.** A coach, a parent, or a mentor used to fill this role. Most users today have nobody.

### Our thesis

If a single product can hold the user's **routine + habits + goals + accountability + emotional support** in one place, and a context-aware AI can speak into that whole picture every day, the user stops fighting fragmentation and starts compounding wins.

---

## 3. Target Users

### Primary persona: The Stuck Striver (ages 17–26)

Students and early-career users who *want* to be high-performers but keep slipping. They're ambitious, online, self-aware, and tired of being told to "just be disciplined."

**Sub-segments:**

| Segment | Description | Key pain |
|---|---|---|
| **Students** | High-school and university students balancing classes, self-study, social life, and the slow erosion of attention | "I know what to study but I can't make myself" |
| **Productivity seekers** | Builders, coders, creators chasing output | Burnout cycles, no recovery system |
| **Recovery users** | Quitting cigarettes, vapes, alcohol, weed, porn, doom-scrolling | Need streak tracking + emotional support, not shame |
| **Overthinkers** | Smart people paralyzed by analysis | Need someone to externalize decisions to |
| **Identity-shifters** | Want to "become fit", "become disciplined", "become financially free" | The gap between aspiration and Tuesday morning |

### Secondary persona: The Comeback User

Someone in their late 20s–30s who fell off — burnout, breakup, addiction, a hard year — and is trying to rebuild a life from the ground up. Optivus is the scaffold.

### Who Optivus is **not** for

- People who already have a tight system and just need a calendar
- Pure to-do-list users (Optivus is opinionated, not neutral)
- Users seeking clinical mental-health treatment (we route to professionals when appropriate)

---

## 4. Core Features

The product is organized into seven feature pillars. Each one stands alone, but the magic is in how they feed each other.

### 4.1 Routine Builder — *the daily skeleton*

A 24-hour timeline the user composes once, then lives by. Each weekday (Mon–Sun) gets its own configuration so the user's reality (Tuesday gym, Thursday late class, Sunday rest) is honored.

**What the user sets up:**
- **Fixed schedule blocks** — sleep, classes, work, commute, meals (the immovable scaffolding of the day)
- **Skin care routine** — morning, afternoon, night steps, configured per day, per product
- **Class timetable** — subject, room, professor, start/end time, weekday
- **Eating routine** — meal name, food, time, with AI nudges when the plan doesn't match the user's body goals (e.g., underweight → gain plan)
- **Custom blocks** — anything else: gym, meditation, reading, walks

**What the system does with it:**
- Renders a beautiful vertical timeline with day/week/month/year zoom
- Shows "now" indicator with pulsing badge
- Lets the user check off subtasks inside a block (e.g., the four steps of evening skincare)
- Surfaces a daily completion percentage that feeds the streak tracker
- Drag-to-resize blocks with haptic feedback and snap-to-15-minutes

### 4.2 Habit Tracker — *good habits in, bad habits out*

Two parallel systems, one product:

**Good habits** (build):
- Gym, coding, reading, meditation, journaling, water intake (3–4L/day), etc.
- Daily goal (45m gym, 2h coding, 30m reading…)
- Visual progress bar per habit
- Streak counter with milestone celebrations

**Bad habits** (drop):
- Cigarettes, doom-scrolling, junk food, procrastination, alcohol, weed, porn, etc.
- Track *count* and *trigger* (when, why, how the user felt)
- Money-saved counter for cigarettes/alcohol (concrete reward)
- "Days clean" counter for recovery

**Phone-data integration (Android):**
- Screen time pulled from system APIs
- App-usage data (Instagram, TikTok, Reddit, etc.)
- Unlock behavior (how many times the phone was unlocked)
- This data feeds the AI coach so it can say, *"You unlocked your phone 142 times today — let's talk about what you're avoiding."*

### 4.3 Long-Term Identity Goals — *who you're becoming*

The user picks identity goals during onboarding (or adds custom ones):

- Become fit / strong body
- Top student
- Become disciplined
- Master a new language
- Become financially free
- Start a business
- Find inner peace
- Better partner / friend / parent
- Travel the world

Each identity goal:
- Gets a start date and end date (or "ongoing")
- Auto-decomposes into daily tasks and habits (e.g., "Become Fit" → Gym 5×/week + 3L water + sleep before 11)
- Has its own progress view, milestones, and "next action"
- Surfaces in the AI coach's context window so it can connect daily choices to identity ("Skipping gym today moves the *Become Fit* identity from 73% → 71%")

### 4.4 Daily Task Engine — *start it, finish it, prove it*

Beneath every routine block and habit, there's a flat list of **today's tasks** the user can swipe through. AI can add, remove, or reschedule tasks via natural language ("add yoga at 7 AM", "move my deep-work session to after lunch").

Tasks support:
- Custom emoji + color
- Specific time or "anytime today"
- Carry-over rules based on the user's accountability style
- AI-suggested tasks based on goals and gaps in the day

#### Task lifecycle: Scheduled → Started → Completed

Every scheduled task has explicit states the user moves through, so Optivus knows what *actually* happened — not just what was planned.

1. **Scheduled.** Task sits on the timeline waiting for its start time.
2. **Started** — when the user begins, they tap **"I'm starting this"**. The task animates into an active state with a live elapsed-time counter. The timeline shows a glowing "in progress" indicator and the active task gets pinned at the top of the screen. This single tap is the heart of the system — it's the user *making contact with their own intention*.
3. **Completed** — the user taps **"Mark as complete"** when they finish. The actual duration is captured (planned: 45m, actual: 52m → AI learns the user is consistently ~15% over on gym).
4. **Paused** — for interruptions; the timer pauses and resumes on the next tap. After a configurable threshold (default 20 min paused), the task is auto-marked abandoned and the coach asks what happened.
5. **Skipped / Abandoned** — if the user closes a started task without completing, or the scheduled time passes without a start, the system records it and asks why later (in a non-shaming, data-gathering way).

**Subtasks inside a started task** — Skin care has 4 steps; gym has 6 exercises. Once a parent task is started, its children become tap-to-check, and the parent auto-completes when all children are done.

**Why this matters:**
- It separates *intent* (planned) from *execution* (started) from *outcome* (completed) — three different signals the AI uses very differently
- It surfaces honest data: if a user "checks off" tasks they didn't actually do, the coach can't help them; the start/end gate makes lying require more effort than truth-telling
- Real durations replace estimates over time — after 30 days the app *knows* the user's morning routine takes 47 minutes, not the 30 they planned, and replans the day around reality

### 4.5 Smart Notifications & Custom Alarms — *the system that won't let you ghost yourself*

A scheduled task nobody reminds you about is a wish. Optivus pairs every block with a layered notification system the user controls.

#### Three escalation tiers

| Tier | When | What happens | User control |
|---|---|---|---|
| **1. Gentle nudge** | 5 min before task start time | Standard push notification: *"Gym in 5 minutes — tap to start"* | On/off per task type |
| **2. Active alert** | User hasn't tapped "Start" 5 min after the scheduled time | Persistent banner + soft chime + AI message: *"Your 5 PM gym block is hanging — start it or push it?"* | On/off, snooze 5/10/15 min |
| **3. Custom alarm** | User opted into this tier for high-priority tasks (wake-up, medication, deep-work, gym) | Full-screen alarm with the user's chosen sound, vibration pattern, and on-screen message — dismissible only by tapping **Start**, **Snooze (with reason)**, or **Skip (with reason)** | Per-task opt-in |

A symmetrical alert exists at the **end** of a task: if the user started but never tapped "Mark as complete", a soft chime fires at the planned end time — *"Did you finish the gym block? Mark it done or extend by 10 min."* This closes the loop without nagging.

#### Custom alarm features

- **Pick your sound** — a library of built-in tones (gentle bell, deep gong, energizing chime, soft sunrise) plus the option to upload your own
- **Coach voice alarms** — AI-generated voice clips in the user's chosen coach voice/style: *"Bro. It's 5 AM. You said this matters. Get up."* (Tough Love), or *"Good morning. Take your time. I'm here when you're ready."* (Supportive)
- **Vibration patterns** — subtle, standard, or "earthquake mode" for heavy sleepers
- **Snooze with friction** — snoozing requires picking a reason from a short list ("tired", "not feeling it", "actually busy", "other"), which feeds the AI's understanding of the user's resistance patterns
- **Wind-down notifications** — 15 min before the sleep block, the coach pings: *"Phone away in 15. Want to journal?"*
- **Recovery alarms** — for users quitting a habit, a gentle alert at known trigger times: *"3 PM is when you usually crave a cigarette. You've gone 4 hours. Drink water and walk for 90 seconds."*

#### Notification budget

To prevent fatigue, every user has a daily notification budget (default: 8 push notifications across all categories). The AI prioritizes which ones to send based on what's most likely to land that day. The user can raise or lower this budget anytime, and there's a one-tap "Quiet day" mode for exam days, sick days, or hard days.

### 4.6 Streaks & Progress

The reward layer. Every system feeds it:
- Day streak (consecutive days hitting routine completion target)
- Per-habit streaks (12 days no cigarettes, 30 days morning skincare, etc.)
- Money saved (₹ tracker for cigarettes/alcohol)
- Recovery counter (days clean from each addiction)
- Weekly/monthly trend charts

Streaks are designed to feel earned, not gamified. Breaking one isn't catastrophic — the AI coach contextualizes it.

### 4.7 AI Coach *(see Section 6 — this is the differentiator)*

A persistent, context-aware AI that has access to **everything** the user has shared and done in the app. It runs in three modes:

1. **Ambient nudges** — proactive suggestions on the timeline ("Add a 20-min walk at 3 PM, you have a free gap")
2. **Direct chat** — open-ended conversation in the Coach tab ("I'm stressed and want to smoke")
3. **Topic modes** — Recovery Coach, Study Coach, Fitness Coach, Calm Coach (different system prompts, same memory)

### 4.8 Onboarding & Personalization

An 11-step onboarding flow that's the foundation of everything else:

1. Welcome
2. Pick focus areas (Health, Career, Skill, Recovery, Growth, Focus)
3. Drop bad habits (multi-select)
4. Build good habits (multi-select)
5. Pick long-term identity goals
6. **About you** — the data the AI needs to actually personalize your plan *(see 4.9 below)*
7. Choose coach style (Supportive / Tough Love / Analytical / Zen Master / Motivational / Friendly)
8. Name your coach (Dad, Maa, Sensei, Bro, Sir, custom)
9. Pick accountability style (Forgiving / Strict / Ruthless)
10. Set your fixed 24h schedule
11. Review your AI-generated plan

This onboarding produces the user's **Identity Profile**, which becomes the system prompt every AI interaction is grounded in.

### 4.9 The "About You" onboarding screen — *the data the AI cannot guess*

This screen is the single biggest unlock for AI personalization quality. Without it, the coach is making educated guesses; with it, the coach has the same baseline a real personal trainer or nutritionist would ask for in their first session.

The screen is split into three short sub-pages so it never feels like a form:

#### Page 1 — Body basics

| Field | Type | Required | Why we ask |
|---|---|---|---|
| Date of birth | Date picker | Required | Age-calibrated targets (a 19-year-old's recovery is not a 45-year-old's) |
| Gender | Female / Male / Non-binary / Prefer not to say | Optional | Calorie & macro math; coach pronoun choice |
| Height | cm or ft+in toggle | Required | BMI, calorie targets, posture/exercise advice |
| Current weight | kg or lbs toggle | Required | BMI, calorie targets, recovery monitoring |
| Target weight | kg or lbs, optional | Optional | Lets the AI design a gain/maintain/lose plan |
| Activity level | Sedentary / Lightly active / Moderately active / Very active | Required | Calorie targets, gym-volume realism |

The AI uses these to compute and *show* the user their BMI, daily calorie target, and water target — and to flag concerns ("You're underweight — let's plan a gain, not a cut") right inside the onboarding screen. This is the moment the user first feels the AI *seeing* them.

#### Page 2 — Lifestyle rhythm

| Field | Type | Required | Why we ask |
|---|---|---|---|
| Typical wake time | Time picker | Required | Anchors the morning routine and sleep block |
| Typical sleep time | Time picker | Required | Anchors the wind-down notification + sleep target |
| Daily water target | Auto-suggested in litres, editable | Required | The single most underrated habit; auto-suggested as `weight × 35 ml`, user can override |
| Occupation status | Student / Working / Both / Looking / Other | Required | Tunes the language and example schedules the coach uses |
| Country / timezone | Auto-detected, editable | Required | All scheduling and notifications are timezone-correct |

#### Page 3 — Sensitive context (optional, skippable)

This page is explicitly framed as *"Tell us only what you want — you can update this anytime in Profile."* Every field is skippable, and the data is stored encrypted and used **only** to shape the coach's tone and advice — never shared, never displayed publicly.

| Field | Type | Why we ask |
|---|---|---|
| Dietary preference | None / Vegetarian / Vegan / Pescatarian / Halal / Kosher / Keto / Other | The coach won't suggest meals you can't eat |
| Allergies / restrictions | Free text | Same |
| Health flags | Checkboxes: asthma, diabetes, anxiety, depression, ADHD, thyroid, PCOS/endometriosis, chronic pain, eating disorder history, addiction recovery, other | The coach softens its tone, avoids unsafe advice, and routes to professionals when appropriate |
| Currently in therapy / on medication | Yes / No / Prefer not to say | The coach knows it's a *complement*, never a substitute |

If the user checks **eating disorder history**, the app silently disables calorie counting, weight-tracking nudges, and "before/after" framing throughout the product. The coach's tone shifts to body-neutral. This is non-negotiable.

#### Why this screen is mandatory in v1

Every other feature improves with more user data, but the AI Coach *requires* this baseline to be useful at all on Day 1. Without it, the coach gives generic advice that feels like ChatGPT. With it, the coach feels like a friend who has been paying attention.

---

## 5. User Scenario — Nairit's Day

Nairit is 19, 50 kg, 5'9", a CS student. He's underweight, smokes 4–5 cigarettes a day to manage exam stress, doom-scrolls Instagram for 3–4 hours, and procrastinates on self-study. He wants to gain weight, get fit, code daily, read, meditate, and drink 3–4 litres of water. He installs Optivus.

### Onboarding (Day 0)

- Picks focus areas: **Health, Skill, Focus, Recovery**
- Drops: **Cigarettes, Doom-scrolling, Junk food, Procrastination**
- Builds: **Gym, Coding, Reading, Meditation, Hydration**
- Identity goals: **Strong Body, Become Disciplined, Top Student**
- **About you screen** — enters DOB (19), height (5'9"), current weight (50 kg), target weight (62 kg), activity level (lightly active), wake 9 AM / sleep 11 PM, occupation Student. The screen instantly shows him BMI 16.2 with a *"You're underweight — let's plan a gain"* card, and auto-sets a 2.8 L water target.
- Coach style: **Tough Love** — names the coach **"Bro"**
- Accountability: **Strict**
- Sets his fixed Monday schedule: wake 9 AM, self-study 10–11, gym 5 PM, sleep 10 PM
- Sets a different Tuesday: wake 7 AM, self-study 8–9, bath 11, gym 5 PM, sleep 10 PM
- Sets per-day skincare:
  - Mon 9:00–9:15 AM — Vitamin C serum
  - Mon 12:00–12:15 PM — Face wash + Vitamin E serum
  - Mon 4:00–4:15 PM — Face wash + cream
  - Mon 9:50–10:00 PM — Face wash + Vitamin C + night cream
  - (Different rituals for other weekdays)
- Opts into **custom alarms** for Wake-up and Gym; standard notifications for everything else.

**AI's first move:** *"Bro, your BMI is 16.2 — you're underweight. I'm rewriting your eating routine to add 600 surplus calories. Approve?"*

### Day 1 — Monday

- 8:55 AM — Custom alarm fires in "Bro's" Tough Love voice: *"It's 8:55. Get up before the alarm escalates."* Nairit dismisses it by tapping **Start** on his wake-up task. The day timer begins.
- 9:00 AM — Optivus pings him: *"Vitamin C serum. 15 min."* He taps **I'm starting this** on the skincare block. Subtask checkboxes appear.
- 9:14 AM — He taps the last subtask. The block auto-completes. Actual duration: 14 min (planned 15) — saved.
- 10:00 AM — Self-study block scheduled. He doesn't tap Start. At 10:05, an active alert fires: *"Your study block is hanging — start it or push it?"* He taps **Start**.
- 11:30 AM — He smokes a cigarette. Logs it in the tracker. Money-saved counter pauses for the day. Coach quietly notes the time.
- 1:00 PM — Lunch logged. AI flags: *"You ate 380 cal at lunch. You need 700 for surplus. Add a snack at 4 PM?"* — he accepts; a new task appears on the timeline.
- 5:00 PM — Custom gym alarm. He taps **Start** on the gym block. Active timer pinned at the top of the screen for 1h 22m.
- 6:22 PM — He taps **Mark as complete**. Actual: 82 min. Planned: 60 min. The AI updates his future gym estimates.
- 9:50 PM — Night skincare alarm. He taps Start, completes 4 subtasks.
- 10:00 PM — Wind-down notification: *"Phone away in 15. Want to journal?"* He ignores it and opens Instagram.
- 11:47 PM — Sleep block was scheduled for 10 PM. He never tapped Start. Auto-marked **abandoned**. Coach saves the data point silently.

### End of Day 1

The Tracker tab shows:
- ❌ Smoking: 2 (instead of usual 4–5)
- ❌ Scrolling: 4 hours (Android API confirms; sleep abandoned at 11:47 PM)
- ✅ Study: 1 hr (started 5 min late, completed)
- ✅ Gym: completed (planned 60m, actual 82m)
- ✅ Skincare: 3/4 blocks completed (he missed the 9 AM one because he started his wake-up late)
- 💰 Money saved today: ₹20

### AI message that night

> "Bro. You wanted *Strong Body* and *Top Student*, but you abandoned your sleep block and burned 4 hours on Instagram. You did ship 1 hour of study and you crushed gym (22 min over — that's real). Two things for tomorrow: phone in another room before 9 AM, and we cap Instagram at 1 hour. Also — your gym keeps running 20 min over, I'm bumping the planned slot to 80 min so the rest of your day stops slipping. Deal?"

### After 30 days

- Screen time ↓ 47%
- Cigarettes ↓ from 4–5/day to 1/day
- Study consistency ↑ to 18/30 days
- Weight: +2.1 kg
- He has a **17-day streak** on hydration
- The **Become Disciplined** identity has moved from 12% → 64%

This is the loop Optivus is built around: routine → tracking → AI synthesis → identity progress → routine adjustment → repeat.

---

## 6. App Differentiator — The AI Coach

Every feature in Sections 4 is, in isolation, available somewhere else. The reason Optivus exists is **the AI Coach** — and specifically, the AI Coach *with full memory of the user's entire system*.

### What the AI knows about the user

At any given moment, the coach has access to:

- The user's **Identity Profile** (focus areas, identity goals, accountability style, coach tone)
- Today's **routine** (every fixed block, every skin/eating/class entry)
- This week's **habit log** (every cigarette, every gym session, every missed study block)
- Long-term **identity goal progress** (Strong Body 64%, Top Student 41%, etc.)
- Phone usage data (screen time, top apps, unlock count)
- Past **conversations** with the coach (multi-turn memory)
- Mood / journal entries (when provided)

### What the AI does with it

**1. Personalized corrections.**
> *"You missed gym 3 times this week. Your *Strong Body* goal needs 5×, but realistically let's drop to 3× and protect those — better than failing 5."*

**2. Trigger-aware support.**
> *"You smoked at 11:30 AM. That's the third Monday in a row at the same time. What's happening between 10:30 and 11:30?"*

**3. Routine optimization.**
> *"You have a 90-min gap from 3–4:30 PM. Want me to add a deep-work block? Your *Top Student* identity is at 41% and slipping."*

**4. Identity-anchored framing.** Every nudge is connected back to *who the user said they wanted to become*. This is what makes the AI feel like a coach, not a chatbot.

**5. Mode-switching.** A "Recovery Mode" coach is gentler. A "Tough Love" mode is sharper. A "Calm" mode is for late-night spiral conversations. Same memory, different voice.

### Why this is defensible

A general-purpose chatbot can be smart, but it doesn't remember the user from yesterday and has no structured data about the user's life. A habit-tracker can have data, but no intelligence on top. Optivus's moat is **the integration** — every minute the user spends in the app makes the coach better at coaching *them specifically*. After 60 days, that coach is unswitchable.

### Coach voice & safety

- Coach **never shames, threatens, or uses pain-based motivation** even in Ruthless mode
- Coach **escalates to crisis resources** if the user expresses self-harm or severe mental health distress
- Coach **never gives medical, legal, or financial advice** — it nudges the user toward qualified humans
- Coach **respects "not today"** — if the user says back off, it backs off

---

## 7. Tab-by-Tab Surface Map

| Tab | Purpose | Primary surface |
|---|---|---|
| **Home** | Dashboard — today's mission ring, streak summary, habit check-in, recurring routines, calendar | Glanceable, motivating |
| **Routine** | The 24-hour timeline + filters (All, Fixed Schedule, Skin Care, Classes, Eating) | Plan and execute the day |
| **Tracker** | Water, steps, sleep, smoking, scrolling, study — all metrics in one place | Visual feedback loop |
| **Coach** | AI chat with persistent memory + topic modes | The conversation that holds the user |
| **Goals** | Long-term identities + active milestones + progress bars | The "why" behind everything |
| **Profile** | Identity statement, strengths, areas to improve, account settings, routine settings | Self-reflection + admin |

---

## 8. Success Metrics

**Activation:** % of users who complete onboarding (target: 70%)
**Engagement:** DAU/MAU ratio (target: ≥0.5 — daily-life apps need this)
**Retention:**
- D1: 60%
- D7: 35%
- D30: 20%
- D90: 12%

**Habit-product specific:**
- Median streak length (target: ≥7 days by Day 30)
- % of users who log a bad habit decline ≥30% in 30 days
- AI coach messages sent per active user per week (target: ≥5)

**Outcome metrics (the ones that matter most):**
- Self-reported life-satisfaction lift after 60 days (in-app survey)
- % of users who report meaningful progress on at least one identity goal at Day 60

---

## 9. Out-of-Scope (v1)

To stay focused, v1 explicitly does **not** include:
- Social features, friend leaderboards, public sharing
- Marketplace for coaches/courses
- Wearable integrations beyond basic step count
- Therapy or clinical mental-health features
- Voice-only mode
- Multi-device real-time sync beyond what Firestore gives for free
- Web app (mobile-first)

These are explicitly deferred, not abandoned.

---

## 10. Open Questions

1. **Premium gate.** Is the AI Coach freemium-capped (e.g., 10 messages/day free, unlimited paid) or fully premium-only? Initial hypothesis: cap free tier, charge for unlimited + advanced modes.
2. **iOS data parity.** Android lets us read screen time and app usage; iOS does not. How do we maintain feature parity? Option: ask the user to self-report on iOS, with a clear honesty pact.
3. **Coach hallucinations.** As context windows grow, the coach may misremember. Do we surface "I don't remember exactly — can you remind me?" rather than fabricate?
4. **Data export.** Privacy-conscious users will want to export and delete. v1 must ship with a clean delete-everything flow (already partially in the codebase).
5. **Notification fatigue.** With routines, habits, goals, and the coach all able to ping, we need a unified notification budget per user per day.

---

## 11. Closing Note

Optivus is not a productivity app. It's an attempt to build the *one place a person goes to come back to themselves* — and to give that person an AI that actually shows up for them. If we get the integration right, every other feature is downstream of that core promise.

*Plan. Execute. Become.*
