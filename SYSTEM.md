# How CampusBodima Works — System Explanation

This document explains the reasoning behind CampusBodima's recommendation engine in plain English. No prior Prolog knowledge is assumed.

---

## The Big Picture

When a student submits search criteria, the system runs a **two-phase pipeline**:

```
Student Criteria
      │
      ▼
┌─────────────────────────────────┐
│  PHASE 1 — FILTER (Hard Rules)  │  ← Prolog deductive reasoning
│  Eliminate boardings that       │
│  cannot possibly match          │
└────────────────┬────────────────┘
                 │  Surviving candidates
                 ▼
┌─────────────────────────────────┐
│  PHASE 2 — SCORE (Soft Rank)    │  ← Weighted scoring formula
│  Rank remaining boardings       │
│  by how well they fit           │
└────────────────┬────────────────┘
                 │  Sorted by score (highest first)
                 ▼
         Results shown on screen
```

Phase 1 is **strict** — a boarding either passes or it doesn't.  
Phase 2 is **flexible** — it measures *how good* a match is, not just yes/no.

---

## Phase 1 — Filtering with Hard Rules

Each filter is a Prolog **rule** (predicate) that checks one condition. A boarding must pass **all** active rules to survive.

### The Rules

| Rule | What it checks | Logic |
|---|---|---|
| `matches_university` | Boarding must be near the chosen university | Exact match, or skip if "Any" selected |
| `matches_price` | Price must fall within the given range | `MinPrice ≤ Price ≤ MaxPrice` |
| `matches_distance` | Must not be farther than max distance | `Distance ≤ MaxDistance` |
| `matches_room_type` | Must be single or shared as requested | Exact match, or skip if "Any" |
| `matches_bathrooms` | Must have at least the requested bathrooms | `Bathrooms ≥ MinBathrooms` |
| `matches_gender` | Must accept the student's gender | Boarding is `male`/`female`/`any`; passes if boarding is `any` OR matches student |
| `matches_facilities` | Must have **all** requested facilities | Subset check: every requested item must exist in the boarding's list |
| `matches_available` | Must currently be available | `Available = yes` |

### How Prolog Runs This

The predicate `filter_boardings/2` uses `findall/3` — a core Prolog construct that asks:

> *"Find all boarding IDs for which every single one of the above rules succeeds."*

```prolog
findall(ID, (
    matches_available(ID),
    matches_university(ID, University),
    matches_price(ID, MinPrice, MaxPrice),
    matches_distance(ID, MaxDistance),
    matches_room_type(ID, RoomType),
    matches_bathrooms(ID, MinBathrooms),
    matches_gender(ID, Gender),
    matches_facilities(ID, Facilities)
), Results).
```

This is **deductive reasoning**: from known facts (the boarding database) and rules, Prolog *deduces* which boardings are valid candidates. Any boarding that causes even one rule to **fail** is automatically excluded — Prolog's backtracking ensures this.

---

## Phase 2 — Scoring with Weighted Factors

### Why Not Just Use Strict Rules for Everything?

Strict rules give a **binary answer** (pass/fail). This creates a problem:

- Imagine you set max price = 20,000 LKR. A boarding at 20,001 LKR is treated identically to one at 50,000 LKR — both fail. But a student might actually prefer the 20,001 over a terrible 15,000 one.
- Two boardings that both pass all filters might be very different in quality — strict rules can't tell you which is *better*.

**Weights solve this** by turning each factor into a continuous score (0–100) and combining them. This models real-world decision-making:

> A student might accept slightly higher rent if the place is 5 minutes' walk instead of 40.

### The Weight Assignments

```
Final Score = (PriceScore × 0.30)
            + (DistanceScore × 0.25)
            + (FacilityScore × 0.25)
            + (RatingScore   × 0.20)
```

| Factor | Weight | Reasoning |
|---|---|---|
| **Price** | 30% | Affordability is the top concern for most students on a fixed budget |
| **Distance** | 25% | Daily commute time directly impacts study, health, and punctuality |
| **Facilities** | 25% | WiFi, study rooms, and kitchen affect day-to-day productivity and comfort |
| **Rating** | 20% | Real feedback from past tenants — important but not always available or recent |

The weights sum to **100%**, ensuring the final score stays in the 0–100 range.

### How Each Sub-Score is Calculated

#### Price Score (30%)

