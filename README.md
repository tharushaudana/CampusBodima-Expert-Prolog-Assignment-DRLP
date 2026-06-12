# CampusBodima — Student Boarding Recommendation Expert System

> **Module:** Deductive Reasoning and Logic Programming  
> **Evaluation Date:** 2026-06-11  
> **Platform:** SWI-Prolog + Web Interface

---

## Overview

**CampusBodima** is a rule-based expert system built entirely in SWI-Prolog that recommends boarding places for university students in Sri Lanka. It uses **deductive reasoning** through Prolog's inference engine to filter and rank boarding options based on user-defined criteria.

The system serves a fully interactive, modern web interface via SWI-Prolog's built-in HTTP server — no external frameworks, databases, or runtimes required beyond SWI-Prolog itself.

---

## Features

- **Expert System Reasoning** — Prolog rules filter boardings by university, price range, distance, room type, bathrooms, gender preference, and required facilities
- **Weighted Scoring Algorithm** — Ranks matched boardings by a multi-factor relevance score
- **Web Interface** — Single-page application with four sections: Find, Browse, Add, About
- **30 Pre-loaded Boardings** — Realistic sample data across five Sri Lankan universities
- **Dynamic Facts** — New boarding places can be added at runtime via the web UI

---

## System Explanation

For a plain-English explanation of how the recommendation engine and filtering pipeline work, see **[SYSTEM.md](SYSTEM.md)**.

---

## File Structure

```
assignment/
├── boarding.pl      # Knowledge base — boarding facts and metadata
├── rules.pl         # Expert system rules — filtering, scoring, recommendations
├── interface.pl     # HTTP server — API endpoints and embedded web UI
└── start.pl         # Entry point — loads modules and starts the server
```

### `boarding.pl` — Knowledge Base

Defines the **schema** and **initial fact base** for all boarding places.

**Fact structure:**
```prolog
boarding(ID, Name, University, Location, Price, Distance,
         RoomType, MaxOccupants, Bathrooms, Facilities,
         Gender, Contact, Rating, Available)
```

| Field | Type | Description |
|---|---|---|
| `ID` | integer | Unique identifier |
| `Name` | string | Boarding place name |
| `University` | atom | Nearest university (`moratuwa`, `colombo`, etc.) |
| `Location` | string | Area/town name |
| `Price` | integer | Monthly rent in LKR |
| `Distance` | float | Distance from university in km |
| `RoomType` | atom | `single` or `shared` |
| `MaxOccupants` | integer | Maximum occupants per room |
| `Bathrooms` | integer | Number of bathrooms |
| `Facilities` | list | e.g. `[wifi, ac, furniture, kitchen]` |
| `Gender` | atom | `male`, `female`, or `any` |
| `Contact` | string | Phone number |
| `Rating` | float | Rating out of 5.0 |
| `Available` | atom | `yes` or `no` |

**30 sample boardings** are pre-loaded across:

| University | Atom | Sample Areas | Count |
|---|---|---|---|
| University of Moratuwa | `moratuwa` | Katubedda, Dehiwala, Mt. Lavinia, Panadura | 12 |
| University of Colombo | `colombo` | Colombo 03/07, Bambalapitiya, Wellawatte | 5 |
| University of Kelaniya | `kelaniya` | Kelaniya, Kiribathgoda, Kadawatha | 5 |
| University of Sri Jayewardenepura | `jayewardenepura` | Nugegoda, Maharagama, Kottawa | 4 |
| University of Peradeniya | `peradeniya` | Peradeniya, Kandy | 4 |

---

### `rules.pl` — Expert System Rules

Implements the **deductive reasoning** layer.

**Filter predicates** (each independently testable):

```prolog
matches_university(ID, University)
matches_price(ID, MinPrice, MaxPrice)
matches_distance(ID, MaxDistance)
matches_room_type(ID, RoomType)
matches_bathrooms(ID, MinBathrooms)
matches_gender(ID, Gender)
matches_facilities(ID, RequiredFacilities)   % subset check
matches_available(ID)
```

**Combined filter:**
```prolog
filter_boardings(+Criteria, -Results)
```
Applies all active criteria using `findall/3`. Any criterion set to `any` or `[]` is treated as "no constraint".

**Scoring algorithm** — each boarding is scored 0–100:

| Factor | Weight | Calculation |
|---|---|---|
| Price match | **30%** | Closeness to budget midpoint |
| Distance | **25%** | Proximity to university |
| Facilities | **25%** | % of requested facilities present |
| Rating | **20%** | Direct mapping from 1–5 scale |

**Main recommendation predicate:**
```prolog
recommend(+Criteria, -SortedResults)
```
Runs `filter_boardings`, scores each result with `score_boarding/3`, then sorts by descending score.

---

