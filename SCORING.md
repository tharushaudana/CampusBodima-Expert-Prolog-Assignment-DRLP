# CampusBodima — Scoring System Reference

This document explains how the recommendation engine scores and ranks boarding places. It covers every function involved, the weight definitions, formulas used, and where each piece lives in the codebase.

---

## 1. Architecture Overview

The system uses a **two-phase pipeline**:

```
User Criteria
     │
     ▼
┌─────────────────────────────────────┐
│  Phase 1 — Hard Filtering           │
│  filter_boardings/2  (rules.pl:77)  │
│  8 binary match rules               │
│  → Eliminates ineligible boardings  │
└────────────────┬────────────────────┘
                 │ List of qualifying IDs
                 ▼
┌─────────────────────────────────────┐
│  Phase 2 — Soft Scoring             │
│  score_boarding/3  (rules.pl:119)   │
│  4 weighted sub-scores → 0–100      │
│  → Ranks remaining boardings        │
└────────────────┬────────────────────┘
                 │ Sorted list (highest score first)
                 ▼
            Final Results
```

---

## 2. Master Scoring Formula

**File:** `rules.pl` — Line 124  
**Predicate:** `score_boarding(+ID, +Criteria, -Score)`

```prolog
score_boarding(ID, Criteria, Score) :-
    price_score(ID, Criteria, PScore),
    distance_score(ID, Criteria, DScore),
    facility_score(ID, Criteria, FScore),
    rating_score(ID, RScore),
    Score is PScore * 0.30 + DScore * 0.25 + FScore * 0.25 + RScore * 0.20.
```

### Weight Table

| Factor       | Weight | Contribution |
|--------------|--------|--------------|
| Price Match  | 0.30   | 30%          |
| Distance     | 0.25   | 25%          |
| Facilities   | 0.25   | 25%          |
| Rating       | 0.20   | 20%          |
| **Total**    | **1.00** | **100%**   |

Each sub-score is independently normalized to the range **0–100** before weighting.  
The final composite score is also in the range **0–100**, rounded to 1 decimal place.

---

## 3. Sub-Score Functions

### 3.1 Price Score — `price_score/3`

**File:** `rules.pl` — Lines 127–146  
**Weight:** 0.30 (30%)

Rewards boardings priced closest to the user's stated budget. Four cases are handled:

| Scenario | Formula | Notes |
|----------|---------|-------|
| No preference (`min=any`, `max=any`) | `Score = max(0, 100 − Price / 400)` | Cheaper is better; baseline range 0–40,000 LKR |
| Only max set | `Score = 100 − ((MaxPrice − Price) / MaxPrice × 50)` | Mild penalty for being under budget |
| Only min set | `Score = 100` if `Price ≥ MinPrice` | Binary pass/fail |
| **Both min and max set** _(primary case)_ | `Score = max(0, 100 − (Diff / Range × 100))` | **Midpoint-centred scoring** |

**Midpoint Formula (primary case):**

```
Midpoint = (MinPrice + MaxPrice) / 2
Range    = MaxPrice − MinPrice
Diff     = |ActualPrice − Midpoint|
Score    = max(0, 100 − (Diff / Range × 100))
```

**Example:**  
MinPrice = 10,000 | MaxPrice = 20,000 | Actual = 15,000  
→ Midpoint = 15,000 → Diff = 0 → Score = **100**

**Where weights are defined:** Implicitly in the midpoint formula. The further a price is from the centre of the budget, the lower the score — linearly down to 0.

---

### 3.2 Distance Score — `distance_score/3`

**File:** `rules.pl` — Lines 149–158  
**Weight:** 0.25 (25%)

Linearly rewards proximity to the university. Closer = higher score.

| Scenario | Formula |
|----------|---------|
| No max distance preference | `Score = max(0, 100 − (Distance / 10 × 100))` |
| Max distance specified | `Score = max(0, 100 − (Distance / MaxDistance × 100))` |

**Default range constant:** 10 km (defined at `rules.pl:154`)

**Behaviour:**
- 0 km → Score = 100
- At MaxDistance → Score = 0
- Every km farther reduces the score proportionally

---

### 3.3 Facility Score — `facility_score/3`

**File:** `rules.pl` — Lines 161–172  
**Weight:** 0.25 (25%)

Measures how well a boarding's amenities match what the user requested.

| Scenario | Formula |
|----------|---------|
| No facilities specified | `Score = min(100, FacilityCount × 10)` |
| Specific facilities requested | `Score = (MatchCount / TotalRequested) × 100` |

**Helper predicate:** `facility_in/2` — `rules.pl:174–175`  
Uses `include/3` and `member/2` to intersect the boarding's facility list with the requested list.

**Constants:**
- Points per unspecified facility: **10** (`rules.pl:167`)
- Maximum score cap: **100** via `min/2`

**Example:**  
User requests `[wifi, ac, parking]`. Boarding has `[wifi, ac, kitchen]`.  
→ MatchCount = 2, Total = 3 → Score = **66.7**

---

### 3.4 Rating Score — `rating_score/2`

**File:** `rules.pl` — Lines 178–180  
**Weight:** 0.20 (20%)

Directly converts the boarding's star rating (1.0–5.0) into a 0–100 score.

```prolog
rating_score(ID, Score) :-
    boarding(ID, _, _, _, _, _, _, _, _, _, _, _, Rating, _),
    Score is (Rating / 5.0) * 100.
```

| Stars | Score |
|-------|-------|
| 5.0   | 100   |
| 4.0   | 80    |
| 3.0   | 60    |
| 2.0   | 40    |
| 1.0   | 20    |

---

## 4. Final Ranking — `recommend/2`

**File:** `rules.pl` — Lines 186–199  
**Predicate:** `recommend(+Criteria, -SortedResults)`

