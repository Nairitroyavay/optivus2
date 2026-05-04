# Fixed Schedule Audit: `onboarding_page_9.dart` vs `fixed_schedule_setup_screen.dart`

> All line references are to the files as they exist on branch `main` (2026-05-04).

---

## 1. Files inspected

| File | Path |
|------|------|
| **OP9** | `lib/views/onboarding/onboarding_page_9.dart` |
| **FSSS** | `lib/views/routine/fixed_schedule_setup_screen.dart` |
| onboarding provider | `lib/providers/onboarding_provider.dart` |
| routine provider | `lib/providers/routine_provider.dart` |
| user repository | `lib/repositories/user_repository.dart` |
| routine repository | `lib/repositories/routine_repository.dart` |
| Firestore service | `lib/services/firestore_service.dart` |

---

## 2. Widget tree overview

### `onboarding_page_9.dart` (OP9)

Lives inside the `OnboardingScreen` pager — no Scaffold/AppBar of its own.

```
Padding (top/bottom safe area + onboarding indicator height)
  Column
    RichText                        — "Set Your Fixed Schedule" (title)   L495–513
    Text                            — subtitle                             L515–523
    SizedBox(height: 24)
    Row (mainAxisAlignment: spaceBetween)
      Row
        Checkbox                    — "Allow Overlaps" toggle             L530–537
        Text                        — label
      FilledButton.icon             — "Add Task"                          L542–551
    SizedBox(height: 16)
    Expanded
      (empty) Center → Column
        Icon(Icons.calendar_month)
        Text "No fixed tasks yet."                                         L558–570
      (non-empty) ReorderableListView.builder                              L572–648
        Container
          ListTile
            title: Text (block.title)
            subtitle: Column
              Row
                Text (startTime – endTime)
                Container (durationString chip)
              [if category] Text (block.category)
            trailing: Icon(Icons.drag_handle_rounded)
```

**Edit dialog:** `showModalBottomSheet` (bottom sheet).  
Fields: Task Title · Start Time · End Time · Duration (minutes) · Category · Notes.  
Delete button in dialog header row (edit only). L150–482

---

### `fixed_schedule_setup_screen.dart` (FSSS)

Full standalone screen.

```
Scaffold(backgroundColor: transparent)
  LiquidBg
    Stack
      SafeArea
        Column
          Padding → Row (AppBar)                                          L800–831
            LiquidIconBtn (back)
            Text "FIXED SCHEDULE"
            LiquidIconBtn (check — save + complete)
          Padding → Container (glass header)                              L836–892
            "Set Your Fixed Schedule"
          SizedBox(height: 16)
          Expanded → Padding → Container (timeline glass panel)           L898–1025
            SingleChildScrollView (BouncingScrollPhysics)
              SizedBox(height: 24 * 60 px = 1440 px)
                Stack
                  ...List.generate(24) → Ruler lines (hour labels)       L930–959
                  Positioned → Glass ruler pillar                         L962–1003
                  ...items.asMap() → per item:
                    if isAdd  → _buildAddButton                           L724–781
                    elif isMini → _buildMiniBlock                         L670–722
                    else → _buildColoredBlock (with top/bottom tapes)     L520–668
```

**Edit dialog:** `showDialog` (AlertDialog).  
Fields: Block Name · Repeat days (dropdown) · Notes · Reminder (SwitchListTile) · Start Time · End Time.  
Delete in actions row. L199–399

---

## 3. Field-by-field edit dialog comparison

| Field | OP9 | FSSS |
|-------|-----|------|
| **Title label** | "Task Title" | "Block Name (e.g. Work)" |
| **Empty title** | blocked — "Title cannot be blank." (L412–415) | silent fallback to `'New Block'` (L360–362) |
| **Category** | editable `TextField` "Category (Optional)" (L370–380) | absent — always written as `''` |
| **Duration (minutes)** | numeric `TextField`; updates `endTime` on change (L345–368) | absent |
| **Duration display** | read-only `Text` "Duration: Xh Ym" (L334–343) | absent |
| **Repeat rule** | absent — hardcoded `'daily'` (ScheduleBlock L27) | `DropdownButtonFormField`: Daily / Weekdays / Weekends (L244–263) |
| **Reminder toggle** | absent | `SwitchListTile.adaptive` (L273–279) |
| **Color** | absent | auto-assigned from `_cycleColors` on first save (L373–375) |
| **Notes max lines** | `maxLines: 2` (L385) | `minLines: 2, maxLines: 3` (L265–270) |
| **Start/End pickers** | `InkWell` tap → `showTimePicker` inside sheet (L250–331) | `TextButton` tap → `showTimePicker` inside AlertDialog (L284–335) |
| **Delete placement** | `IconButton` in header row (L217–226) | `TextButton` in actions list (L339–352) |
| **Dialog type** | `showModalBottomSheet` (L184) | `showDialog` (L210) |