### `interface.pl` — HTTP Server & Web UI

Sets up SWI-Prolog's HTTP server and serves both API endpoints and the web frontend.

**Libraries used:**
```prolog
library(http/thread_httpd)   % Multi-threaded HTTP server
library(http/http_dispatch)  % URL routing
library(http/http_json)      % JSON request/response
library(http/http_parameters)% Query parameter parsing
```

**API Endpoints:**

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/` | Serves the single-page HTML UI |
| `GET` | `/api/boardings` | Returns all boarding facts as JSON |
| `GET` | `/api/universities` | Returns list of universities |
| `GET` | `/api/facilities` | Returns list of all facilities |
| `POST` | `/api/search` | Runs recommendation engine, returns scored results |
| `POST` | `/api/add` | Asserts a new boarding fact dynamically |

**Example POST /api/search request:**
```json
{
  "university": "moratuwa",
  "min_price": 10000,
  "max_price": 25000,
  "max_distance": 3.0,
  "room_type": "single",
  "min_bathrooms": 1,
  "gender": "any",
  "facilities": ["wifi", "furniture"]
}
```

**Web UI Sections:**
- **Find Boarding** — Filter panel + ranked result cards with relevance scores
- **All Boardings** — Browse all listings with live text search and university filter
- **Add Boarding** — Form to dynamically add new boarding places
- **About** — System description and algorithm explanation

---

### `start.pl` — Entry Point

```prolog
:- use_module(boarding).
:- use_module(rules).
:- use_module(interface).

:- initialization(start_server).
```

---

## Requirements

- **SWI-Prolog** version 8.0 or later
- Download: https://www.swi-prolog.org/Download.html

---

## How to Run

### 1. Open a terminal in the assignment directory

```bash
cd path/to/assignment
```

### 2. Start the server

```bash
swipl start.pl
```

Expected output:
```
========================================
  CampusBodima - Boarding Finder
  Starting server on port 8080
  Open: http://localhost:8080
========================================

% Started server at http://localhost:8080/
```

### 3. Open the web interface

Open your browser and navigate to:
```
http://localhost:8080
```

### Custom Port (optional)

```bash
swipl -g "start_server(9090)" start.pl
```

Then open `http://localhost:9090`.

### Stop the Server

Press `Ctrl+C` in the terminal.

---

## Usage Guide

### Finding a Boarding

1. On the **Find Boarding** tab (loaded by default with University of Moratuwa selected)
2. Set your filters:
   - **University** — defaults to University of Moratuwa
   - **Price Range** — enter min/max monthly rent in LKR
   - **Max Distance** — how far from university you're willing to go
   - **Room Type** — single or shared
   - **Min Bathrooms** — minimum number of bathrooms
   - **Gender** — male/female/any preference
   - **Facilities** — tick all the amenities you need
3. Click **Search Boardings**
4. Results appear ranked by relevance score (highest match first)
5. Use the sort dropdown to re-order by price, distance, or rating

### Browsing All Boardings

1. Click the **All Boardings** tab
2. Use the search box to filter by name or location
3. Use the university dropdown to narrow by institution

### Adding a New Boarding

1. Click the **Add Boarding** tab
2. Fill in the required fields (marked with *)
3. Select applicable facilities
4. Click **Add Boarding Place**
5. The new boarding is immediately available in searches

---

## Expert System Design — Deductive Reasoning

This system demonstrates key principles of **logic programming** and **deductive reasoning**:

### 1. Knowledge Representation
Facts about boarding places are stored as Prolog **predicates** (ground facts in the knowledge base), following the closed-world assumption.

### 2. Rule-Based Inference
Each filter is a Prolog **rule** — a logical statement that succeeds or fails based on the current fact base. The system uses **backward chaining** (Prolog's natural evaluation strategy) to find all boardings satisfying the query.

### 3. Constraint Satisfaction
`filter_boardings/2` uses `findall/3` to collect all individuals satisfying a conjunction of constraints — a direct application of deductive reasoning over the knowledge base.

### 4. Subset Reasoning
Facility matching uses `subset/2`, demonstrating logical subset relationships: a boarding is valid only if its facility list *subsumes* the user's required facilities.

### 5. Dynamic Knowledge Base
`add_boarding/2` uses `assert/1` to extend the knowledge base at runtime, demonstrating Prolog's support for dynamic facts.

---

## Price Reference (LKR/month)

| Category | Range |
|---|---|
| Budget | Rs. 8,000 – 15,000 |
| Mid-range | Rs. 15,000 – 25,000 |
| Premium | Rs. 25,000 – 40,000 |

---

## Available Facilities

`wifi` · `ac` · `furniture` · `kitchen` · `parking` · `laundry` · `hot_water` · `study_room` · `cctv` · `generator` · `meals`