```prolog
recommend(Criteria, SortedResults) :-
    filter_boardings(Criteria, IDs),
    maplist(score_and_pack(Criteria), IDs, Scored),
    sort(1, @>=, Scored, SortedPairs),
    maplist(unpack_scored, SortedPairs, SortedResults).
```

| Step | Predicate | Action |
|------|-----------|--------|
| 1 | `filter_boardings/2` | Eliminate ineligible boardings |
| 2 | `score_and_pack/3` | Compute `Score–ID` pairs for each qualifying boarding |
| 3 | `sort/4` | Sort pairs descending by score (`@>=`) |
| 4 | `unpack_scored/2` | Produce `boarding_result{id, score}` dicts |

**Score rounding** (`rules.pl:199`):
```prolog
RoundedScore is round(Score * 10) / 10
```
Final scores are displayed to **1 decimal place** (e.g., 94.3).

---

## 5. Phase 1 — Hard Filter Functions

**File:** `rules.pl` — Lines 77–110  
**Predicate:** `filter_boardings(+Criteria, -Results)`

A boarding must satisfy **all** of the following to proceed to scoring:

| Predicate | Line | Condition |
|-----------|------|-----------|
| `matches_available/1` | 70–71 | `Available = yes` |
| `matches_university/2` | 22–26 | Matches university or criteria is `any` |
| `matches_price/3` | 29–32 | `MinPrice ≤ Price ≤ MaxPrice` |
| `matches_distance/2` | 35–37 | `Distance ≤ MaxDistance` |
| `matches_room_type/2` | 40–44 | Matches room type or criteria is `any` |
| `matches_bathrooms/2` | 47–49 | `Bathrooms ≥ MinBathrooms` |
| `matches_gender/2` | 52–59 | Accepts the requested gender or is `any` |
| `matches_facilities/2` | 62–67 | All required facilities are present (subset check) |

These are strict binary rules — there is no partial credit. A boarding that fails any one filter is excluded entirely before scoring begins.

---

## 6. Where Weights Are Defined

All weight values are **literal constants** embedded in a single line of `rules.pl`:

```
File:  rules.pl
Line:  124
```

```prolog
Score is PScore * 0.30 + DScore * 0.25 + FScore * 0.25 + RScore * 0.20.
```

To change the importance of any factor, edit this one line. There are no separate configuration files or weight tables — the weights live exclusively here.

---

## 7. Scoring Constants Summary

| Constant | Value | File & Line | Purpose |
|----------|-------|-------------|---------|
| Price weight | `0.30` | `rules.pl:124` | 30% of final score |
| Distance weight | `0.25` | `rules.pl:124` | 25% of final score |
| Facility weight | `0.25` | `rules.pl:124` | 25% of final score |
| Rating weight | `0.20` | `rules.pl:124` | 20% of final score |
| Default price range | `40,000 LKR` | `rules.pl:133` | Normalization baseline |
| Default distance range | `10 km` | `rules.pl:154` | Normalization baseline |
| Points per facility (unspecified) | `10` | `rules.pl:167` | Bonus per amenity |
| Facility score cap | `100` | `rules.pl:167` | Upper bound via `min/2` |
| Rating scale max | `5.0` | `rules.pl:180` | Denominator for normalization |
| Rounding precision | `1 decimal` | `rules.pl:199` | `round(Score*10)/10` |

---

## 8. Input & Output Data Structures

### Input Criteria Dict

```prolog
criteria{
    university:     atom          % e.g. moratuwa, colombo, any
    min_price:      number | any  % minimum acceptable rent (LKR)
    max_price:      number | any  % maximum acceptable rent (LKR)
    max_distance:   number | any  % km from university
    room_type:      atom          % single | shared | any
    min_bathrooms:  number | any  % minimum bathrooms
    gender:         atom          % male | female | any
    facilities:     list          % e.g. [wifi, ac, parking]
}
```

### Output Result Dict

```prolog
boarding_result{
    id:    integer,        % boarding ID
    score: float           % composite score, 0–100 (1 d.p.)
}
```

---

## 9. Complete Request-to-Result Flow

```
POST /api/search  (interface.pl:79)
        │
        ▼
  build_criteria/2  — convert JSON to Prolog dict  (interface.pl:87)
        │
        ▼
  recommend/2  (rules.pl:189)
   ├─ filter_boardings/2  → qualifying IDs
   │      ├─ matches_available/1
   │      ├─ matches_university/2
   │      ├─ matches_price/3
   │      ├─ matches_distance/2
   │      ├─ matches_room_type/2
   │      ├─ matches_bathrooms/2
   │      ├─ matches_gender/2
   │      └─ matches_facilities/2
   │
   ├─ score_boarding/3  (per ID)
   │      ├─ price_score/3    × 0.30
   │      ├─ distance_score/3 × 0.25
   │      ├─ facility_score/3 × 0.25
   │      └─ rating_score/2   × 0.20
   │
   ├─ sort descending by score
   └─ unpack_scored → boarding_result dicts
        │
        ▼
  boarding_to_dict_with_score/2  (interface.pl)
        │
        ▼
  JSON response  {results: [...], count: N}
```

---

## 10. Key Deductive Reasoning Techniques Used

| Technique | Where Used |
|-----------|------------|
| **Backward chaining** | Prolog's native evaluation in all predicates |
| **Conjunctive constraint solving** | `findall/3` in `filter_boardings/2` (rules.pl:91–100) |
| **Subset reasoning** | `facility_in/2` + `include/3` for facility matching |
| **Weighted aggregation** | Four-factor formula in `score_boarding/3` |
| **Dynamic knowledge base** | `assert/1` in `add_boarding/2` (rules.pl:213–232) |
| **Closed-world assumption** | Absent facts treated as false (standard Prolog) |