Rewards boardings whose price falls near the **centre** of your range. The closer to the midpoint, the higher the score.

```
Midpoint = (MinPrice + MaxPrice) / 2
Range    = MaxPrice - MinPrice
Diff     = |ActualPrice - Midpoint|

PriceScore = max(0,  100 - (Diff / Range × 100))
```

- Price exactly at midpoint → **100**
- Price at the edge of your range → **~0**
- Price outside range → boarding was already eliminated in Phase 1

#### Distance Score (25%)

Rewards proximity. Closer = higher score, linearly.

```
DistanceScore = max(0,  100 - (Distance / MaxDistance × 100))
```

- 0 km (on campus) → **100**
- Exactly at your maximum distance → **0**
- Beyond max distance → already eliminated in Phase 1

#### Facility Score (25%)

Measures what fraction of your *requested* facilities the boarding actually has.

```
FacilityScore = (Number of your requested facilities present) / (Total you requested) × 100
```

- All requested facilities present → **100**
- Half present → **50**
- None present → **0** (but this can't happen — Phase 1 already requires all to be present if you specified any)

> **Note:** If you request no specific facilities, the score instead rewards boardings with *more* facilities in general (each facility adds 10 points, capped at 100).

#### Rating Score (20%)

A direct linear mapping from the 1–5 star rating.

```
RatingScore = (Rating / 5.0) × 100
```

- 5.0 stars → **100**
- 4.0 stars → **80**
- 3.0 stars → **60**
- 1.0 star  → **20**

---

## Concrete Example — Step by Step

### The Student's Search

> A student at **University of Moratuwa** is looking for a room with:
> - Price range: **LKR 10,000 – 20,000**
> - Max distance: **3 km**
> - Required facilities: **WiFi and Kitchen**
> - Gender: Any
> - Room type: Any

### The Candidate Boardings

Three boardings exist near Moratuwa. Let's see what happens to each.

| # | Name | Price | Distance | Facilities | Rating |
|---|---|---|---|---|---|
| A | Sunshine Boarding | 15,000 | 0.3 km | wifi, furniture, kitchen, laundry | 4.2 |
| B | Lake View Rooms | 22,000 | 1.2 km | wifi, ac, furniture, kitchen, parking, hot_water | 4.5 |
| C | K-Zone Student Inn | 9,000 | 0.2 km | wifi, furniture | 3.2 |

---

### Phase 1 — Filter

Each boarding is tested against every rule:

**Boarding A — Sunshine Boarding**
```
✔ matches_university   → moratuwa ✓
✔ matches_price        → 10,000 ≤ 15,000 ≤ 20,000 ✓
✔ matches_distance     → 0.3 ≤ 3.0 ✓
✔ matches_room_type    → any (skip) ✓
✔ matches_bathrooms    → any (skip) ✓
✔ matches_gender       → any (skip) ✓
✔ matches_facilities   → {wifi, kitchen} ⊆ {wifi, furniture, kitchen, laundry} ✓
✔ matches_available    → yes ✓

RESULT: PASSES → enters Phase 2
```

**Boarding B — Lake View Rooms**
```
✔ matches_university   → moratuwa ✓
✗ matches_price        → 10,000 ≤ 22,000 ≤ 20,000 ✗  ← FAILS HERE

RESULT: ELIMINATED — never reaches scoring
```

**Boarding C — K-Zone Student Inn**
```
✔ matches_university   → moratuwa ✓
✗ matches_price        → 10,000 ≤ 9,000 ← FAILS HERE (below minimum)

RESULT: ELIMINATED — never reaches scoring
```

> Only **Boarding A** survives. Even though B had better facilities and C was closest, they violated hard constraints and are disqualified entirely.

---

### Phase 2 — Score Boarding A

Now the system calculates how *well* Boarding A matches the criteria.

#### Step 1 — Price Score (weight: 30%)

```
MinPrice  = 10,000
MaxPrice  = 20,000
Midpoint  = (10,000 + 20,000) / 2 = 15,000
Range     = 20,000 - 10,000       = 10,000
Price     = 15,000
Diff      = |15,000 - 15,000|     = 0

PriceScore = 100 - (0 / 10,000 × 100) = 100
Contribution = 100 × 0.30 = 30.0
```

Price is exactly at the midpoint of the budget → perfect score.

#### Step 2 — Distance Score (weight: 25%)

```
Distance    = 0.3 km
MaxDistance = 3.0 km

DistanceScore = 100 - (0.3 / 3.0 × 100)
              = 100 - 10
              = 90
Contribution  = 90 × 0.25 = 22.5
```

Very close to university (only 0.3km of the allowed 3km) → high score.

#### Step 3 — Facility Score (weight: 25%)

```
Requested       = [wifi, kitchen]           (2 items)
Boarding has    = [wifi, furniture, kitchen, laundry]
Matched         = [wifi, kitchen]           (2 items found)

FacilityScore   = (2 / 2) × 100 = 100
Contribution    = 100 × 0.25 = 25.0
```

All requested facilities are present → perfect score.

#### Step 4 — Rating Score (weight: 20%)

```
Rating      = 4.2 out of 5.0

RatingScore = (4.2 / 5.0) × 100 = 84
Contribution = 84 × 0.20 = 16.8
```

#### Step 5 — Final Score

```
Final Score = 30.0  (price)
            + 22.5  (distance)
            + 25.0  (facilities)
            + 16.8  (rating)
            ──────
            = 94.3%
```

**Sunshine Boarding is shown to the student with a 94.3% match.**

---

## Prolog Code Trace

When `recommend(Criteria, Results)` is called, here is the exact call chain:

```
recommend(Criteria, SortedResults)
│
├── filter_boardings(Criteria, IDs)
│   ├── get_criterion(...)        ← extract each filter value from Criteria
│   └── findall(ID, (
│           matches_available(ID),
│           matches_university(ID, University),
│           matches_price(ID, MinPrice, MaxPrice),
│           matches_distance(ID, MaxDistance),
│           matches_room_type(ID, RoomType),
│           matches_bathrooms(ID, MinBathrooms),
│           matches_gender(ID, Gender),
│           matches_facilities(ID, Facilities)
│       ), IDs)
│
├── maplist(score_and_pack(Criteria), IDs, Scored)
│   └── For each ID:
│       score_boarding(ID, Criteria, Score)
│       ├── price_score(ID, Criteria, PScore)
│       ├── distance_score(ID, Criteria, DScore)
│       ├── facility_score(ID, Criteria, FScore)
│       └── rating_score(ID, RScore)
│           Score = PScore×0.30 + DScore×0.25 + FScore×0.25 + RScore×0.20
│
└── sort(1, @>=, Scored, SortedPairs)   ← sort descending by score
```

Prolog evaluates each `matches_*` predicate using **backward chaining**: it starts from the goal and works back through the rules and facts in `boarding.pl` to determine whether the goal is provable. If any single condition fails, Prolog **backtracks** and tries the next boarding ID.

---

## Dynamic Knowledge Base

The system uses Prolog's **dynamic predicates** to support adding new boardings at runtime.

```prolog
:- dynamic boarding/14.   ← tells Prolog this fact can change at runtime
```

When a student submits a new boarding via the web form:

1. `add_boarding/2` is called with the form data
2. It reads and increments the `next_id` counter (also dynamic)
3. It calls `assert/1` to **permanently add** a new `boarding/14` fact to the knowledge base
4. All subsequent calls to `recommend/2` or `all_boardings/1` will automatically include this new fact

This demonstrates Prolog's **open-world extension** capability: the knowledge base is not fixed at compile time — it grows as new information is asserted.

**Closed-World Assumption**: Prolog assumes that anything not provable from the current knowledge base is false. If a boarding is not in the database, it simply doesn't exist — there is no "unknown". This is why the `matches_available` check works: if `Available = no`, the rule fails and that boarding is treated as if it isn't there.

---

## Summary

| Aspect | Mechanism | Where in Code |
|---|---|---|
| Knowledge representation | `boarding/14` facts | `boarding.pl` |
| Hard filtering | Prolog rules + `findall/3` | `rules.pl` — `filter_boardings/2` |
| Subset reasoning | `subset/2` predicate | `rules.pl` — `matches_facilities/2` |
| Soft ranking | Weighted score formula | `rules.pl` — `score_boarding/3` |
| Recommendation | Filter → Score → Sort | `rules.pl` — `recommend/2` |
| Web interface | SWI-Prolog HTTP server | `interface.pl` |
| Dynamic facts | `assert/1` / `retract/1` | `rules.pl` — `add_boarding/2` |