---

## 4. Validation differences

| Rule | OP9 | FSSS |
|------|-----|------|
| Title required | Yes — "Title cannot be blank." (L412–415) | No — defaults to `'New Block'` |
| Same start == end | Yes — "Start and end time cannot be the same." (L417–420) | No |
| Duration range (1–1439 min) | Yes — "Duration must be 1 to 1439 minutes." (L423–430) | No |
| Overlap detection | Yes — `overlapsWith()` check with `_allowOverlap` opt-out checkbox (L433–448) | No |

---

## 5. Sort order

| | OP9 | FSSS |
|-|-----|------|
| **Mechanism** | `ReorderableListView` — user drags; list order is stored as-is | Absolute pixel position: `top = item.start * 60.0` (L521); no drag-to-reorder |
| **Auto-sort** | None | Blocks appear at their clock position visually; list index order does not change |
| **New block insertion** | Appended to end of list (L457) | Inserted at `index + 1` (after the tapped add-button) (L377–384) |
| **Order persisted** | Positional (list index = display order) | Not positional; visual order determined by `start` hour |

---

## 6. Data model and serialized fields

### OP9 — `ScheduleBlock.toMap()` (L34–48)

```
templateId       String   "sched_${microsecondsSinceEpoch}"
title            String
routineType      String   always "fixed_schedule"
startTime        String   "HH:mm"
endTime          String   "HH:mm"
repeatRule       String   always "daily"
category         String   (user-editable, may be non-empty)
notes            String
isActive         bool     always true on create
createdAt        String   ISO-8601
updatedAt        String   ISO-8601
```

### FSSS — `FixedScheduleTemplate.toMap()` (routine_provider.dart L202–216)
_(Written after the conversion chain: `SetupBlockItem → FixedBlock.toTemplate() → FixedScheduleTemplate`)_

```
templateId            String   "add_${millisecondsSinceEpoch}" (from SetupBlockItem id)
title                 String
routineType           String   always "fixed_schedule"
startTime             String   "HH:mm"
endTime               String   "HH:mm"
repeatRule            String   "daily" | "weekly:1,2,3,4,5" | "weekly:6,7"
category              String   always "" (SetupBlockItem has no category field)
notes                 String
reminderEnabled       bool     (from SwitchListTile)
reminderOffsetMinutes int      default 5
isActive              bool     always true
createdAt             String   ISO-8601 (always DateTime.now() — no preservation)
updatedAt             String   ISO-8601 (always DateTime.now())
```

### Field delta

| Field | OP9 | FSSS |
|-------|-----|------|
| `category` | **user-settable** | always `''` |
| `repeatRule` | always `'daily'` | user-selectable (3 values) |
| `reminderEnabled` | **absent** | present |
| `reminderOffsetMinutes` | **absent** | present (default 5) |
| `createdAt` preservation | preserved on edit (L172) | always overwritten with `DateTime.now()` (`FixedBlock.toTemplate()` L285-298) |

---

## 7. Save paths

### OP9

**Call chain:**  
`_updateProvider()` (OP9 L142–148)  
→ `onboardingProvider.notifier.updateFixedSchedule(...)` (onboarding_provider.dart L202)  
→ `onboardingProvider.notifier.saveToFirestoreDebounced(9)` — 2-second debounce (L182–188)  
→ `userRepo.saveOnboardingData(state.toMap(), step: 9)` (user_repository.dart L297)

**Writes to four locations:**

| Path | Field written | Note |
|------|--------------|------|
| `/users/{uid}` (root doc) | `onboarding.fixedSchedule` | merge: true (user_repository.dart L310–315) |
| `/users/{uid}/onboarding/state` | full state including `fixedSchedule` | direct set (L317–326) |
| `/users/{uid}/profile/main` | full state including `fixedSchedule` | direct set (L328–337) |
| `/users/{uid}/identity_profile/main` | categories, goals, coach — **not** fixedSchedule | direct set (L339–348) |

The `_normalizeFixedSchedule` function (onboarding_provider.dart L10–19) enforces `repeatRule = 'daily'` on every write regardless of what the item contains.

### FSSS

**Call chain:**  
`_saveToProvider()` (FSSS L163–168)  
→ `routineProvider.notifier.setFixedBlocks(blocks)` (routine_provider.dart L1280–1283)  
→ `setFixedScheduleTemplates(...)` → `state.copyWith(...)` → `_saveDebounced()` — 2-second debounce (L1118–1127)  
→ `_repo.saveRoutine(state)` (routine_repository.dart L18–27)  
→ `_service.saveRoutine({...state.toMap()})` (firestore_service.dart L221–222)

