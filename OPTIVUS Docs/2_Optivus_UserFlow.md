# Optivus — Complete User Flow

**Document version:** 1.0
**Last updated:** April 2026
**Companion to:** *Optivus PRD v1.0*

This document walks through how a real user moves through every part of the Optivus app — from first install to a full day lived inside the system. Each flow lists entry points, the screens the user sees, the taps they make, the conditional branches the system handles, and the exit points.

### How to read the System mapping tables

Each user-facing flow section (1–10) ends with a **System mapping** table that connects the user-visible actions to the underlying engineering: the event emitted, the service that handles it, and the database collections written. Format:

`User action → Event → Service → DB write`

The event names match the canonical catalog in [Section 12](#12-event-system) — they are not invented per flow. Service names follow the contracts in `Optivus_ServiceContracts.md`. Where a service is **deferred to phase 2** (e.g. AI Coach per the PRD's Technical Constraints), it is marked `(phase 2)` and v1 falls back to the rule-based path noted in the same row.

This connects the narrative flow (what the user feels) to the system flow (what the code must do). Engineers and product designers should both be able to read the same row.

---

## Table of contents

1. [Onboarding flow](#1-onboarding-flow)
2. [Home screen flow](#2-home-screen-flow)
3. [Routine setup flow](#3-routine-setup-flow)
4. [Habit tracking flow](#4-habit-tracking-flow)
5. [AI Coach interaction flow](#5-ai-coach-interaction-flow)
6. [Daily usage flow](#6-daily-usage-flow)
7. [End-of-day flow](#7-end-of-day-flow)
8. [Tracker screen flow](#8-tracker-screen-flow)
9. [Goals screen flow](#9-goals-screen-flow)
10. [Profile screen flow](#10-profile-screen-flow)
11. [Notification & trigger system](#11-notification--trigger-system)
12. [Event system](#12-event-system)
13. [Strategic AI planning loop](#13-strategic-ai-planning-loop)
14. [Failure states & re-engagement](#14-failure-states--re-engagement)

---

## 1. Onboarding flow

**Goal:** Take a brand-new user from app install to a fully personalized AI-coached daily plan in under 8 minutes.

### Entry
- User taps the Optivus icon on their home screen for the first time.
- App boot: Firebase initializes → checks auth state → no logged-in user → router sends them to `/`.

### Step 1 — Welcome screen
**What the user sees**
- The Optivus logo on a glass plaque, animated bot avatar
- Heading: *Optivus*
- Tagline: **PLAN. EXECUTE. BECOME.**
- Glass preview card: *AI-Powered Coach — Optimizing your daily workflow*
- Primary button: **Get Started**
- Below: *"Already have an account? Log in"*

**What the user does**
- Tap **Get Started** → routes to `/signup`
- *(or)* Tap **Log in** → routes to `/login` (returning users skip the rest of onboarding)

### Step 2 — Sign up
- Fields: Full Name, Email, Password, Confirm Password
- The password field shows a live rule panel as the user types: 8+ chars, capital letter, number, special char — each rule turns green as it's met
- A live "Passwords match" indicator turns green when both passwords agree
- Tap **Create Account** → Firebase creates the user → spinner → auth state changes → router redirects to `/onboarding`

### Step 3 — Onboarding Page 0: Welcome
- Glass plaque with animated logo
- Headline: *Welcome to Optivus*
- Subtitle: *Your AI Life Operating System*
- Body: *"Seamlessly organize your tasks, goals, and health with an intelligence that adapts to you."*
- Top: liquid-glass page indicator (1 of 11 dots)
- Bottom: **Get Started** button → swipes to Page 1

### Step 4 — Onboarding Page 1: Pick focus areas
**Title:** *What do you want to improve?*

**What the user sees**
- 6 folder-tab category cards in a 2×3 grid: **Health · Career · Skill · Recovery · Growth · Focus**
- A 7th *Custom* card to add a new category
- "Select all" / "Deselect all" pill in the top-right
- Each selected card lights with its primary color and a checkmark badge

**What the user does**
- Tap any card to multi-select. Default: Health + Recovery.
- Tap **Save** in the top bar to persist selection (otherwise auto-saved on Next).
- Tap **Next** → Page 2

### Step 5 — Onboarding Page 2: Drop bad habits
**Title:** *Drop Bad Habits*

- 4 toggle rows: **Cigarettes · Doom Scrolling · Junk Food · Procrastination**
- Each row has a 3D glass orb icon and an iridescent liquid switch
- Below: **+ Add Custom Habit** button

User toggles whichever apply → **Next**

### Step 6 — Onboarding Page 3: Build good habits
**Title:** *Build Good Habits*

- 5 default habit cards: **Gym · Coding · Reading · Meditation · Journaling**
- Each card collapses when unselected and expands when selected to reveal a daily goal subtitle and a tri-color progress bar
- Multi-select

User picks habits → **Next**

### Step 7 — Onboarding Page 4: Long-term identity goals
**Title:** *Long-Term Identity Goals*

- 8 identity cards in a 2-column grid: **Financially Free · Strong Body · Become Disciplined · New Language · Start a Business · Inner Peace · Better Partner · Travel the World**
- 9th: *Custom*
- Multi-select; default Strong Body + Inner Peace

User picks identities → **Next**

### Step 8 — Onboarding Page 5: About You *(new — three sub-pages)*

This step is a single onboarding page that internally pages through three sub-screens.

**Sub-page 5a — Body basics**
- Date of birth (date picker, required)
- Gender: Female / Male / Non-binary / Prefer not to say (optional)
- Height: cm or ft+in toggle (required)
- Current weight: kg or lbs toggle (required)
- Target weight: optional
- Activity level: Sedentary / Lightly Active / Moderately Active / Very Active

When the user enters height + weight, a live BMI card slides up:

> *"Your BMI is 16.2 — you're underweight. Let's plan a gain, not a cut."*

This is the moment the user first feels the AI seeing them.

**Sub-page 5b — Lifestyle rhythm**
- Typical wake time
- Typical sleep time
- Daily water target (auto-suggested as `weight × 35 ml`, editable)
- Occupation status: Student / Working / Both / Looking / Other
- Country/timezone (auto-detected, editable)

**Sub-page 5c — Sensitive context (skippable)**
- Diet preference (None / Vegetarian / Vegan / Pescatarian / Halal / Kosher / Keto / Other)
- Allergies (free text)
- Health flags (checkboxes incl. eating-disorder history → silently disables calorie tracking app-wide)
- Currently in therapy / on medication

User taps **Next** at the bottom of sub-page 5c → Page 6

### Step 9 — Onboarding Page 6: Coach style
**Title:** *Pick how your coach should guide you*

- 6 folder-tab cards: **Supportive (blue) · Tough Love (red) · Analytical (teal) · Zen Master (purple) · Motivational (rose) · Friendly (gold)**
- Single-select

### Step 10 — Onboarding Page 7: Coach name
**Title:** *What should we call your coach?*

- Amber glass text input
- 5 horizontally-scrolling jelly-bean suggestion chips: **Dad · Maa · Sensei · Bro · Sir**
- Live preview card below shows: *"Good morning, Nairit. — Coach Bro"*

User types a name or taps a chip → **Next**

### Step 11 — Onboarding Page 8: Accountability
**Title:** *How should we handle slip-ups?*

- 3 cards stacked vertically: **Forgiving 🪶 · Strict 📋 · Ruthless 🔒**
- The selected card gets an animated pink-cyan gradient rim
- Single-select, default Strict

### Step 12 — Onboarding Page 9: Set fixed schedule
**Title:** *Set Your Fixed Schedule*

- A 24-hour vertical timeline
- Default seed blocks: Sleep, Classes, Work, Gym, Dinner, Leisure, End of Day
- Each block has tape handles (top and bottom) the user drags to resize
- "+" Add buttons sit between blocks; tapping one opens an Add Task dialog (name, start, end)
- Long-press any block → edit dialog

User drags handles to fit their real life → **Next**

### Step 13 — Onboarding Page 10: AI plan ready
**Title:** *Your AI Plan is Ready*

- 3 preview cards with iridescent gradient rims:
  - **Daily Routine** card with a mini timeline preview
  - **Top 3 Goals** card with checkmarked goal rows
  - **Habit Focus** card with two radial progress rings (Sleep, Fitness)
- Bottom: **Enter Optivus** button

User taps **Enter Optivus** → all onboarding data is saved to `/users/{uid}/onboarding/*` in Firestore → router redirects to `/home`.

### System mapping

| User action | Event | Service | DB write |
|---|---|---|---|
| Tap **Create Account** on signup | `user_signed_up` | AuthService | `users/{uid}` (Firebase Auth + Firestore profile stub) |
| Each onboarding page save (debounced) | — (state mutation only, no event) | OnboardingService | `users/{uid}/onboarding/{section}` |
| Tap **Enter Optivus** on Page 10 | `onboarding_completed` | OnboardingService → PlanGenerator → NotificationService | `users/{uid}/onboarding/*` finalized, `users/{uid}/identity_profile`, `users/{uid}/scheduled_notifications` armed for next 24h |

### Exit
The user is now on the Home tab with a fully personalized day plan, an Identity Profile that grounds the AI Coach, and notifications armed for the next 24 hours.

---

## 2. Home screen flow

**Goal:** Give the user a 5-second glanceable status of their day and a one-tap path into whichever flow they need.

### Entry
- App reopen with logged-in user
- Tab bar tap on **Home** (index 0)
- After completing onboarding

### What the user sees (top to bottom)

1. **Header card** (glass plaque, fixed at top)
   - Day label: *MONDAY, APR 25*
   - Greeting: *Good Morning, Nairit*
   - Notification bell with red dot indicator

2. **Today's Mission ring**
   - 160px animated dark-navy progress arc on a light track
   - Center: large percentage *(e.g. 75%)* + COMPLETE label
   - Below: 3 stat pills — **Tasks 7/10 · Focus 4.5h · Cal 320**

3. **Habit Check-in row**
   - Horizontal scroll of 5 glass-orb pills: 💧 Hydrate · 🧘 Meditate · 🌿 Skincare · 📖 Read · 🏃 Run
   - "View All" pill on the right

4. **Streak Summary** (left column)
   - 🔥 *12 Day Streak* with a +2 badge
   - ⏱️ *45h Focus Time* card

5. **Plan by Date** (right column)
   - Mini inline calendar with month nav arrows
   - Event dots under days that have scheduled blocks
   - Today's date is highlighted in dark navy

6. **Your Recurring Routines**
   - 🌿 *Skin Care* — Vitamin C, Face Wash, etc.
   - 🎓 *Class Routine* — 3 Classes Scheduled
   - 🍽️ *Eating Routine* — 4 Meals Planned

### Common interactions and where they go

| User taps | What happens |
|---|---|
| Notification bell | Opens notification list |
| A habit pill | Quick-action sheet rises with amount/quantity → user logs → ring updates |
| Streak card | Expands into a streak history view with a heatmap calendar |
| A day in the calendar | Switches to the Routine tab on that date |
| Skin Care row | Switches to Routine tab with `skinCare` filter pre-applied |
| Class Routine row | Switches to Routine tab with `classes` filter pre-applied |
| Eating Routine row | Switches to Routine tab with `eating` filter pre-applied |
| A tab in the bottom bar | Switches tabs with the liquid pill stretching across |
| Drag the bottom-tab pill | Pill follows finger across tabs with haptic ticks at each boundary |

### System mapping

| User action | Event | Service | DB write |
|---|---|---|---|
| Open Home tab (first action of the day) | `day_started` | DailyPlanner | `users/{uid}/days/{date}` (priority queue computed) |
| Tap a habit pill, log amount | `good_habit_logged` | HabitService → StreakService → MissionRing | `users/{uid}/habit_logs`, `users/{uid}/streaks/{habit_id}` |
| Tap a streak card | — (read-only navigation) | — | none |
| Tap a calendar day | — (navigation only) | — | none |
| Tap notification bell | — (navigation only) | — | none |

### Exit
The Home tab is a hub — every interaction routes the user into one of the deeper flows (Routine, Habit, Coach, Goals, Profile).

---

## 3. Routine setup flow

**Goal:** Configure the four foundational routines (skin care, classes, eating, fixed schedule) so the timeline reflects the user's real life.

### Entry points
- **From Home tab** — tap a row in *Your Recurring Routines*
- **From Routine tab** — tap the settings gear → *Routine Settings* sheet → tap a routine row
- **From Profile tab** — tap *Routine Setting* → opens the full Routine Settings screen

### Routine tab (the hub before any setup)
- Top header: filter pill (currently *All*), AI toggle, Tasks toggle, Settings gear
- Title: *Today's Flow* (or *This Week's Flow* / *This Month's Flow* in zoomed views)
- Body: vertical timeline of today's blocks with rail dots and a NOW indicator
- If the active filter has no setup yet → a **glass setup popup** floats over the timeline:
  - 🌿 *No skin care today — Set up your skin care routine and it will appear here automatically* with a **Set up Skin Care** button

User taps the setup button → opens the dedicated setup screen.

### 3.1 Skin Care setup
1. **SkinCareSetupScreen** opens with a slide animation.
2. **7 day droplets** at the top (MON–SUN); the active day glows in mint green.
3. **Glass header**: *Set Your Fixed Skincare Routine*.
4. **Card body** with title *Your Fixed Skincare Schedule* and a subtitle.
5. **24-hour timeline** (6 AM start) with default blocks: Morning Ritual (7 AM), Evening Recovery (8 PM), Self-Care: Mask (9:30 PM).
6. The user can:
   - **Drag tape handles** at the top/bottom of any block to resize (minimum 36 min)
   - **Tap a block** → edit dialog opens with: Block Name (e.g. *Morning Ritual*), Start, End, and a Steps section with chips like *Cleanse · Vitamin C · SPF*. New steps are added via a text input + green plus button.
   - **Tap a "+" Add button** between blocks to create a new one
   - Switch days via the droplets; each day has its own routine
7. Tap the check icon (top right) → marks skin-care set up, saves to Firestore, returns to the Routine tab. The popup is now gone.

### 3.2 Eating setup
Same shape, with meal-specific fields:
- 7 day droplets, amber/orange themed
- Glass header: *Set Your Daily Eating Routine*
- Default blocks: Breakfast 8 AM (🥣 Oatmeal), Lunch 1 PM (🥗 Salad), Snack 5 PM (🍎 Apple), Dinner 8:30 PM (🍣 Salmon)
- Edit dialog: Meal Name, Food Detail, Icon (emoji), Start, End

### 3.3 Class setup
- 7 day droplets, blue themed
- Glass header: *Set Your Weekly Class Schedule*
- Default classes for current weekday: *Data Structures, Operating Systems*
- Edit dialog: Subject, Room, Professor, Start time, End time, plus a **Delete** action

### 3.4 Fixed Schedule setup
- **No day droplets** (fixed schedule applies every day)
- Glass header: *Set Your Fixed Schedule*
- 24-hour timeline with default blocks: Sleep, Classes, Work, Gym, Dinner, Leisure, End of Day
- Each block is full-color or mini-styled depending on duration (≤1h becomes a mini pill)
- Tap a block → edit dialog with name, start, end, and Delete

### 3.5 Long-term goals
Long-term identity goals are captured in onboarding (Step 7 above) but can be edited any time from the Goals tab — tap a goal card → edit panel slides up.

### System mapping

| User action | Event | Service | DB write |
|---|---|---|---|
| Save Skin Care plan | — (state mutation; emits `task_scheduled` for each window) | RoutineService → NotificationService | `users/{uid}/routines/skin_care`, `users/{uid}/scheduled_notifications` |
| Save Eating plan | — (emits `task_scheduled` per meal window) | RoutineService → NotificationService | `users/{uid}/routines/eating`, `users/{uid}/scheduled_notifications` |
| Save Class schedule | — (emits `task_scheduled` per class) | RoutineService → NotificationService | `users/{uid}/routines/classes`, `users/{uid}/scheduled_notifications` |
| Save Fixed Schedule blocks | — (emits `task_scheduled` per block) | RoutineService → NotificationService | `users/{uid}/routines/fixed_schedule`, `users/{uid}/scheduled_notifications` |
| Edit / delete a block | — (state mutation; cancels old `scheduled_notifications`) | RoutineService → NotificationService | corresponding `routines/*` doc updated, stale notifications cancelled |

### Exit
After any setup screen completes, the user lands back on the Routine tab. The previously-empty filter now shows real blocks on the timeline.

---

## 4. Habit tracking flow

**Goal:** Make logging effortless. Good habits in, bad habits out, streaks visible.

### Entry points
- **Home tab** — tap a habit pill in the *Habit Check-in* row
- **Tracker tab** — full dashboard of all habit metrics
- **Routine tab** — subtask checkboxes inside an active routine block
- **AI coach** — natural language: *"I drank 500ml just now"* → coach logs it for the user
- **Notification** — tap a "Log your water" reminder → deep-links to logger

### Tracker tab structure
- Header: *YOUR PROGRESS*
- Cards (one per metric):
  - 💧 *Water Intake* — `1.5L / 2L`, blue progress bar
  - 🚶 *Steps* — `6,000 / 10K`, mint progress bar
  - 🌙 *Sleep* — `6h 30m`, purple progress bar
- Bad habits section (further down):
  - 🚭 *Cigarettes* — count today, money saved, days clean
  - 📱 *Doom Scrolling* — hours today, top app
  - 🍔 *Junk Food* — slips this week
- Tap any card → expanded detail with weekly chart, streak history, and trigger heatmap

### 4.1 Logging a good habit (water example)
1. User taps the 💧 *Hydrate* pill on Home (or the Water card on Tracker).
2. A bottom sheet rises: *"How much did you drink?"* with quick-action buttons: **+250ml · +500ml · +1L · Custom**
3. User taps **+500ml**.
4. Haptic tick, count animates from 1.5L → 2.0L, ring fills to 100%.
5. Confetti micro-animation; if this hits the daily target, the streak counter increments by 1 with a small badge.
6. Sheet auto-dismisses.

### 4.2 Logging a bad habit slip (cigarette example)
1. User opens Tracker → taps 🚭 *Cigarettes* card → **Log slip**.
2. Sheet slides up, framed gently:
   *"Logging a slip — that's okay. Want to tell us what triggered it?"*
3. Trigger picker (chips): **Stress · Boredom · Social · After meal · Other**
4. User taps Stress → tap **Log**.
5. Slip count increments from 0 → 1, money-saved counter for today pauses, streak break is logged.
6. The AI coach receives a `slip_logged` event in real time. A soft notification appears 30–60 seconds later:
   *"Heard. You're 4 days from your previous record. Want to walk for 5 min?"*
7. Tap the notification → opens Coach with the cigarette slip already in context.

### 4.3 Streak management
- Each habit (good or bad) has its own streak counter
- The accountability setting decides what happens on a miss:
  - **Forgiving** — no streak break; AI says *"Tomorrow's a new day."*
  - **Strict** — streak resets; AI asks the user to explain why before rescheduling
  - **Ruthless** — streak resets; AI is sharp and direct, but never insulting
- Tap a streak card → see a calendar heatmap with hot (consistent) and cold (missed) days

### System mapping

| User action | Event | Service | DB write |
|---|---|---|---|
| Log a good habit (water +500ml, etc.) | `good_habit_logged` | HabitService → StreakService → MissionRing | `users/{uid}/habit_logs`, `users/{uid}/streaks/{habit_id}` |
| Log a bad-habit slip (cigarette, scroll) | `bad_habit_slip_logged` | HabitService → StreakService → MoneySavedCounter; **(phase 2: AI Coach)** v1: NotificationService schedules a P4 nudge from rule fallback | `users/{uid}/habit_logs`, `users/{uid}/streaks/{habit_id}`, `users/{uid}/scheduled_notifications` |
| 3+ slips in 30 min on same habit | `slip_streak_detected` | StreakService; **(phase 2: AI Coach coalesced response)** v1: single rule-based notification | `users/{uid}/streaks/{habit_id}` updated, prior slip notifications coalesced |
| Tap a streak card to view history | — (read-only) | — | none |

### Exit
After a log, the user is returned to whichever screen they came from, with the relevant counter and streak updated app-wide (Home ring, Tracker card, Profile stats all reflect the change).

---

## 5. AI Coach interaction flow

**Goal:** Give the user a context-aware AI they can talk to anytime, that also nudges them proactively across the app.

### Entry points
- **Coach tab** (index 3) — open chat
- **Routine tab** — green AI toggle in the top-right opens an in-context AI panel over the timeline
- **Notifications** — tapping a coach-sent notification deep-links straight to the relevant turn in the Coach tab
- **Tracker** — *"Talk to Coach"* button on a slip detail screen

### 5.1 First entry into Coach tab
**Header**
- Coach avatar (purple bot orb)
- Coach name (e.g. *Bro*) — pulled from onboarding
- Status row: green dot · *Online · Here for you*
- More-options icon on the right

**Body**
- Chat history with iOS-style speech bubbles
- User bubbles right-aligned with a tail bottom-right
- Coach bubbles left-aligned with a tail bottom-left
- Heavy 3D liquid-glass treatment on each bubble (refractive edge, top specular highlight)

**Input bar** (floats above the tab bar, lifts with the keyboard)
- Glass pill with morphing wave animation
- Left: **+** icon (attach photo / log a slip / share screenshot)
- Center: text field — *"Type a message..."*
- Right: 🎤 mic icon when empty; gradient send button when text is present

### 5.2 Sending a message
1. User taps the input → keyboard rises → input pill animates above keyboard.
2. User types: *"i smoked because i felt stressed"*.
3. Mic icon flips to a purple-to-cyan gradient send button.
4. User taps send.
5. The user message appears as a right-aligned bubble.
6. A typing indicator (3 bouncing dots inside a coach bubble) appears.
7. The Gemini chat session — initialized with a system prompt grounded in the user's onboarding profile, current goals, and habits — receives the message.
8. The coach reply streams in as a new left-aligned bubble.
9. List auto-scrolls to bottom; user can drag up to read history.

### 5.3 Routine tab — AI panel flow
1. User toggles the green **AI** switch in the Routine tab header.
2. A dimming overlay slides in over the timeline; an **AI panel** rises from the bottom (380ms slide).
3. Panel header: animated AI avatar (purple-cyan gradient), *AI Coach*, *3 suggestions for today*, refresh icon.
4. Panel auto-fetches suggestions on open. Loading state: 2 shimmer cards.
5. Suggestions arrive as 240px-wide horizontal cards:
   - Emoji + action chip (*+ Add* / *− Remove*)
   - Title: *"Add 20-min Walk at 3:00 PM"*
   - Reason: *"You have a free gap between 3–4 PM. A walk boosts afternoon focus."*
   - Buttons: **Accept · Dismiss**
6. **Accept** → task is added to today's timeline, suggestion card animates out.
7. **Dismiss** → suggestion is removed but logged for AI learning.
8. Below the suggestions, a free-text bar: *"Ask AI… e.g. 'add yoga at 7am'"*. The user can type natural-language commands → AI parses and returns new suggestion cards.
9. Tapping the dim area or toggling the AI switch off closes the panel.

### 5.4 Topic modes
Three chat modes accessible by long-pressing the coach avatar in the Coach tab header:
- **Recovery Coach** — softer tone, focused on cravings/triggers, no productivity push
- **Study Coach** — focused on academic execution, deep work, exam prep
- **Calm Coach** — for late-night spirals, breathing exercises, grounding

Each mode swaps the system prompt; the conversation history is preserved across modes so the user can switch fluidly mid-conversation.

### 5.5 Safety branches
| Trigger phrase | What happens |
|---|---|
| User mentions self-harm / suicide | Tone shifts immediately to gentle. Crisis resources offered. AI never moralizes. |
| Medical / legal / financial advice request | AI declines specifically, names the relevant professional, offers to help frame questions for them. |
| Severe mental-health crisis flag from health-flag onboarding | Coach uses softer voice by default and proactively offers professional support after recurring distress signals. |

### System mapping

> **Phase note:** the AI Coach as described in this section is a phase-2 feature per the PRD's Technical Constraints. v1 ships with the chat UI behind a "Coming soon" gate — the events below are reserved for the catalog but not emitted in MVP. Routine-tab AI suggestions (5.3) and safety branches (5.5) are also deferred.

| User action | Event | Service | DB write |
|---|---|---|---|
| User sends a chat message | `coach_message_sent` | **(phase 2)** CoachService → GeminiService | `users/{uid}/coach_chats/{thread_id}/turns` |
| AI replies | `coach_replied` | **(phase 2)** GeminiService → CoachService | same `coach_chats` thread, plus `users/{uid}/ai_memory_writes` |
| AI generates suggestion cards (Routine tab) | `suggestion_generated` | **(phase 2)** PlanGenerator → SuggestionService | `users/{uid}/suggestions` |
| User taps **Accept** on a suggestion | `suggestion_accepted` | **(phase 2)** SuggestionService → RoutineService → NotificationService | `users/{uid}/routines/*`, `users/{uid}/scheduled_notifications`, suggestion marked accepted |
| User taps **Dismiss** | `suggestion_dismissed` | **(phase 2)** SuggestionService (logs reinforcement signal) | suggestion marked dismissed |

### Exit
- User backs out → Coach tab remains open with full chat history preserved
- Tapping any other tab leaves the chat exactly as it is for next time

---

## 6. Daily usage flow

**Goal:** Show how a real day flows through the app — alarms, taps, logs, micro-decisions.

This walkthrough uses **Nairit** (the persona from the PRD) on a regular Monday.

### 6.1 — 6:55 AM — Pre-wake background state
- Phone is in Do Not Disturb mode
- Optivus has armed a **custom alarm** for the wake-up task at 7:00 AM (chosen during onboarding; opted in for this task)
- Other notifications are still queued silently

### 6.2 — 7:00 AM — Wake-up alarm
- A full-screen alarm UI takes over the lock screen
- Coach voice plays in the user's chosen Tough Love style: *"Bro. It's 7. You said this matters. Get up."*
- Three buttons:
  - **Start the Day** (large, primary)
  - **Snooze 10 min — pick a reason** (asks for tired / sick / other before snoozing)
  - **Skip with reason**
- User taps **Start the Day**
- Wake-up task moves from Scheduled → Started
- App opens to Home tab

### 6.3 — 7:00 – 7:30 AM — Morning routine
- Home tab Mission ring shows 0% (fresh day)
- 7:25 AM gentle nudge: *"Skin care in 5 minutes — tap to start"*
- User opens Routine tab → sees the 7:30 AM Skincare block highlighted
- 7:30 AM, user taps **I'm starting this** on the block
- Block animates into Active state with a live elapsed-time chip; it pins to the top of the screen
- Subtask checkboxes appear: ☐ Cleanse · ☐ Vitamin C · ☐ SPF
- User checks each one as they go
- When the last one is checked, the block auto-completes (planned 15m, actual 14m → captured)
- Mission ring on Home jumps from 0% to 8%

### 6.4 — 9:00 AM — Class block
- Class block fires (or geofences in if location permission granted)
- User taps **Start** on the *Data Structures* class block
- Block stays Active for 1h
- 10:00 AM user taps **Mark as complete** as they leave the room

### 6.5 — 11:30 AM — Bad-habit slip
- User feels stressed, smokes a cigarette
- Opens Tracker → 🚭 *Cigarettes* → **Log slip** → Trigger: **Stress**
- 30 seconds later, a coach notification arrives: *"Heard. Stress at 11:30 again — third Monday in a row. Walk for 90 seconds?"*
- User taps the notification → opens Coach tab with the slip already in context
- Brief conversation; user feels heard; closes the app

### 6.6 — 1:00 PM — Lunch
- Eating routine block fires its gentle nudge
- User taps **Start** on the lunch block
- Eats lunch
- Taps **Mark as complete** → app prompts *"What did you eat?"* with quick-add buttons
- User logs lunch
- AI computes calories: 380 cal — flags below target — adds a 4 PM snack suggestion to today's timeline

### 6.7 — 5:00 PM — Custom gym alarm
- Full-screen alarm fires (gym was opted in for custom alarm during onboarding)
- Coach voice: *"Bro. Gym. Now."*
- User taps **Start** → gym task pinned at the top of all screens with a live timer
- User goes to gym
- Returns to phone after 82 min
- Taps **Mark as complete**
- Actual duration captured (planned 60m, actual 82m). The AI logs this and on Day 2 quietly bumps the planned gym slot to 80m so the rest of the day stops slipping.

### 6.8 — 6:00 PM – 9:30 PM — Evening
- Dinner block fires → user starts → eats → completes
- Hydration habit: user has tapped 💧 several times throughout the day; current count is 2.0L (target met)
- Around 8 PM, AI checks in via notification: *"Want to journal for 10 min before night skincare?"* — user dismisses

### 6.9 — 9:50 PM — Night skincare alarm
- Gentle chime nudge
- User taps **Start** on the night skincare block
- Subtasks: ☐ Cleanse · ☐ Vitamin C · ☐ Night Cream · ☐ Lip balm
- All checked → auto-complete

### 6.10 — 10:00 PM — Wind-down notification
- *"Phone away in 15 min. Want to journal?"*
- User can tap to open journaling, or ignore
- (User ignores it tonight and opens Instagram)

### System mapping

This flow is a composite — most actions reuse mappings from earlier flows. Listed below in narrative order.

| User action | Event | Service | DB write |
|---|---|---|---|
| 6.2 Wake-up alarm tapped | `notification_tapped` then `task_started` | NotificationService → TaskService | `users/{uid}/notifications/{id}` (tapped state), `users/{uid}/tasks/{morning_routine_id}` |
| 6.3 Each subtask checkbox | — (state mutation, granular) | TaskService | task subtasks updated incrementally |
| 6.3 All subtasks done | `task_completed` | TaskService → StreakService → MissionRing → IdentityProfile | `tasks/*`, `streaks/*`, `mission_ring`, `identity_profile` |
| 6.4 Class block auto-starts | `task_started` | TaskService (auto-start by scheduler) | `tasks/{class_id}` actual_start set |
| 6.5 Bad habit slip | `bad_habit_slip_logged` | HabitService → StreakService (see Section 4 system mapping) | `habit_logs`, `streaks` |
| 6.7 Custom alarm fires & user starts gym | `notification_tapped` → `task_started` | NotificationService → TaskService | as above |
| 6.10 User ignores wind-down notif | `notification_dismissed` | NotificationService (logs for learning loop) | `notifications/{id}` dismissed state |

### Exit
The day flows continuously into the End-of-Day flow below.

---

## 7. End-of-day flow

**Goal:** Close the day with an honest summary, learn from it, set up tomorrow.

### 7.1 — 10:30 PM — Sleep block scheduled
- If the user taps **Start** on the sleep block, the app silently activates a do-not-disturb mode and shows a *"Goodnight"* screen with the next morning's wake time
- If the user **doesn't** tap Start by 11:00 PM, an active alert fires: *"Your sleep block is hanging — start or push?"*
- If the user is still on Instagram by 11:30 PM, the block is auto-marked **Abandoned** and the data point is logged for the coach

### 7.2 — Coach end-of-day summary
At a configurable time (default 30 min after the planned sleep), the coach posts a single summary message in the Coach tab and pushes a notification:

> "Bro. Here's how today landed:
> ✅ Skincare 4/4
> ✅ Gym (planned 60m, you did 82m — savage)
> ✅ Study 1h
> ❌ Smoking 2 (stress at 11:30 — let's plan for that tomorrow)
> ❌ 4h Instagram tonight
> Money saved this week: ₹140
> Strong Body identity: 64% (+2% today)
> Top Student identity: 41%
> Tomorrow's first task: Wake 7 AM — phone in another room?"

User can:
- Tap **Yes, lock my phone away tomorrow** → adds a "phone in another room before 7 AM" task to tomorrow's timeline
- Tap **Talk to me about the smoking trigger** → opens free-form chat with the slip in context
- Swipe away to dismiss

### 7.3 — Tracker review (optional)
User opens Tracker → today's full picture:

| Metric | Result |
|---|---|
| 💧 Water | 2.0 L / 2 L ✅ |
| 🚶 Steps | 8,432 / 10K |
| 🌙 Sleep | (pending — calculated on wake) |
| 🚭 Cigarettes | 2 (down from baseline 4–5) |
| 📱 Doom Scrolling | 4h 11m — top app: Instagram |
| 💰 Money saved today | ₹20 |
| 💰 Money saved this week | ₹140 |

### 7.4 — Streak update
- 💧 Hydration streak: 17 → 18 days
- 🚭 No-smoking streak: broken at 6 days → reset to 0 (Strict accountability)
- 🌿 Skincare streak: 9 → 10 days
- 💪 Gym streak: 3 → 4 days

The Profile tab and Home Streak Summary cards both reflect the new numbers immediately.

### 7.5 — Tomorrow setup
- User taps **Plan tomorrow** in the coach summary or in the Routine tab tomorrow-arrow
- Tomorrow's view opens with the day-of-week template already pre-populated
- AI shows the proposed tweaks at the top in a glass card:
  - *"Phone in another room before 7 AM — added"*
  - *"Gym block extended to 80 min based on your real durations"*
  - *"Pre-emptive walk at 11:25 AM to address Monday-stress trigger"*
- Buttons: **Approve all · Approve individually · Reject**

User taps **Approve all** → tomorrow's timeline is ready before bed.

### 7.6 — Sleep
- Phone enters sleep mode
- All notifications muted except wake alarm
- Wake alarm armed
- App enters background

### System mapping

| User action | Event | Service | DB write |
|---|---|---|---|
| Sleep block reached OR midnight cutoff | `day_closed` | DayCloseService → StreakService → IdentityProfile → SummaryGenerator | `users/{uid}/days/{date}` (final state), `streaks/*`, `identity_profile`, `users/{uid}/summaries/{date}` |
| Coach end-of-day summary opens | `coach_replied` (proactive) | **(phase 2)** CoachService; v1: rule-based template message inserted by NotificationService | `notifications/{id}` for v1; `coach_chats/*` for phase 2 |
| User adjusts streak setting from summary | — (state mutation) | StreakService | `users/{uid}/streaks/{habit_id}.accountability_mode` |
| User approves AI-suggested tweaks for tomorrow | `suggestion_accepted` | **(phase 2)** SuggestionService → PlanGenerator → RoutineService | `users/{uid}/plans/{tomorrow_date}`, `routines/*` updated |
| Identity Profile recomputes after `day_closed` | `identity_progress_changed` | IdentityProfile | `users/{uid}/identity_profile` (per-identity %) |

### Exit
The user wakes up the next morning and re-enters the **Daily usage flow** at Step 6.2. The system has already adjusted based on what *actually* happened today, not just what was planned. Over weeks, the loop tightens, the coach gets sharper, and the user moves measurably closer to the identity they chose during onboarding.

---

## 8. Tracker screen flow

**Goal:** Make logging effortless, make patterns visible, and turn every habit into a screen the user *wants* to open. Section 4 covered the *generic logging path*; this section is the screen itself — the dashboard, the per-habit detail screens, and how the AI's interpretation lives inside them.

> **Build status:** This screen is incomplete in the current codebase. This section is the design spec.

### 8.1 Tracker home

#### Entry points
- Bottom tab bar — **Tracker** (index 2)
- Home tab — tap a habit pill in *Habit Check-in*
- AI coach message — *"Open Tracker → Cigarettes"* deep-link
- Notification — tap *"Log your water"* reminder

#### What the user sees (top to bottom)

1. **Header**
   - Date: *MONDAY, APR 25*
   - Toggle pill: **Today · Week · Month** (right-aligned)
   - Filter chip: **All · Good · Bad · Phone** (horizontally scrollable)

2. **Mission ring (compact)**
   - 80px ring + label: *Today's Mission · 75%*
   - Tap → expands into a breakdown of which habits/blocks contributed

3. **Good habits — carousel of cards** (horizontal scroll, 280px wide each)

   | Card | Visible content |
   |---|---|
   | 💧 *Hydration* | `1.5 L / 2 L`, blue progress bar, 🔥 18-day streak chip |
   | 🚶 *Steps* | `6,000 / 10,000`, mint progress bar |
   | 🌙 *Sleep* | `7 h 12 m`, purple progress bar (computed from previous night's sleep block) |
   | 🏋 *Gym* | `1 / 1 today`, ✅ done, 4-day streak |
   | 📖 *Reading* | `12 / 30 min`, amber progress bar |
   | ➕ *Add habit* | Glass plus tile |

4. **Bad habits — carousel** (same shape, red/charcoal tinted)

   | Card | Visible content |
   |---|---|
   | 🚭 *Cigarettes* | `2 today` (baseline 4–5), 💰 ₹140 saved this week |
   | 📱 *Doom Scrolling* | `4 h 11 m today`, top app: Instagram |
   | 🍔 *Junk Food* | `1 slip this week` |
   | ➕ *Add habit* | Glass plus tile |

5. **Phone Behavior card** *(Android only — see 8.4)*
   - Total screen time today, top 3 apps with bars, unlock count
   - Tap → expanded phone-usage detail

6. **Weekly trend strip** (collapsible)
   - 7-day mini sparklines for top 3 active habits
   - Tap → opens that habit's weekly detail

7. **AI insight card** (only appears when the AI has something *non-obvious* to say — see Section 13 strategic AI rules)
   - Glass plaque with coach avatar
   - Single sentence: *"Your hydration is 23% better on gym days. Want to lock that pattern in?"*
   - Buttons: **Tell me more** (opens Coach) · **Dismiss**

#### Interaction map

| User taps | What happens |
|---|---|
| Today/Week/Month toggle | All cards re-bind to that range; numbers animate |
| A good-habit card | Pushes habit detail screen (8.2) |
| A bad-habit card | Pushes bad-habit detail screen (8.3) |
| Phone Behavior card | Pushes phone usage screen (8.4) |
| Trend sparkline | Pushes habit detail with Week tab pre-selected |
| AI insight card | Either opens Coach with context or dismisses + emits `suggestion_dismissed` |
| **+ Add habit** | Opens habit picker sheet (8.5) |
| Long-press any card | Quick menu: Log · Edit goal · Pause · Archive |

#### Empty / loading / offline states
- **First-time empty (no habits chosen yet)** — Glass card prompting *"Pick your habits in Profile → About You"* with a button
- **Loading** — Shimmer placeholders in card shape
- **Offline** — Cards render from local cache with a small *"Synced 2 min ago"* footer

### 8.2 Good-habit detail screen — Hydration as the canonical example

#### Layout (top to bottom)

1. **Hero**
   - 200px circular progress ring; center: `1.5 L / 2 L`, *75%*
   - Streak chip: 🔥 18-day streak with a +1 badge if today's target hits
   - Trend chip: ↗ +12% vs last week

2. **Quick log row** — 4 jelly-bean buttons: **+250 ml · +500 ml · +1 L · Custom**
   - Custom opens a numpad sheet
   - Each tap emits `good_habit_logged`, fires haptic, animates ring fill, dismisses sheet

3. **Today's log** — chronological list of log entries
   - Each row: time, amount, source (manual / AI nudge / notification tap)
   - Swipe left on a row → **Delete** (with confirm)

4. **Weekly chart** — 7-day bar chart, today highlighted
   - Tap a bar → snapshot of that day

5. **Streak heatmap** — 12-week grid, hot days vs cold days
   - Hot = target hit, cold = missed, gray = before habit was added

6. **AI insight** *(if relevant)* — *"Your hydration drops on Sundays — 1.1 L average. Want a Sunday-specific reminder?"*
   - **Yes, add reminder** → emits `suggestion_accepted`, schedules notification
   - **Not now** → emits `suggestion_dismissed`

7. **Settings row** (icons at the bottom)
   - 🎯 *Edit goal* — change `2 L` to any value
   - 🔔 *Reminders* — schedule push reminders at specific times
   - 💬 *Talk to coach about hydration* — opens Coach with this habit pinned
   - ⏸ *Pause habit* — stops tracking, preserves history
   - 🗑 *Archive habit* — removes from Tracker home, keeps history

#### Edge cases
- User logs more than goal → ring locks at 100% with a small ✨ overage chip showing the surplus
- User logs at 11:58 PM → log attaches to today; if they log at 12:01 AM and yesterday wasn't met, AI offers *"Move this log to yesterday?"* once

### 8.3 Bad-habit detail screen — Cigarettes as the canonical example

The shape mirrors 8.2 but the framing is opposite — the goal is to *reduce*, not increase, and the emotional register is non-shaming.

#### Layout

1. **Hero**
   - Big number: *2* (today's count) with subtitle *"baseline: 4–5"*
   - Money saved card: 💰 *₹140 this week · ₹2,400 this month* (auto-computed from baseline × per-unit cost the user set)
   - Days clean (only if streak > 0): *"6 days clean"*

2. **Log slip button** — single large button, gentle gray, not red
   - Tap → trigger picker sheet rises (Stress · Boredom · Social · After meal · Other)
   - Picker is *optional* — user can tap **Skip** to log without a trigger
   - Confirms with non-shaming language: *"Logged. Thank you for being honest."*

3. **Today's log** — same shape as 8.2, with trigger tags visible

4. **Trigger heatmap** — 7×24 grid (day × hour), darker cells = more slips at that time
   - This is the AI's diagnostic surface — patterns become obvious (Mondays at 11:30)
   - Tap a cell → shows the actual logs from that slot

5. **Weekly chart** — bars going *down* feel good; trend chip shows ↓ -38% vs last week

6. **AI insight** *(usually present here)* — *"Your stress slips cluster between 11–noon on Mondays. Want a 10:55 walk reminder?"*
   - Buttons: **Add it** / **Not now**

7. **Talk to coach about this** — prominent button (more important here than on good-habit screen because slips often need conversation)

8. **Settings row**
   - 🎯 *Set baseline* — what you smoked before starting (used for money-saved math)
   - 💰 *Cost per unit* — defaults to user's region's average (₹15 in India)
   - 🔔 *Recovery alarms* — schedule pre-emptive nudges at known trigger times
   - 💬 *Coach mode for this* — switch this habit to Recovery Coach mode by default
   - ⏸ / 🗑 — Pause / Archive

#### Critical behavior
- **Never** show a red "you slipped" banner. The framing is *"You logged honestly — that's the win today."*
- If 3 slips in 30 min, suppress per-slip notifications and emit `slip_streak_detected` (Section 12)
- If user has *eating disorder* health flag from About You, this screen does NOT show calorie counts, weight implications, or before/after framing for any food-related habit
- For cigarettes/alcohol/etc., money saved is **never** displayed during a relapse week (AI hides it temporarily so the contrast doesn't shame)

### 8.4 Per-tracker designs

Sections 8.2 and 8.3 describe the *generic* good-habit and bad-habit detail screens — the shared shell. This section describes what's *unique* about each specific tracker: the fields, log paths, AI patterns, and safety behavior that don't apply to every habit. These aren't separate screens; they're variants of the same detail screen, configured by the habit's type.

#### 8.4.1 🚭 Smoking tracker (cigarettes / vape / alcohol / weed)

The same screen handles all addictive substances — only labels and cost defaults change.

- **Trigger picker:** Stress · Boredom · Social · After meal · Craving · Other
- **Money-saved math:** `(baseline_per_day − actual_today) × cost_per_unit`. Cost defaults by region (₹15 / cigarette in India, $0.50 in US), editable in the habit settings.
- **Days clean counter:** explicit "0 logged today" days. Tappable → shows the streak heatmap.
- **Health milestones** auto-displayed by days clean (each unlocks as the user reaches it):
  - 20 minutes → heart rate normalizes
  - 12 hours → carbon monoxide drops to normal
  - 24 hours → heart-attack risk starts to drop
  - 72 hours → lung function improves, breathing eases
  - 1 week → smell and taste return
  - 2 weeks → circulation improves
  - 1 month → lungs start to clear
  - 1 year → heart-disease risk halves
- **Recovery alarms:** pre-emptive nudges scheduled at known trigger times (Section 13's planner reads the trigger heatmap and schedules a P3 nudge 5 min before high-risk slots — e.g., 11:25 AM walk reminder for a Monday-stress smoker).
- **Talk to coach about this** is the most-used button on this screen — surfaced more prominently than on other bad-habit screens.

#### 8.4.2 📱 Screen time / doom-scrolling tracker

The most data-rich tracker because the OS exposes raw usage data.

**Source:**
- **Android:** `UsageStatsManager` + `PACKAGE_USAGE_STATS` permission. Auto-pulled every 30 min while app is foreground, and once at `day_closed`.
- **iOS:** Screen Time API access is limited; we ask the user to enable Family Controls if they want auto-pull. Fallback is a 1-tap nightly self-report picker: *"Roughly how long were you on social media today? 0–1h · 1–2h · 2–4h · 4h+"*

**Layout (specific to this tracker):**
- Hero: today's total screen time (e.g., *4h 11m*) with a comparison bar to weekly average
- App breakdown: top 5 apps with time + per-app unlock count
- Total unlock count (e.g., *147 unlocks today*)
- Hourly distribution chart — when did the scrolling happen (peaks at lunch, post-class, late night)?
- *"Apps marked as drains"* — user-flagged apps. Each can have its own daily cap (Instagram 30 min, TikTok 0 min)

**Cap-violation flow** (when a flagged app crosses its cap):
1. First crossing of the day: gentle in-app toast + push: *"You've hit your Instagram cap. Want to lock it for 1 hour?"*
2. User can tap **Lock 1 hr** (system DnD-style mute on notifications from that app, not a hard block) or **Dismiss**
3. Second crossing same day: AI offers a Coach conversation instead of another lock prompt

Optivus does **not** hard-block apps. The discipline is the user's; the app is awareness, not enforcement.

**AI patterns:**
- Correlates scrolling spikes with stress events (slips logged, abandoned tasks, late nights)
- *"Your scrolling jumps 2× on days you skip gym. Pattern, not coincidence."*
- Detects *unlock without action* — phone unlocked, no app opened > 5s, then re-locked. Above ~80/day = anxiety pattern, AI surfaces it.

#### 8.4.3 🍔 Junk food tracker

- **Quick-add chips:** 🍕 Pizza · 🍔 Burger · 🥤 Soda · 🍫 Sweets · 🍟 Fries · 🌯 Fast food · 🍿 Snacks · Other
- **Trigger picker:** Cravings · Stress · Social/eating out · Lazy (nothing prepped) · Tired · Other
- **Optional photo log** — snap the food for personal accountability. Photos are stored locally + Firestore-private; never shared, never seen by anyone else.
- **Cost tracker** — money spent on junk vs the healthy alternative the user planned. Money-saved counter applies if user replaces a junk meal with a planned one.
- **Days clean counter** — for streak users.
- **🚨 Critical safety:** if the **eating disorder** flag is set in About You, this tracker is replaced entirely with a **Mindful Eating** tracker:
  - No counts, no goals, no streaks
  - Single field per meal: *"How did this meal feel?"* — slider from "rushed/stressed" to "nourishing/calm"
  - Optional note
  - The framing is body-neutral; calories and weight are never mentioned

This swap happens silently on the backend — the user never sees a "you can't have this tracker" message; they just see Mindful Eating instead.

#### 8.4.4 ⏳ Procrastination tracker

The trickiest tracker because procrastination is a behavior pattern, not a discrete event. Two log paths run in parallel:

**A. Manual log:** User opens Tracker → Procrastination → **Log a procrastination**
- *"What did you put off?"* — picker of today's planned tasks + custom text option
- *"What did you do instead?"* — picker: 📱 Phone · 😴 Sleep · 🎮 Games · 📺 TV/streaming · 🍔 Food · 😶 Just sat there · Other
- *"How long did you avoid it?"* — quick chips: 15 min · 30 min · 1 hr · 2+ hr

**B. Auto-detect** (the more powerful path): the event log is mined for procrastination signals. Every task whose `actual_start − planned_start > 30 min` OR `task_abandoned` without a `task_started` is auto-logged as a procrastination instance, with the planned task and the time-of-day captured. The user sees these in the today's-log section and can dismiss any auto-log they disagree with (which itself becomes a learning signal).

**Layout (specific to this tracker):**
- Hero: today's lost minutes (sum across all logs) + this-week comparison
- Today's procrastination log (manual + auto, mixed chronologically)
- **Task-type heatmap:** which task types get procrastinated most? Self-study 78%, gym 12%, social 0%
- **Time-of-day heatmap:** which hours collapse? Most users have a 2–4 PM trough
- **Identity damage view:** *"Of your procrastinated tasks this week, 80% were Top Student-aligned. The system you're running is moving you away from your stated identity."*

**AI patterns:**
- High-procrastination tasks → suggest restructuring (smaller chunks, different time of day, different room)
- Time-of-day patterns → propose moving difficult tasks to high-energy windows
- Avoidance-substitute patterns → *"You procrastinate with phone 80% of the time. Tomorrow, phone in another room from 9–11 AM."*

**Anti-shame frame:** the screen header explicitly says *"Procrastination is information, not failure."* This isn't decorative — it's a structural choice that makes users actually log honestly.

#### 8.4.5 💧 Water / hydration tracker

Already canonical in 8.2. What's tracker-specific:

- **Auto-target from About You:** `weight_kg × 35 ml`, editable
- **Quick-log buttons:** +250 ml · +500 ml · +1 L · Custom
- **Hourly distribution view:** shows whether the user front-loads (good), back-loads (poor — leads to night-pee disrupting sleep), or spreads evenly
- **Smart reminders:** if user hits 50% of target by noon, evening reminders are auto-reduced; if they're at 20% by 6 PM, frequency increases
- **Heat boost (location-permission-only):** on hot days (>35 °C from local weather), AI bumps target by 500 ml and adds 2 reminders. User can disable.
- **Container presets:** user can save their water bottles as named buttons ("My 750ml bottle") for one-tap logging

#### 8.4.6 🧘 Meditation tracker

This tracker includes a **built-in meditation timer**, not just a logger.

**Timer screen (full-screen overlay when user taps "Start meditation"):**
- Animated breathing orb in the center (4-7-8 or box breathing visual)
- Bell at start, optional bells at 1/5/10-min intervals, bell at end
- Background sound options: Silence · Rain · Forest · White noise · Tibetan bowls
- Pause/resume; tap **Mark complete** at end OR let the timer auto-complete
- Vibrates phone gently at start/end for screen-off use

**Optional pre-session check-in:** mood slider 1–10, energy slider 1–10
**Optional post-session check-in:** same sliders → AI tracks *meditation lift* (post − pre), surfaces it weekly: *"Your average meditation lift is +2.1 points. It's working."*

**Layout (specific):**
- Hero: today's meditation minutes + 🔥 streak
- Lifetime total (e.g., *47 hours meditated*) with milestone badges (10h, 50h, 100h, 365h)
- Type breakdown chart: silent / guided / music
- Session log with notes
- **No goal pressure on length** — any duration counts toward streak. Some days are 90 seconds; that still counts.

#### 8.4.7 💰 Money saving tracker

**Two modes running in parallel:**

**Passive (auto):** money saved from quitting bad habits. Aggregated daily from the smoking, junk-food, alcohol trackers. Not user-action — the system computes it.

**Active (manual):** user logs deposits.
- **+ Log savings** button → *"How much did you save? Why?"*
- Example entries: *"₹500 — didn't eat out"* · *"₹200 — walked instead of cab"* · *"₹1,000 — declined Amazon impulse"*

**Layout:**
- Hero: total saved this month / all-time
- **Sources breakdown** as a pie or stacked bar:
  - 🚭 Cigarettes ₹2,400
  - 🍔 Junk food ₹800
  - 🍻 Alcohol ₹0
  - ✋ Manual ₹500
  - **Total: ₹3,700**
- **Savings goal ring:** *"₹3,700 / ₹5,000"* — the user attaches a target (custom name + amount + emoji). Multiple goals can run in parallel (vacation fund, emergency fund, gear).
- **Reflective card** (weekly): *"What your discipline bought this week"* — translates rupees into something concrete: *"₹1,200 this week = 8 days at your gym membership rate / 2 books / ⅓ of a new keyboard."*
- **Goal-progress reframe:** *"₹1,300 from the keyboard. That's 26 cigarette-free days at current pace."*

**AI behavior:** during a relapse week, the savings counter is **temporarily hidden** so the contrast doesn't shame. It returns automatically when the user has 2 clean days again.

#### 8.4.8 📖 Reading tracker

**Three log modes** (chosen during habit setup, switchable):
- **Time-based:** minutes read per day
- **Pages-based:** pages read per day
- **Books-based:** books finished per month/year

**Currently reading shelf** (the heart of this tracker):
- User adds a book: title + author → Google Books API lookup pulls cover, page count, genre, blurb. Manual entry as fallback.
- Each book card shows progress bar (page X / total) and last-read date
- Tap a book → log a session, mark progress, add a note/highlight

**Session log:** date, duration, pages from-to, optional note
**Reading streak:** any reading on a day counts toward streak
**Yearly goal:** *"12 books in 2026"* with progress ring + on-track / off-track indicator
**Genre breakdown:** auto-tagged from Google Books, editable
**Highlights/notes:** simple per-book text list. Not a full e-reader — just enough to capture the moment.

**AI patterns:**
- *"You read 4× more on weekends. Want to lock weekend mornings as reading time?"*
- *"You've started 3 books and finished 0 in the last 60 days. Pick one to focus on?"* (gentle, optional)

#### 8.4.9 🏃 Exercise / running tracker

**Workout type chips:** 🏃 Run · 💪 Weights · 🚴 Bike · 🏊 Swim · 🧘 Yoga · 🏋 Other (custom)

**Quick-log fields (universal):** duration, type, intensity (Light / Moderate / Hard), optional pre/post mood

**Type-specific extra fields:**
- **Run / bike / swim:** distance, pace (auto-calculated), optional route name, optional weather (for runners who care)
- **Weights:** muscle-group tags (chest / back / legs / arms / core), top sets — exercise + weight + reps. Simple list, not a full lifting app.
- **Yoga:** style (Vinyasa / Hatha / Restorative / etc.), instructor/class name (optional)

**Personal Records (PRs):** auto-detected and highlighted at the top of the screen the day they happen. *"🏆 New 5K PR: 26:14 (previous: 27:02)"*

**Health integration (opt-in):** Google Fit / Apple Health auto-pulls workouts the user did outside Optivus, so they don't have to double-log. User reviews and confirms each pulled workout.

**Weekly summary:**
- Total volume (minutes)
- Total distance (if any cardio)
- Type breakdown
- Compared to last week

**AI patterns:**
- Correlates workout intensity with sleep, mood, slip count → *"Hard workouts on Mondays correlate with better Tuesday studying. Want to lock that pattern?"*
- Detects under-recovery: 5 hard workouts in 5 days → *"Take tomorrow as active recovery — yoga or a walk."*

#### 8.4.10 📋 Daily routine completion tracker (the meta-tracker)

This isn't a habit — it's a tracker *of the routine itself*. It measures how well the user is following their own planned day.

**Hero metric:** today's completion % = `completed_blocks / scheduled_blocks` (paused and in-progress blocks count proportionally; abandoned counts as 0)

**Block-by-block view:** scroll through today's blocks chronologically, each with a status badge:
- ✅ Completed (with planned-vs-actual duration)
- ⏳ In progress
- ⏸ Paused
- ❌ Abandoned
- ⏭ Skipped (with reason if logged)
- ⏰ Upcoming

**Per-routine-type breakdown:**

| Routine | Today | This week |
|---|---|---|
| 🌿 Skin Care | 100% | 86% |
| 🎓 Classes | 67% | 71% |
| 🍳 Eating | 75% | 81% |
| 📋 Fixed schedule | 50% | 64% |
| 🏋 Custom blocks | 100% | 90% |

**Drift heatmap:** grid of hour × day-of-week showing which time slots collapse most. Most users have a 2–4 PM trough.

**Weekly view:** 7-day color-coded ring grid — each day's completion % at a glance. Months can be browsed back.

**Weekday patterns** (the most actionable surface):
- *"Mondays you average 62%. Sundays 91%. Want me to redesign Monday from scratch?"*
- *"Your 5 PM gym block has been completed 4 of last 7 weekdays. The 8 AM study block: 1 of 7."*

**AI integration:** routine completion % feeds the Mission ring on Home, which feeds identity progress in Goals (Section 9). The AI's daily planner (Section 13) reads this tracker first when computing tomorrow's plan — chronic afternoon drift triggers a *"lighten the afternoon"* suggestion, chronic Monday drift triggers a *"redesign Monday"* offer.

**Why this is its own tracker:** every other tracker measures *one habit*. This one measures *the system*. It's the first place the user looks when they feel like things are off but can't articulate why.

### 8.5 Adding a new habit

#### Flow
1. User taps **+ Add habit** on Tracker home
2. Bottom sheet rises: *What do you want to track?*
3. Two big buttons: **Build a good habit** / **Drop a bad habit**
4. Picks one → list of presets appears (same library as onboarding) + *"Custom"* at the bottom
5. Picks a preset → quick-config screen:
   - Habit name (pre-filled, editable)
   - Emoji + color picker
   - Daily goal (with sensible default — e.g., gym = 1×/day, water = 2 L)
   - Unit (auto-set, editable)
   - Reminder time(s) — optional
   - Coach mode override — optional (e.g., set this one habit to Recovery Coach by default)
6. Tap **Save** → emits `habit_added` → user lands on the new habit's detail screen with empty state and a *"Log your first one"* prompt

### 8.6 Editing & archiving

- **Edit goal**: tap 🎯 → numpad sheet → save → emits `habit_goal_edited`
- **Pause**: hides the habit from Tracker home and stops streak counting, but preserves history. Reactivating restores everything except the broken streak (it stays broken).
- **Archive**: removes from Tracker home and from AI's active context. History is preserved but no longer used in suggestions. Reversible from Profile → *Archived habits*.
- **Delete**: hard delete with double-confirm. Reachable only from Profile, not from the habit detail screen, on purpose.

### 8.7 Why the Tracker matters

The Tracker isn't just a logger — it's where the user *sees themselves* in data. Every screen here is built around three principles:

1. **Logging takes ≤2 taps.** If it takes more, users stop logging, and the AI goes blind.
2. **Every screen has the AI's interpretation visible**, not buried in chat. The Tracker is where pattern → insight → action lives in one glance.
3. **Bad habit screens are gentle by default.** The hardest moment in this app is logging a slip; the screen design makes that act feel safe.

### System mapping

| User action | Event | Service | DB write |
|---|---|---|---|
| Tap a metric card from Tracker home | — (read-only navigation) | — | none |
| Quick-log from a card (+250ml, +1 cig, etc.) | `good_habit_logged` or `bad_habit_slip_logged` | HabitService → StreakService → MissionRing → MoneySavedCounter (if applicable) | `users/{uid}/habit_logs`, `users/{uid}/streaks/{habit_id}` |
| Edit habit goal (numpad sheet) | `habit_goal_edited` | HabitService | `users/{uid}/habits/{habit_id}.target_*` |
| Pause a habit | `habit_paused` | HabitService → StreakService (freeze counter) | `users/{uid}/habits/{habit_id}.is_paused = true` |
| Archive a habit | `habit_archived` | HabitService | `users/{uid}/habits/{habit_id}.archived_at` set |
| Delete a habit (from Profile, double-confirmed) | `habit_deleted` | HabitService | hard delete: `habits/{habit_id}` removed (logs preserved for audit) |
| Add a new habit | `habit_created` | HabitService | new doc at `users/{uid}/habits/{new_id}` |

---

## 9. Goals screen flow

**Goal:** Make long-term identity goals feel like *living things*, not abstract aspirations. Every identity should connect visibly to today's habits and tasks, with the AI explaining the score so the user trusts the system.

> **Build status:** This screen is incomplete in the current codebase. This section is the design spec.

### 9.1 Goals home

#### Entry points
- Bottom tab bar — **Goals** (index 4)
- Onboarding completion — first-time user lands briefly here for orientation
- AI coach message — *"Your Strong Body identity is at 64%"* deep-link
- Profile — tap *Identity Statement* → routes to Goals

#### What the user sees

1. **Identity Statement card** (top, glass plaque)
   - A single-sentence summary the user wrote (or the AI suggested) during onboarding:
     *"I'm becoming someone who is strong, disciplined, and a top student."*
   - Tap → edit
   - Below: chip row of selected identities, each tappable

2. **Hero card — Today's identity push**
   - The single identity most touched by today's planned tasks
   - *Today is a Strong Body day.* — *"Gym + 2L water + sleep before 11 = +3% if you complete all three."*
   - Encourages the user to see their day through one identity lens

3. **Identity grid** — 2-column grid of identity cards

   Each card shows:
   - Emoji + identity name (e.g., 💪 Strong Body)
   - Current % with a small progress arc
   - Trend chip: ↗ +4% this week / → flat / ↘ -2%
   - Sub-line: *"3 active habits feeding this"*

   Selected identities only — *"+ Add identity"* tile at the bottom right.

4. **Milestones strip** (horizontal scroll)
   - Glass cards: *"5 lbs gained 🎯 · Read 12 books 📚 · 30-day no-smoke streak 🚭"*
   - Each shows progress (e.g., *"3.2 / 5 lbs"*) and is checkable when complete

5. **AI insight card** *(if relevant)*
   - *"Top Student is your slowest-moving identity (+1% this month). Want me to propose 2 changes?"*
   - **Yes** → opens Coach with proposed plan / **Not now**

#### Interaction map

| User taps | What happens |
|---|---|
| Identity Statement | Edit modal — change the sentence |
| Identity card | Pushes identity detail screen (9.2) |
| Today's identity push card | Opens Routine tab with today's identity-aligned blocks highlighted |
| Milestone card | Pushes milestone detail (9.6) |
| **+ Add identity** | Opens identity picker (same library as onboarding) (9.4) |
| Long-press an identity | Quick menu: Edit · Pause · Archive · Connect habits |

### 9.2 Identity detail screen — Strong Body as the canonical example

#### Layout

1. **Hero**
   - 240px progress arc, center: *64%*
   - Trend: ↗ +4% this week
   - Started: *Day 0 — Apr 1* / Target: *Ongoing* (or specific end date)
   - Below: a single-sentence definition the user can expand:
     *"Strong Body means I move daily, eat to fuel growth, and sleep before 11."*

2. **Daily contributions section** — *"What feeds this identity"*

   A list of habits and routine blocks tied to this identity. Each row shows the habit name, its weekly target, this week's actual, and a contribution-weight indicator (how much it pulls the score):

   | Contributor | This week | Weight |
   |---|---|---|
   | 🏋 Gym (target 5×/wk) | 3 / 5 | High |
   | 💧 Hydration (target 2 L/day) | 6 / 7 days hit | Medium |
   | 🌙 Sleep before 11 PM | 4 / 7 days hit | High |
   | 🍳 Eating routine | 5 / 7 days followed | Medium |

   Tap any row → jumps to that habit's detail screen (8.2).

3. **Why this score?** — expandable AI explanation card

   *"Your score is 64% because: gym is at 60% (3 of 5), hydration at 86% (6 of 7), sleep target at 57% (4 of 7), eating at 71%. Sleep and gym pull the score most because both are weighted High. If you hit gym tonight and sleep before 11, you'd jump to ~67% by tomorrow morning."*

   This is the AI being **transparent about its model**, not a black box. Critical for trust.

4. **Milestones for this identity** — list with checkboxes
   - *□ First 30 days consistent*
   - *☑ +2 kg weight gained* (auto-detected from biometrics, manually confirmable)
   - *□ 30-day gym streak*
   - *□ Resting HR below 70* (manual)
   - **+ Add milestone**

5. **Recent wins / slips** — auto-curated 7-day timeline
   - *Apr 22 — Skipped gym (slip)*
   - *Apr 23 — Hit hydration target*
   - *Apr 24 — Slept at 12:30 AM (slip)*
   - This isn't a guilt log — it's pattern visibility

6. **Talk to coach about this identity** — opens Coach with identity pinned

7. **Settings row**
   - 🔗 *Connect habits* — choose which habits feed this identity (multi-select)
   - ⚖ *Adjust weights* — change how much each contributor pulls the score (advanced)
   - ⏸ *Pause* — stop scoring this identity; AI stops referencing it; reversible
   - 🗑 *Archive* — remove from active list; history preserved

#### Edge cases
- **Conflicting identities** — if a habit feeds two identities (gym → Strong Body + Become Disciplined), it counts toward both with adjustable weights
- **Pause**: identity disappears from Goals home and AI's daily planner stops referencing it. Active habits keep tracking but stop contributing to the paused identity's score.
- **Archive**: same as pause but also removed from the identity grid. Reversible from Profile → *Archived identities*.

### 9.3 Why this score? — the transparency layer

This is the most important micro-feature in the entire Goals tab. Most habit apps show a number; almost none explain it. Optivus does, because:

- The user can argue with the math (and the AI will adjust)
- The user understands which contributors matter most
- The system feels honest, not gamified

Implementation: every score is the weighted sum of its contributors' completion rates over the last 28 days. The AI's explanation card recomputes on every open and stays in plain language. If the user disagrees with the weights, tap **Adjust weights** → sliders.

### 9.4 Adding a new identity

1. User taps **+ Add identity** on Goals home
2. Bottom sheet rises with the same 8 default identities from onboarding (Strong Body, Top Student, Become Disciplined, etc.) plus *"Custom"*
3. Picks one or types custom name
4. Quick-config screen:
   - Identity name (editable)
   - Emoji + color
   - One-sentence definition (the user writes this — *"To me, Top Student means…"*)
   - Suggested contributing habits — AI proposes 3–5 based on the user's existing habits
   - Target end date or *Ongoing*
   - Initial milestone (1 suggested, editable)
5. Tap **Add** → emits `identity_added` → user lands on the new identity's detail screen at 0% with empty state

### 9.5 Pausing & archiving

- **Pause**: keeps everything but stops counting toward score and AI suggestions for 7/30/90 days or *Until I unpause*. Useful during exam weeks (pause Strong Body) or recovery periods (pause Top Student).
- **Archive**: removes from active list. Useful when an identity has been *fulfilled* (e.g., user finished a degree, archives Top Student) or *abandoned with closure*. The AI sends a final summary card before archive: *"Top Student — 19 months, peaked at 78%. Want a recap?"*

### 9.6 Milestone marking

- Auto-completing milestones (e.g., *+2 kg gained*) check themselves off when biometrics are updated
- Manual milestones get a check button on the milestone strip and the identity detail screen
- Completing a milestone fires `milestone_completed` event, triggers a single P6 celebration notification (subject to budget), and the next milestone in the chain is suggested by the AI

### 9.7 The connection between Goals, Habits, and Routine

This connection is **the differentiator** — what makes Optivus more than a habit tracker.

- Every habit can declare which identity (or identities) it feeds — set during habit creation, editable via *Connect habits*
- Every routine block can be tagged with an identity, so the timeline visually inherits identity colors when the user opens *"Today is a Strong Body day"* from the hero card
- Daily Mission ring on Home is the weighted sum of *today's* identity-aligned task completions, not just any task completions

This means: a user who finishes 7 of 10 random tasks but skipped the 3 that mattered most for *their* chosen identities will see Mission ring < 70%, and the AI will say so. This is the system telling the truth.

### System mapping

| User action | Event | Service | DB write |
|---|---|---|---|
| Add a new identity goal | `identity_created` | IdentityProfile → GoalService | `users/{uid}/identities/{new_id}` |
| Edit an identity (rename, change weight) | `identity_updated` | IdentityProfile | `users/{uid}/identities/{id}` |
| Connect a habit to an identity | `identity_habit_linked` | IdentityProfile → HabitService | `users/{uid}/habits/{habit_id}.identity_ids[]`, `users/{uid}/identities/{id}.linked_habits[]` |
| Mark a manual milestone complete | `milestone_completed` | IdentityProfile | `users/{uid}/identities/{id}/milestones/{m_id}.completed_at`, P6 celebration notification queued (subject to frequency cap) |
| Pause an identity | `identity_paused` | IdentityProfile | `users/{uid}/identities/{id}.is_paused = true` |
| Archive an identity | `identity_archived` | IdentityProfile | `users/{uid}/identities/{id}.archived_at` |
| Identity % recomputed (system) | `identity_progress_changed` | IdentityProfile | `users/{uid}/identities/{id}.current_pct` |

---

## 10. Profile screen flow

**Goal:** Be both the *self-reflection surface* (who am I becoming?) and the *settings surface* (how do I want this app to behave?). Most apps make Profile a settings dump; Optivus treats it as a mirror.

### 10.1 Profile home

#### Entry points
- Bottom tab bar — **Profile** (index 5)
- Coach tab — tap coach avatar → menu → *Coach settings* deep-links here
- Any *Settings* gear in the app

#### What the user sees (top to bottom)

1. **Identity hero** (full-width glass card)
   - Avatar (auto-generated or user-uploaded)
   - User name (e.g., *Nairit*)
   - Identity statement: *"Becoming strong, disciplined, and a top student."*
   - Big stat row: 🔥 *18-day streak · ⏱ 122 h focus · 💰 ₹2,400 saved*

2. **Strengths & Areas to Improve** card *(AI-generated, refreshes weekly)*

   | Section | Example content |
   |---|---|
   | **Strengths** | 💧 *Hydration — 86% consistency* / 🌿 *Skincare — 9-day streak* / 🏋 *Gym — gaining momentum* |
   | **Areas to improve** | 🌙 *Sleep — only 4 of 7 nights on time* / 📱 *Doom-scrolling — 4 h average* |

   Each item is tappable → deep-links to that habit's detail screen.

3. **Coach card**
   - Coach avatar (purple bot orb)
   - *Bro · Tough Love · Online*
   - Tap → Coach settings (10.3)

4. **Settings list** (each row is a glass plaque pressing into a sub-screen)
   - 🗓 *Routine settings* → opens Routine Settings (deep-links to Skin Care / Eating / Classes / Fixed Schedule setup screens — Section 3)
   - 🤖 *Coach settings* (10.3)
   - 📊 *Accountability* (10.4)
   - 🔔 *Notifications* (10.5)
   - 🧬 *About You* (10.6) — biometrics + health flags
   - 🔒 *Privacy & data* (10.7)
   - 💎 *Subscription* (10.8)
   - ❓ *Help & feedback*
   - 👋 *Sign out* (10.9)

5. **Footer** — version number, build, *"Made with care."*

### 10.2 Identity Statement — the self-reflection surface

Tapping the hero card opens a full-screen edit:

- The current statement in editable text
- Below: AI-suggested rewrites based on the user's actual progress (*"Try: 'I'm someone who shows up — even on hard days.'"*)
- Suggestion chips can be tapped to replace the statement; the user can also write freely
- Save → emits `identity_statement_changed`

The Strengths/Areas to Improve card is generated weekly by the AI from the user's logged data and shouldn't be hand-edited. Tap a card row → that habit's detail screen, where the user can act on it.

### 10.3 Coach settings

A sub-screen with:

- **Coach name** — text field (default *Bro*, editable; suggestion chips: Dad, Maa, Sensei, Sir, custom)
- **Coach style** — single-select cards: Supportive · Tough Love · Analytical · Zen Master · Motivational · Friendly *(same UI as onboarding Page 6)*
- **Tone budget**
  - *Max sharp interventions per day*: slider 0–5, default 2
  - *Auto-soften after bad days*: toggle, default ON (the doom-loop safeguard from Section 13.4)
- **Voice & alarms**
  - *Coach voice on alarms*: toggle ON/OFF
  - *Voice clip preview*: play sample line in the current style
- **Topic modes** (long-press shortcuts)
  - Multi-select: Recovery Coach, Study Coach, Calm Coach
- **Reset coach memory** *(advanced, with warning modal)*
  - *"This wipes the coach's conversation history but keeps your habits, routines, and goals. Use this if the coach's tone has drifted in a way that doesn't help you."*

Saving any change emits `coach_style_changed` and the AI's next message uses the new settings.

### 10.4 Accountability

Three vertical cards (same UI as onboarding Page 8):
- 🪶 **Forgiving** — 1 free skip per habit per 7 days; gentle reset language
- 📋 **Strict** — no grace; gentle reset language
- 🔒 **Ruthless** — no grace; sharp reset language; no Tough Love auto-softening

Below, two switches:
- *Apply across all habits* (default ON)
- *Override per-habit* — opens a per-habit list where the user can set different accountability for sensitive habits (e.g., Forgiving for cigarettes, Strict for gym)

Save emits `accountability_changed` and updates the streak service immediately.

### 10.5 Notifications

This is where Section 11's caps and rules become user-controllable.

- **Daily notification budget** — slider 3–15, default 8
- **Per-category caps** — sub-row sliders for Task reminders (5), Slip responses (2), Coach insights (2), Celebrations (1)
- **Quiet days** — quick toggle for *today* + scheduled quiet days (pick a future date)
- **Blackout windows** — list of time ranges where only P1 alarms fire (default: Sleep block; user can add Deep Work blocks, Meeting hours, etc.)
- **Custom alarms** — list of tasks where the user opted into P1 alarms (Wake-up, Gym, Meds…), each toggleable
- **Sound** — pick the default tone for non-alarm notifications + per-category overrides
- **Vibration pattern** — Subtle / Standard / Earthquake (for heavy sleepers)
- **Test notification** — fires a sample so the user feels what they're configuring

### 10.6 About You editor

This screen mirrors the onboarding Page 5 structure (three sub-pages) and is the **only** place the user can change biometrics and health flags after onboarding.

- **Body basics** — DOB, gender, height, weight, target weight, activity level
  - Updating weight emits `biometrics_updated` → recomputes BMI, calorie targets, water target
  - The screen shows the *delta* from last entry: *"You logged 50 kg. Last entry: 49.2 kg three weeks ago. +0.8 kg ↗"*
- **Lifestyle rhythm** — wake/sleep times, water target, occupation, timezone
  - Wake/sleep changes adjust all default routine block defaults but **don't** retroactively change existing routine blocks (user must edit those manually if desired)
- **Sensitive context** — diet, allergies, health flags, therapy/medication
  - All changes emit `health_flags_changed`
  - Toggling **eating disorder history** ON shows a one-time confirmation: *"This will hide all calorie counts, weight comparisons, and before/after framing across the app. You can change this anytime."*
  - Toggling it OFF shows: *"This will re-enable calorie tracking. Sure?"* — friction is intentional both ways

### 10.7 Privacy & data

A trust-building screen — not legalese, plain English:

- **What we collect** — bullet list of categories (event log, biometrics, conversations, optional phone usage). Tap each for a one-paragraph explanation.
- **Where it lives** — *"Your data lives in your private Firestore document. Anthropic / Gemini sees only the messages you send to the coach, never your habit history directly."*
- **Export your data** — button that generates a JSON + CSV bundle and emails it to the user. Emits `data_export_requested`.
- **Delete a category** — granular: delete just chat history, just events, just biometrics
- **Delete account** — bottom of screen, gentler than red. Tapping opens a multi-step confirm:
  1. *"Are you sure? Your streaks, identity progress, and 1,247 logged events will be erased."*
  2. *"Type DELETE to confirm."*
  3. *"This is permanent. We can't bring it back."*
  4. Final **Delete** button. Emits `account_deleted`. User signs out and account is queued for hard-delete in 7 days (recoverable within that window via re-login).

### 10.8 Subscription

- Current tier: Free / Pro
- Free tier limits: *10 coach messages/day, no custom alarms, no advanced topic modes*
- Pro features list with checkmarks
- Upgrade button → native paywall (App Store / Play Store)
- Manage subscription → opens platform settings

### 10.9 Sign out

- Tap *Sign out* → confirm modal: *"Sign out? Your data stays safe and you can log back in anytime."*
- Confirm → Firebase signs out → router sends user to `/welcome`
- The next launch routes to `/login` (not onboarding) because the device remembers the user has an account

### 10.10 Why Profile is more than settings

The Profile tab is the user's *mirror* — the one place where the app says *"this is who you are right now, in this system."* Three principles:

1. **Identity-first**, settings-second. The hero card and Strengths/Improve cards live above the settings list on purpose.
2. **Every settings change has an event.** Profile is a major source of events feeding the AI's adaptive behavior; the AI notices when a user changes their accountability from Strict to Forgiving and adjusts tone for the next 24 hours.
3. **No dark patterns.** Sign out and Delete account are reachable in 2 taps. Nothing is buried. The trust this builds compounds.

### System mapping

| User action | Event | Service | DB write |
|---|---|---|---|
| Edit Identity Statement | `identity_statement_updated` | IdentityProfile | `users/{uid}/profile.identity_statement` |
| Change Coach style / tone | `coach_settings_changed` | UserSettingsService | `users/{uid}/settings/coach.*` |
| Change Accountability mode | `accountability_changed` | UserSettingsService → StreakService (recompute current streaks under new rule) | `users/{uid}/settings/accountability`, `users/{uid}/streaks/*` |
| Toggle a notification category on/off | `notification_settings_changed` | UserSettingsService → NotificationService (cancel scheduled notifications in category if disabled) | `users/{uid}/settings/notifications`, `users/{uid}/scheduled_notifications` |
| Edit "About You" (biometrics) | `biometrics_updated` | UserSettingsService | `users/{uid}/profile.biometrics` |
| Tap **Export my data** | `data_export_requested` | DataExportService | export job queued, email sent with signed URL when ready |
| Tap **Delete account** | `account_deletion_requested` | DataDeletionService → AuthService | 30-day cascade deletion job queued; auth disabled immediately |
| Tap **Sign out** | `user_signed_out` | AuthService | local session cleared; Firestore listeners detached |

---

## 11. Notification & trigger system

UX-layer sentences like *"AI sends a notification 30 seconds after a slip"* are not enough — without explicit timing, frequency, and priority logic the app becomes either spammy or silent. This section defines the actual rules.

### 11.1 Adaptive timing rules

Every coach-driven notification goes through a delay function before it actually fires:

```
delay = base_delay
  + cooldown_remaining(category)
  + suppression_check()
  - urgency_boost
```

**Per-category base delays:**

| Category | Base delay | Why |
|---|---|---|
| Slip response | 30s | Fast enough to feel present, slow enough to not feel like surveillance |
| Task pre-reminder | 5 min before scheduled start | Window to mentally arrive |
| Active task alert (started, not finished) | end_time + 5 min | Lets the user run slightly over without a poke |
| Started-but-never-completed chime | end_time + 0 min | Single soft chime at planned end |
| Proactive coach insight | Strategic — see Section 13 | AI decides when, not the timer |
| Streak/celebration | At natural pause point (next 30-min boundary, but not during active task) | Don't break flow |

**Adaptive boosts and suppressions:**
- If user has app open *right now*: replace push with in-app toast; no system notification fires
- If user just logged a positive action in the last 5 min: suppress unless P1 (don't poke after a win)
- If user just dismissed a similar notification: increase delay by 2x for next 24 hrs
- If current time falls in a Sleep block: queue until wake, but only deliver if still relevant (most queued items expire silently)

### 11.2 Frequency caps

A daily *budget* is enforced before any notification fires.

| Scope | Default cap | User-configurable |
|---|---|---|
| Total push notifications per day | 8 | Yes (3–15 range) |
| Per category — task reminders | 5 | Indirect (via budget) |
| Per category — slip responses | 2 | Yes |
| Per category — proactive coach insights | 2 | Yes |
| Per category — streak/celebration | 1 | Yes |
| Notifications per rolling 60 min | 2 | No (hard rule) |
| Min gap between same-category notifications | 45 min | No (hard rule) |
| "Quiet day" mode override | All P4–P6 muted | One-tap toggle from Home |

When the budget is full, lower-priority notifications get *dropped silently* (not queued), but they still emit `notification_suppressed` events so the AI can learn what it's not getting to say.

### 11.3 Priority hierarchy

Six tiers, P1 highest:

| Tier | Type | Bypasses DnD | Bypasses budget |
|---|---|---|---|
| **P1** | Custom alarms (wake-up, medication, deep work the user explicitly opted in for) | Yes | Yes |
| **P2** | Active task alerts (you started something and it's hanging) | No | Yes |
| **P3** | Scheduled task reminders (5-min pre, gentle nudge) | No | No |
| **P4** | Slip responses (you logged a slip; coach replying) | No | No |
| **P5** | Proactive coach nudges (insight, suggestion, pattern observed) | No | No |
| **P6** | Celebrations, streak milestones, weekly summary | No | No |

P1 is the only tier with audio that bypasses silent mode (and it's user opt-in per task type during onboarding). P6 is the first thing dropped when the budget is tight.

### 11.4 De-duplication & coalescing

- If user logs 3 cigarette slips within 30 min, the coach sends **one** message at the 30-min mark, not three (`slip_streak_detected` event fires instead of three `slip_logged` reactions)
- If a notification arrives while another is on screen (rare race), the newer P1/P2 replaces it; otherwise it's dropped
- Same-task pre-reminder + active-task alert never fire within 10 min of each other (the active-task alert wins)

---

## 12. Event system

The app is built on a published event log. Every meaningful state change emits an event; services subscribe to the events they care about. This decouples UI from logic and gives the AI a clean stream to learn from.

### 12.1 Event naming convention

`{domain}_{state_or_action}` — past tense for things that happened, present tense for active states. Names are stable; payloads can grow but never break backwards.

### 12.2 Full event catalog (v1)

| Event name | Emitted by | Payload | Listeners | Side effects |
|---|---|---|---|---|
| `user_signed_up` | Auth flow | `{user_id, email, signup_ts, source}` | Onboarding router, Analytics | Routes to onboarding |
| `onboarding_completed` | Page 10 *Enter Optivus* tap | `{user_id, identity_profile, biometrics, schedule, completed_ts}` | Identity Profile builder, AI Coach (system prompt seeding), Notification scheduler, Plan generator | First plan generated |
| `task_scheduled` | Plan generator | `{task_id, type, planned_start, planned_end, parent_routine?, alarm_tier}` | Notification scheduler | Pre-reminders armed |
| `task_started` | User taps *Start* | `{task_id, planned_start, actual_start, drift_minutes, started_via}` | Notification scheduler (cancel pre-reminder), Streak service, AI memory, Mission ring | Pre-reminders cancelled, active timer pinned |
| `task_paused` | User taps *Pause* | `{task_id, paused_at, elapsed_so_far}` | Notification scheduler (arm 20-min auto-abandon timer) | — |
| `task_completed` | User taps *Mark complete* | `{task_id, planned_duration, actual_duration, drift_pct, subtasks_completed, subtasks_total}` | Streak service, Mission ring, Identity Profile (% delta), AI learning loop | Mission ring updates, identity %s recompute |
| `task_abandoned` | Auto (planned end + 20 min idle) or user | `{task_id, started_at, abandoned_at, reason_tag?}` | AI Coach (queue gentle check-in), Streak service | Queued AI check-in |
| `task_skipped` | User taps *Skip* | `{task_id, reason_tag, skipped_at}` | AI learning loop, Streak service | — |
| `good_habit_logged` | Tracker tab or Home pill | `{habit_id, amount, unit, ts}` | Streak service, Mission ring, AI memory | Counter + streak update |
| `bad_habit_slip_logged` | Tracker tab | `{habit_id, trigger_tag?, ts, count_today}` | AI Coach (decides response), Streak service, Money-saved counter | P4 notification queued via Section 13 logic |
| `slip_streak_detected` | Streak service (3+ slips in 30 min) | `{habit_id, count, window_min}` | AI Coach (single coalesced response) | Replaces individual slip notifications |
| `coach_message_sent` | User in Coach tab | `{turn_id, text, mode}` | Gemini service | Reply streamed back |
| `coach_replied` | Gemini service | `{turn_id, text, suggested_actions?}` | Coach UI | Bubble rendered |
| `suggestion_generated` | AI planner | `{suggestion_id, type, target_date, rationale, priority_score}` | Routine AI panel, Notification scheduler (if P3+) | Card displayed |
| `suggestion_accepted` | User taps *Accept* | `{suggestion_id, type}` | Plan generator, AI learning loop (reinforce this pattern) | Plan modified |
| `suggestion_dismissed` | User taps *Dismiss* | `{suggestion_id, reason?}` | AI learning loop (deprioritize similar for 7 days) | — |
| `notification_sent` | Notification service | `{notif_id, category, priority, ts, delivered}` | Frequency cap counter, Analytics | Budget decrements |
| `notification_tapped` | OS callback | `{notif_id, deep_link}` | Deep link router, AI learning loop (this nudge worked) | App opens to target |
| `notification_dismissed` | OS callback | `{notif_id, dismissed_via}` | AI learning loop (this nudge type isn't landing) | — |
| `notification_suppressed` | Notification service | `{would_have_been_id, reason: budget_full \| dnd \| cooldown \| dedup}` | AI learning loop | — |
| `day_started` | First *Start* tap of the day OR 6 AM fallback | `{date, planned_blocks_count, weekday_template_id}` | Daily planner (Section 13) | Today's priority queue computed |
| `day_closed` | Sleep block start OR midnight cutoff | `{date, completion_pct, slips, abandoned_count, completed_count, focus_minutes}` | End-of-day summary generator, Streak service, AI learning loop, Identity Profile | Summary message queued |
| `identity_progress_changed` | Identity Profile | `{identity_id, old_pct, new_pct, delta}` | Goals tab, Profile tab | UI refresh |
| `ghost_day_detected` | Background job | `{user_id, last_seen_ts, missed_days}` | Re-engagement service (Section 14) | Tier-appropriate intervention |
| `comeback_initiated` | User opens app after 3+ day gap | `{user_id, gap_days}` | Comeback flow, AI Coach (tone reset to Supportive) | Comeback modal shown |

### 12.3 Event ordering & persistence

- All events write to a local event store (offline-tolerant) and sync to Firestore when online
- Events are append-only — never mutated or deleted
- Each event has `event_id`, `user_id`, `ts`, `device_id`, `payload`, `version`
- The AI memory layer subscribes to the same stream the UI does, so what the user sees and what the AI knows are guaranteed consistent

---

## 13. Strategic AI planning loop

Reactive AI responds to whatever just happened. Strategic AI decides — at the start of the day — *what matters most today*, allocates a finite speak budget against it, and stays silent the rest of the time. Section 13 defines that loop.

### 13.1 Daily planner — runs once at `day_started`

When `day_started` fires, the AI planner runs synchronously before any notifications are scheduled:

1. **Pull state**
   - Today's planned blocks (from Routine)
   - Yesterday's `day_closed` payload (what got done, what didn't)
   - Last 7 days of patterns from the event log (cigarette spike on Mondays at 11:30 AM, gym consistently runs 22 min over)
   - Identity Profile current %s
   - Current streaks
   - User's notification budget for today (default 8)

2. **Generate intervention candidates** — every potential coach moment for the day, tagged with priority score:

   | Candidate type | Example | Default priority |
   |---|---|---|
   | Carry-over from yesterday | "You abandoned sleep block — let's not repeat" | 9/10 |
   | Pattern-based pre-emption | "Walk at 11:25 AM (Monday stress trigger)" | 8/10 |
   | Identity-aligned push | "Gym + study both align with Top Student" | 7/10 |
   | Goal nudge | "You're 4% from next milestone on Strong Body" | 5/10 |
   | Celebration | "Day 18 hydration streak" | 3/10 |

3. **Allocate speak budget**
   - Default budget: 5 proactive interventions per day (separate from task reminders)
   - Sort candidates by priority score, take top 5, schedule them at the timestamps that make the most sense (pre-trigger, mid-afternoon check-in, post-gym celebration, etc.)
   - Remaining candidates go into a *latent queue* — only fire if a slot opens (user dismisses an earlier one without acting, or a higher-priority moment passes silently)

4. **Set silence windows**
   - During every Active task (between `task_started` and `task_completed`)
   - Sleep block start until wake alarm
   - 30 min after any `task_completed` (don't break the flow of a winning streak)
   - 2 hours after any `bad_habit_slip_logged` (one response, then back off)
   - First 15 min of any deep-work / focus block flagged by user

### 13.2 Priority resolution — which suggestion comes first

When multiple suggestion candidates target similar timeslots, the AI uses this ladder:

1. **Safety-relevant** > everything else (hydration when user is dehydrated, sleep when sleep-deprived)
2. **Identity-aligned** > generic improvement (a suggestion that touches a chosen identity beats one that doesn't)
3. **Pattern-broken** > pattern-reinforced (something that addresses a weakness today beats something that reinforces an existing strength)
4. **Pre-emptive** > reactive (a 11:25 AM walk to head off a 11:30 stress trigger beats a 11:35 AM "you slipped" message)
5. **Underutilized category** > over-suggested category (if hydration nudges have been dismissed 3x this week, prefer a different angle)

### 13.3 When NOT to speak

The hardest skill. Explicit rules:

| Rule | Trigger | Behavior |
|---|---|---|
| **Don't break the flow** | User just completed a task | 30-min silence on proactive nudges |
| **Don't pile on after a slip** | `bad_habit_slip_logged` fired | One response within 30s, then 2-hour silence on that habit |
| **Don't interrupt active work** | Any task in Started state | Suppress all P5/P6 until task ends |
| **Don't shout into the void** | User dismissed 3 same-type suggestions in a row | Stop suggesting that type for 7 days |
| **Don't be a doom loop** | 3 consecutive bad days | Tone shifts from Tough Love → Supportive regardless of setting; suggestions get easier (1 micro-task instead of full plan) |
| **Don't waste the morning alarm** | Wake-up alarm is firing | Wake-up alarm voice line *is* the message; don't queue a second push within 15 min |
| **Don't talk during user's lead** | User just opened Coach tab | Wait for user to speak; don't push a proactive insight on top of their message |
| **Quiet day** | User toggled Quiet Day | Only P1 and P2 fire; everything else queues silently |

### 13.4 Tone budget

Tough Love is rhetorically expensive — overuse turns it into noise.

- Tough Love mode: max **2 sharp interventions per day**; remaining nudges soften toward analytical/supportive
- Never Tough Love within 2 hours of a slip log (counterproductive)
- Never Tough Love during a Quiet Day
- After 3 consecutive bad days, Tough Love is auto-disabled for 48 hours regardless of user setting

### 13.5 Adaptive learning

Every `notification_tapped` / `notification_dismissed` / `suggestion_accepted` / `suggestion_dismissed` event feeds back:

- **Reinforcement**: If a phrasing or timing led to action (`task_started` within 10 min of a notification tap), boost similar candidates
- **Decay**: If a suggestion type is dismissed without action 3+ times, its priority score is divided by 2 for the next 7 days
- **Time-of-day learning**: If the user consistently engages with morning nudges and ignores evening ones, shift the AI's speak budget toward mornings
- **Phrasing memory**: The AI remembers which 5 most recent phrasings the user responded to and biases new generations toward similar tone/length

---

## 14. Failure states & re-engagement

Most habit apps die in this section. The user gets one bad day, then three, then a month, then they uninstall. Optivus needs explicit flows for each stage of disengagement, and a non-shaming comeback path.

### 14.1 Failure stage map

| Stage | Trigger | What the app does | What it does NOT do |
|---|---|---|---|
| **Off-day** | User skips/abandons 50%+ of today's blocks | Standard end-of-day summary, but tone softens. AI acknowledges: *"Today was off — happens. Tomorrow's plan is unchanged unless you want to lighten it."* | No streak panic, no guilt language |
| **Bad day** | User skips/abandons 80%+, OR logs 2x baseline slips | Coach offers a "lighten tomorrow" toggle in the EoD message. AI logs `pattern_bad_day` for planner. | No motivational quotes |
| **3 bad days in a row** | Auto-detect | Tone auto-shifts to Supportive. Tomorrow's plan auto-trims to 3 essential tasks (sleep, water, one keystone habit). EoD message: *"Three rough days. Let's make tomorrow tiny on purpose. One thing matters: sleep."* | No Tough Love regardless of setting |
| **Silent day** | App opened but no logs/taps for 12+ hours during waking hours | Single gentle in-app toast at next typical-active hour: *"Quiet today — all good?"* No push | No push notification |
| **Ghost day 1** | App not opened 24+ hours | One push at user's typical morning time: *"Hey — yesterday was quiet. No pressure. Open when ready."* | No streak warnings |
| **Ghost day 3** | App not opened 72+ hours | One push: *"Your streaks are paused, not broken. We're holding them for 4 more days."* | No daily reminders |
| **Ghost day 7** | App not opened 7 days | Final retention push: *"Streaks expire tomorrow. One tap to save them — no need to do anything else today."* | No further pushes after this |
| **Ghost day 14** | App not opened 14 days | Comeback offer push: *"Comeback day? Tap to plan one easy task — that's all."* | No ongoing pushes |
| **Dormant** | App not opened 30+ days | All scheduled notifications cancelled. App enters dormant state. Only a single comeback push per month. | No marketing-style re-engagement |

### 14.2 Streak grace logic

- **Forgiving accountability**: Each habit has 1 free skip per 7-day window. The skip auto-applies; user sees: *"Used your weekly skip on hydration. Streak intact."*
- **Strict accountability**: No grace. Streak resets, but the reset message is gentle: *"Streak ended at 14. Resets are part of it — Day 1 again tomorrow."*
- **Ruthless accountability**: No grace. Sharp reset: *"Streak: 0. You know what to do."*
- **Streak hold during ghost periods**: For ghost days 1–7, all streaks pause (not break). On day 8 they reset. This is fixed across accountability levels — the rationale is that absence ≠ slip.

### 14.3 The comeback flow

When `comeback_initiated` fires (user opens the app after 3+ day gap), the normal Home screen is replaced with a one-time comeback modal:

**Comeback modal**
- Heading: *"Hey. Welcome back."*
- Body: *"No catch-up. No guilt. What kind of day is today?"*
- Three buttons:
  - **Easy day — 1 task** (the AI picks one micro-task: drink water, 5-min walk, 10-min reading)
  - **Half day — 3 tasks** (essentials only: sleep, hydration, one keystone)
  - **Full day — let's go** (today's regular weekday plan)

**Behavior after the user picks:**
- The AI Coach's tone is forced to Supportive for the next 48 hours regardless of user setting
- The Coach does **not** mention the gap unless the user does
- Past slip data is not surfaced in any new conversation for 48 hours
- After 3 successful logs/completions post-comeback, AI offers: *"You're rolling. Want to ramp back up to your full plan?"*
- All ghost-period notifications are cleared

### 14.4 Long-absence safeguards

- After 30 days dormant, the app stops generating notifications entirely until the user opens it
- After 90 days dormant, on next open the app offers: *"Want a fresh start? We can reset streaks and re-do onboarding, or pick up exactly where you left off."*
- User data is **never** deleted automatically. Identity profile, biometrics, schedule, and event history are preserved indefinitely so a return user gets continuity, not a clean slate they didn't ask for.

### 14.5 What this prevents

- **Spam**: Frequency caps + budget + suppression rules mean a struggling user gets fewer notifications, not more
- **Doom loops**: Auto tone-softening after 3 bad days breaks the *"Tough Love → user feels worse → more slips → more Tough Love"* spiral
- **Streak shame**: Pause-not-break during absences removes the most common uninstall trigger in habit apps
- **Silent ghosting**: The 1/3/7/14 day touchpoint ladder keeps a single thread of contact open without nagging
- **Cold returns**: Comeback modal ensures the first interaction after absence is gentle and the bar is low

---

## Appendix: Cross-flow navigation map

```
          ┌─────────────┐
          │   Welcome   │
          └──────┬──────┘
                 ↓ Get Started
          ┌─────────────┐
          │   Sign up   │ ←──→ Login (returning user)
          └──────┬──────┘
                 ↓ create account
          ┌────────────────────────┐
          │   Onboarding 0–10      │  (11 steps)
          └──────┬─────────────────┘
                 ↓ Enter Optivus
                 │
       ┌─────────┼──────────┬─────────┬───────┬─────────┐
       ↓         ↓          ↓         ↓       ↓         ↓
     Home    Routine    Tracker    Coach   Goals    Profile
      │       │           │         │      │         │
      │       ├─ Skin Care setup    │      │         ├─ Routine settings
      │       ├─ Eating setup       │      │         └─ Account / About
      │       ├─ Class setup        │      │
      │       ├─ Fixed schedule     │      │
      │       └─ AI panel ──────────┘      │
      │                                    │
      └────────── tap routine row ─────────┘
                 → deep-link with filter
```

Every flow is reachable in ≤2 taps from any other flow. The bottom tab bar plus deep-links from notifications and the AI coach mean the user is never more than one decision away from where they need to be.