**Writes to one location:**

| Path | Field written | Note |
|------|--------------|------|
| `/users/{uid}/routine/current` | `templates.fixed_schedule` (array) + `fixedScheduleSetUp` (bool) | direct set — replaces the whole doc |

`RoutineState.toMap()` (routine_provider.dart L659–678) nests the array at `templates.fixed_schedule`.

---

## 8. Duplicate write analysis

The two screens use **entirely separate Firestore paths**. At steady state there is no overlap:

- OP9 exclusively owns `/users/{uid}/onboarding/state.fixedSchedule`
- FSSS exclusively owns `/users/{uid}/routine/current.templates.fixed_schedule`

**One-time bridge — onboarding completion:**  
`completeOnboarding()` calls `_materializeOnboardingSelections()` (user_repository.dart L421–529), which reads the OP9 data from the onboarding map and **also writes it to** `/users/{uid}/routine/current.templates.fixed_schedule` (user_repository.dart L522–529). This is the only moment the two stores converge.

**Risk:** If the user edits FSSS _before_ completing onboarding, `completeOnboarding()` will overwrite those FSSS edits with the OP9 data. After onboarding is complete, FSSS edits are safe — they operate on `routine/current` only and nothing reads the onboarding path again.

---

## 9. Ranked differences — smallest impact first

| # | Difference | Impact |
|---|-----------|--------|
| 1 | Notes `maxLines`: OP9 = 2, FSSS = 3 (FSSS L265) | Cosmetic only |
| 2 | Dialog type: OP9 = `showModalBottomSheet`, FSSS = `showDialog` | UI chrome only; no data effect |
| 3 | Delete placement: OP9 = header IconButton (L217), FSSS = actions TextButton (L339) | UX only |
| 4 | Empty-state UI: OP9 shows icon + "No fixed tasks yet." (L557–570); FSSS shows 3 pre-placed add-buttons at 7:30/12:30/18:00 (L150–160) | UX only |
| 5 | Title label: "Task Title" vs "Block Name" | Copy only |
| 6 | `createdAt` preservation: OP9 preserves original on edit (L172), FSSS always stamps `DateTime.now()` (`FixedBlock.toTemplate()` routine_provider.dart L285) | Audit trail — history is lost in FSSS edits |
| 7 | `repeatRule` lockdown: OP9 forces `'daily'` via normalizer; FSSS allows weekday subsets | Functional — FSSS blocks skip non-matching days, OP9 blocks always appear |
| 8 | Reminder fields: OP9 has no `reminderEnabled`/`reminderOffsetMinutes`; FSSS has both | Feature gap — blocks created via OP9 never fire reminders |
| 9 | Category field: OP9 allows non-empty value; FSSS always writes `''` | Data loss if a user re-edits in FSSS a block created in OP9 with a category |
| 10 | Validation: OP9 enforces 4 rules including overlap detection; FSSS has none | Data quality — FSSS can persist blank-title and overlapping blocks silently |
| 11 | List ordering: OP9 = drag-reorder (list index); FSSS = visual timeline position (no index reorder) | Blocks created in OP9 keep user-defined order; FSSS order is implicit by clock time |
| 12 | Save path: OP9 → `/users/{uid}/onboarding/state`; FSSS → `/users/{uid}/routine/current` | Architectural — two independent stores; only `completeOnboarding()` bridges them |

---

## 10. Remaining risks and missing dependencies

| Risk | Severity | Detail |
|------|----------|--------|
| Pre-completion FSSS edit overwritten by `completeOnboarding` | Medium | user_repository.dart L522–529 overwrites `routine/current.templates.fixed_schedule` with onboarding data at completion time |
| FSSS never preserves `createdAt` | Low | `FixedBlock.toTemplate()` always uses `DateTime.now()` (routine_provider.dart L285), destroying the original timestamp |
| Category data loss on FSSS edit | Low | Any block whose `category` was set in OP9 will have `category` silently cleared to `''` if the user re-saves from FSSS |
| Overlap allowed in FSSS | Low | FSSS has no overlap check; two blocks with identical times can be saved without warning |
| Blank-title blocks in FSSS | Low | Empty title silently becomes `'New Block'` (FSSS L360–362); this title passes through the normalizer and produces a real task |
| `reminderOffsetMinutes` ignored for OP9 blocks | Low | `_candidatesForDate` reads `template.reminderOffsetMinutes` (routine_provider.dart L846–855) but OP9 blocks never write that field; it defaults to 5 min |
| Template ID collision unlikely but format diverges | Informational | OP9 uses `sched_${microseconds}` (L155), FSSS uses `add_${milliseconds}` (L380); no collision risk but grep/search fragile |

---

_Audit produced 2026-05-04. No Dart files were modified._
