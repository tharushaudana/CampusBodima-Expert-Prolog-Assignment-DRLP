% ============================================================
% interface.pl - Web Server & UI for CampusBodima
% CampusBodima Expert System
% ============================================================

:- module(interface, [start_server/0, start_server/1]).

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_header)).
:- use_module(boarding).
:- use_module(rules).

% ============================================================
% HTTP Route Handlers
% ============================================================

:- http_handler(root(.), serve_homepage, []).
:- http_handler(root('api/boardings'), api_boardings, []).
:- http_handler(root('api/universities'), api_universities, []).
:- http_handler(root('api/facilities'), api_facilities, []).
:- http_handler(root('api/search'), api_search, []).
:- http_handler(root('api/add'), api_add, []).

% ============================================================
% Server Start
% ============================================================

start_server :-
    start_server(8080).

start_server(Port) :-
    format('~n========================================~n'),
    format('  CampusBodima - Boarding Finder~n'),
    format('  Starting server on port ~w~n', [Port]),
    format('  Open: http://localhost:~w~n', [Port]),
    format('========================================~n~n'),
    http_server(http_dispatch, [port(Port)]).

% ============================================================
% API: Get All Boardings
% ============================================================

api_boardings(_Request) :-
    all_boardings(Boardings),
    length(Boardings, Count),
    reply_json_dict(_{results: Boardings, count: Count}).

% ============================================================
% API: Get Universities
% ============================================================

api_universities(_Request) :-
    all_universities(UniAtoms),
    maplist(uni_to_dict, UniAtoms, Unis),
    reply_json_dict(_{universities: Unis}).

uni_to_dict(Atom, _{id: Atom, name: Name}) :-
    university_name(Atom, Name).

% ============================================================
% API: Get Facilities
% ============================================================

api_facilities(_Request) :-
    all_facilities(FacAtoms),
    maplist(fac_to_dict, FacAtoms, Facs),
    reply_json_dict(_{facilities: Facs}).

fac_to_dict(Atom, _{id: Atom, label: Label}) :-
    facility_label(Atom, Label).

% ============================================================
% API: Search / Recommend Boardings
% ============================================================

api_search(Request) :-
    http_read_json_dict(Request, Input),
    build_criteria(Input, Criteria),
    recommend(Criteria, ScoredResults),
    maplist(build_result_dict, ScoredResults, ResultDicts),
    length(ResultDicts, Count),
    reply_json_dict(_{results: ResultDicts, count: Count}).

build_criteria(Input, Criteria) :-
    % Extract and convert each field from JSON input
    get_or_default(Input, university, any, UniRaw),
    convert_atom(UniRaw, University),
    get_or_default(Input, min_price, any, MinPriceRaw),
    convert_number(MinPriceRaw, MinPrice),
    get_or_default(Input, max_price, any, MaxPriceRaw),
    convert_number(MaxPriceRaw, MaxPrice),
    get_or_default(Input, max_distance, any, MaxDistRaw),
    convert_number(MaxDistRaw, MaxDistance),
    get_or_default(Input, room_type, any, RoomRaw),
    convert_atom(RoomRaw, RoomType),
    get_or_default(Input, min_bathrooms, any, BathRaw),
    convert_number(BathRaw, MinBathrooms),
    get_or_default(Input, gender, any, GenderRaw),
    convert_atom(GenderRaw, Gender),
    get_or_default(Input, facilities, [], FacRaw),
    convert_facility_list(FacRaw, Facilities),
    Criteria = criteria{
        university: University,
        min_price: MinPrice,
        max_price: MaxPrice,
        max_distance: MaxDistance,
        room_type: RoomType,
        min_bathrooms: MinBathrooms,
        gender: Gender,
        facilities: Facilities
    }.

get_or_default(Dict, Key, Default, Value) :-
    (   is_dict(Dict),
        get_dict(Key, Dict, V),
        V \== null,
        V \== @(null),
        V \== ""
    ->  Value = V
    ;   Value = Default
    ).

convert_atom(any, any) :- !.
convert_atom("", any) :- !.
convert_atom(Value, Atom) :-
    (atom(Value) -> Atom = Value ; atom_string(Atom, Value)).

convert_number(any, any) :- !.
convert_number("", any) :- !.
convert_number(Value, Number) :-
    (number(Value) -> Number = Value ; atom_number(Value, Number)).

convert_facility_list([], []) :- !.
convert_facility_list(List, Atoms) :-
    is_list(List),
    maplist(convert_atom, List, Atoms).

build_result_dict(boarding_result{id: ID, score: Score}, Dict) :-
    boarding_to_dict_with_score(ID, Score, Dict).

% ============================================================
% API: Add New Boarding
% ============================================================

api_add(Request) :-
    http_read_json_dict(Request, Input),
    build_boarding_data(Input, Data),
    (   add_boarding(Data, NewID)
    ->  boarding_to_dict(NewID, Dict),
        reply_json_dict(_{success: true, message: "Boarding added successfully", boarding: Dict})
    ;   reply_json_dict(_{success: false, message: "Failed to add boarding"})
    ).

build_boarding_data(Input, Data) :-
    get_dict(name, Input, Name),
    get_or_default(Input, university, moratuwa, UniRaw),
    convert_atom(UniRaw, University),
    get_dict(location, Input, Location),
    get_dict(price, Input, PriceRaw),
    convert_number(PriceRaw, Price),
    get_dict(distance, Input, DistRaw),
    convert_number(DistRaw, Distance),
    get_or_default(Input, room_type, single, RoomRaw),
    convert_atom(RoomRaw, RoomType),
    get_or_default(Input, max_occupants, 1, MaxOccRaw),
    convert_number(MaxOccRaw, MaxOccupants),
    get_or_default(Input, bathrooms, 1, BathRaw),
    convert_number(BathRaw, Bathrooms),
    get_or_default(Input, facilities, [], FacRaw),
    convert_facility_list(FacRaw, Facilities),
    get_or_default(Input, gender, any, GenderRaw),
    convert_atom(GenderRaw, Gender),
    get_dict(contact, Input, Contact),
    get_or_default(Input, rating, 3.0, RatingRaw),
    convert_number(RatingRaw, Rating),
    Data = boarding_data{
        name: Name,
        university: University,
        location: Location,
        price: Price,
        distance: Distance,
        room_type: RoomType,
        max_occupants: MaxOccupants,
        bathrooms: Bathrooms,
        facilities: Facilities,
        gender: Gender,
        contact: Contact,
        rating: Rating
    }.

% ============================================================
% Serve Homepage - Embedded HTML/CSS/JS
% ============================================================

serve_homepage(_Request) :-
    homepage_html(HTML),
    format('Content-Type: text/html~n~n'),
    format('~w', [HTML]).

homepage_html(HTML) :-
    HTML = '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CampusBodima - Student Boarding Finder</title>
    <style>
        /* ============================================================
           CSS Variables & Reset
           ============================================================ */
        :root {
            --primary: #1a56db;
            --primary-light: #e8effc;
            --primary-dark: #1344b0;
            --accent: #059669;
            --accent-light: #d1fae5;
            --bg: #f0f4f8;
            --card-bg: #ffffff;
            --text: #1e293b;
            --text-light: #64748b;
            --border: #e2e8f0;
            --shadow: 0 1px 3px rgba(0,0,0,0.08), 0 1px 2px rgba(0,0,0,0.06);
            --shadow-md: 0 4px 6px rgba(0,0,0,0.07), 0 2px 4px rgba(0,0,0,0.06);
            --shadow-lg: 0 10px 15px rgba(0,0,0,0.1), 0 4px 6px rgba(0,0,0,0.05);
            --radius: 12px;
            --radius-sm: 8px;
            --danger: #dc2626;
            --warning: #f59e0b;
            --star: #f59e0b;
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            background: var(--bg);
            color: var(--text);
            line-height: 1.6;
            min-height: 100vh;
        }

        /* ============================================================
           Header
           ============================================================ */
        .header {
            background: linear-gradient(135deg, var(--primary) 0%, #2563eb 50%, var(--primary-dark) 100%);
            color: white;
            padding: 0;
            box-shadow: var(--shadow-lg);
            position: sticky;
            top: 0;
            z-index: 100;
        }

        .header-content {
            max-width: 1400px;
            margin: 0 auto;
            padding: 18px 24px 0;
        }

        .header-top {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 16px;
        }

        .logo {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .logo-icon {
            width: 42px;
            height: 42px;
            background: rgba(255,255,255,0.2);
            border-radius: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 22px;
            backdrop-filter: blur(10px);
        }

        .logo h1 {
            font-size: 24px;
            font-weight: 700;
            letter-spacing: -0.5px;
        }

        .logo p {
            font-size: 13px;
            opacity: 0.85;
            font-weight: 400;
        }

        .header-stats {
            display: flex;
            gap: 20px;
            font-size: 13px;
            opacity: 0.9;
        }

        .header-stats span {
            background: rgba(255,255,255,0.15);
            padding: 4px 12px;
            border-radius: 20px;
            backdrop-filter: blur(10px);
        }

        /* Navigation Tabs */
        .nav-tabs {
            display: flex;
            gap: 4px;
        }

        .nav-tab {
            padding: 10px 24px;
            background: transparent;
            border: none;
            color: rgba(255,255,255,0.7);
            font-size: 14px;
            font-weight: 500;
            cursor: pointer;
            border-radius: 8px 8px 0 0;
            transition: all 0.2s;
            position: relative;
        }

        .nav-tab:hover {
            color: white;
            background: rgba(255,255,255,0.1);
        }

        .nav-tab.active {
            color: var(--primary);
            background: var(--bg);
            font-weight: 600;
        }

        /* ============================================================
           Main Content
           ============================================================ */
        .main {
            max-width: 1400px;
            margin: 0 auto;
            padding: 24px;
        }

        .tab-content { display: none; }
        .tab-content.active { display: block; }

        /* ============================================================
           Find Boarding Tab
           ============================================================ */
        .search-layout {
            display: grid;
            grid-template-columns: 320px 1fr;
            gap: 24px;
            align-items: start;
        }

        /* Filter Panel */
        .filter-panel {
            background: var(--card-bg);
            border-radius: var(--radius);
            box-shadow: var(--shadow);
            padding: 24px;
            position: sticky;
            top: 100px;
        }

        .filter-panel h3 {
            font-size: 16px;
            font-weight: 600;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 8px;
            color: var(--primary);
        }

        .filter-group {
            margin-bottom: 18px;
        }

        .filter-group label {
            display: block;
            font-size: 13px;
            font-weight: 600;
            color: var(--text);
            margin-bottom: 6px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .filter-group select,
        .filter-group input[type="number"] {
            width: 100%;
            padding: 9px 12px;
            border: 1.5px solid var(--border);
            border-radius: var(--radius-sm);
            font-size: 14px;
            color: var(--text);
            background: white;
            transition: border-color 0.2s;
        }

        .filter-group select:focus,
        .filter-group input:focus {
            outline: none;
            border-color: var(--primary);
            box-shadow: 0 0 0 3px var(--primary-light);
        }

        .price-range {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 8px;
        }

        .facilities-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 6px;
        }

        .facility-check {
            display: flex;
            align-items: center;
            gap: 6px;
            font-size: 12.5px;
            cursor: pointer;
            padding: 4px;
            border-radius: 4px;
            transition: background 0.15s;
        }

        .facility-check:hover { background: var(--primary-light); }

        .facility-check input[type="checkbox"] {
            accent-color: var(--primary);
            width: 15px;
            height: 15px;
        }

        .btn-search {
            width: 100%;
            padding: 12px;
            background: var(--primary);
            color: white;
            border: none;
            border-radius: var(--radius-sm);
            font-size: 15px;
            font-weight: 600;
            cursor: pointer;
            transition: background 0.2s, transform 0.1s;
            margin-top: 8px;
        }

        .btn-search:hover { background: var(--primary-dark); }
        .btn-search:active { transform: scale(0.98); }

        .btn-reset {
            width: 100%;
            padding: 10px;
            background: transparent;
            color: var(--text-light);
            border: 1.5px solid var(--border);
            border-radius: var(--radius-sm);
            font-size: 13px;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.2s;
            margin-top: 8px;
        }

        .btn-reset:hover {
            border-color: var(--danger);
            color: var(--danger);
        }

        /* Results Area */
        .results-area {
            min-height: 400px;
        }

        .results-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 16px;
        }

        .results-header h3 {
            font-size: 18px;
            font-weight: 600;
        }

        .results-count {
            color: var(--text-light);
            font-size: 14px;
        }

        .sort-select {
            padding: 8px 12px;
            border: 1.5px solid var(--border);
            border-radius: var(--radius-sm);
            font-size: 13px;
            background: white;
        }

        /* Boarding Cards */
        .cards-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
            gap: 18px;
        }

        .boarding-card {
            background: var(--card-bg);
            border-radius: var(--radius);
            box-shadow: var(--shadow);
            overflow: hidden;
            transition: transform 0.2s, box-shadow 0.2s;
        }

        .boarding-card:hover {
            transform: translateY(-3px);
            box-shadow: var(--shadow-lg);
        }

        .card-header {
            background: linear-gradient(135deg, var(--primary-light), #dbeafe);
            padding: 16px 18px;
            display: flex;
            justify-content: space-between;
            align-items: start;
        }

        .card-header h4 {
            font-size: 16px;
            font-weight: 600;
            color: var(--primary-dark);
            margin-bottom: 2px;
        }

        .card-location {
            font-size: 13px;
            color: var(--text-light);
        }

        .card-score {
            background: var(--accent);
            color: white;
            padding: 4px 10px;
            border-radius: 20px;
            font-size: 13px;
            font-weight: 700;
            white-space: nowrap;
        }

        .card-body { padding: 16px 18px; }

        .card-meta {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 10px;
            margin-bottom: 14px;
        }

        .meta-item {
            display: flex;
            align-items: center;
            gap: 6px;
            font-size: 13px;
        }

        .meta-icon {
            width: 28px;
            height: 28px;
            background: var(--primary-light);
            border-radius: 6px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 14px;
            flex-shrink: 0;
        }

        .meta-label {
            color: var(--text-light);
            font-size: 11px;
            display: block;
        }

        .meta-value {
            font-weight: 600;
            font-size: 13px;
        }

        .card-price {
            font-size: 22px;
            font-weight: 700;
            color: var(--accent);
        }

        .card-price span {
            font-size: 13px;
            font-weight: 400;
            color: var(--text-light);
        }

        .card-facilities {
            display: flex;
            flex-wrap: wrap;
            gap: 5px;
            margin-top: 12px;
            padding-top: 12px;
            border-top: 1px solid var(--border);
        }

        .facility-tag {
            background: var(--primary-light);
            color: var(--primary);
            padding: 3px 8px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: 500;
        }

        .card-footer {
            padding: 12px 18px;
            border-top: 1px solid var(--border);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .card-rating {
            display: flex;
            align-items: center;
            gap: 4px;
            font-size: 14px;
        }

        .stars { color: var(--star); }

        .card-contact {
            display: flex;
            align-items: center;
            gap: 6px;
            color: var(--primary);
            font-weight: 600;
            font-size: 13px;
        }

        .badge {
            display: inline-block;
            padding: 2px 8px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: 600;
            text-transform: uppercase;
        }

        .badge-single { background: #dbeafe; color: #1e40af; }
        .badge-shared { background: #fef3c7; color: #92400e; }
        .badge-male { background: #dbeafe; color: #1e40af; }
        .badge-female { background: #fce7f3; color: #9d174d; }
        .badge-any { background: #d1fae5; color: #065f46; }

        /* Empty State */
        .empty-state {
            text-align: center;
            padding: 60px 20px;
            color: var(--text-light);
        }

        .empty-state .icon { font-size: 48px; margin-bottom: 16px; }
        .empty-state h3 { font-size: 18px; margin-bottom: 8px; color: var(--text); }
        .empty-state p { font-size: 14px; }

        /* ============================================================
           All Boardings Tab
           ============================================================ */
        .browse-header {
            display: flex;
            gap: 12px;
            margin-bottom: 20px;
            flex-wrap: wrap;
        }

        .search-input {
            flex: 1;
            min-width: 250px;
            padding: 10px 16px;
            border: 1.5px solid var(--border);
            border-radius: var(--radius-sm);
            font-size: 14px;
        }

        .search-input:focus {
            outline: none;
            border-color: var(--primary);
            box-shadow: 0 0 0 3px var(--primary-light);
        }

        /* ============================================================
           Add Boarding Tab
           ============================================================ */
        .add-form {
            max-width: 800px;
            margin: 0 auto;
            background: var(--card-bg);
            border-radius: var(--radius);
            box-shadow: var(--shadow);
            padding: 32px;
        }

        .add-form h3 {
            font-size: 20px;
            font-weight: 600;
            margin-bottom: 24px;
            color: var(--primary);
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .form-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 18px;
        }

        .form-group {
            display: flex;
            flex-direction: column;
        }

        .form-group.full-width {
            grid-column: 1 / -1;
        }

        .form-group label {
            font-size: 13px;
            font-weight: 600;
            margin-bottom: 6px;
            color: var(--text);
        }

        .form-group input,
        .form-group select {
            padding: 10px 12px;
            border: 1.5px solid var(--border);
            border-radius: var(--radius-sm);
            font-size: 14px;
        }

        .form-group input:focus,
        .form-group select:focus {
            outline: none;
            border-color: var(--primary);
            box-shadow: 0 0 0 3px var(--primary-light);
        }

        .form-facilities {
            grid-column: 1 / -1;
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 8px;
        }

        .btn-submit {
            grid-column: 1 / -1;
            padding: 14px;
            background: var(--accent);
            color: white;
            border: none;
            border-radius: var(--radius-sm);
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: background 0.2s;
            margin-top: 8px;
        }

        .btn-submit:hover { background: #047857; }

        /* ============================================================
           About Tab
           ============================================================ */
        .about-content {
            max-width: 800px;
            margin: 0 auto;
        }

        .about-card {
            background: var(--card-bg);
            border-radius: var(--radius);
            box-shadow: var(--shadow);
            padding: 32px;
            margin-bottom: 20px;
        }

        .about-card h3 {
            font-size: 18px;
            font-weight: 600;
            margin-bottom: 12px;
            color: var(--primary);
        }

        .about-card p, .about-card li {
            font-size: 14px;
            color: var(--text-light);
            line-height: 1.8;
        }

        .about-card ul {
            list-style: disc;
            padding-left: 20px;
        }

        .score-breakdown {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 12px;
            margin-top: 16px;
        }

        .score-item {
            background: var(--primary-light);
            padding: 14px;
            border-radius: var(--radius-sm);
            text-align: center;
        }

        .score-item .weight {
            font-size: 24px;
            font-weight: 700;
            color: var(--primary);
        }

        .score-item .label {
            font-size: 13px;
            color: var(--text-light);
        }

        /* ============================================================
           Toast Notification
           ============================================================ */
        .toast {
            position: fixed;
            bottom: 24px;
            right: 24px;
            padding: 14px 24px;
            background: var(--accent);
            color: white;
            border-radius: var(--radius-sm);
            box-shadow: var(--shadow-lg);
            font-size: 14px;
            font-weight: 500;
            transform: translateY(100px);
            opacity: 0;
            transition: all 0.3s ease;
            z-index: 1000;
        }

        .toast.show {
            transform: translateY(0);
            opacity: 1;
        }

        .toast.error { background: var(--danger); }

        /* ============================================================
           Loading Spinner
           ============================================================ */
        .spinner {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid var(--border);
            border-top-color: var(--primary);
            border-radius: 50%;
            animation: spin 0.8s linear infinite;
        }

        @keyframes spin { to { transform: rotate(360deg); } }

        .loading-overlay {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            padding: 40px;
            color: var(--text-light);
        }

        /* ============================================================
           Responsive Design
           ============================================================ */
        @media (max-width: 900px) {
            .search-layout {
                grid-template-columns: 1fr;
            }

            .filter-panel {
                position: static;
            }

            .form-grid {
                grid-template-columns: 1fr;
            }

            .form-facilities {
                grid-template-columns: repeat(2, 1fr);
            }

            .score-breakdown {
                grid-template-columns: 1fr;
            }

            .header-stats { display: none; }
        }

        @media (max-width: 600px) {
            .cards-grid {
                grid-template-columns: 1fr;
            }

            .nav-tab {
                padding: 10px 14px;
                font-size: 13px;
            }

            .main { padding: 16px; }
        }
    </style>
</head>
<body>

    <!-- ============================================================
         Header & Navigation
         ============================================================ -->
    <header class="header">
        <div class="header-content">
            <div class="header-top">
                <div class="logo">
                    <div class="logo-icon">&#127968;</div>
                    <div>
                        <h1>CampusBodima</h1>
                        <p>Find Your Perfect Student Boarding</p>
                    </div>
                </div>
                <div class="header-stats">
                    <span id="totalCount">Loading...</span>
                    <span>&#9733; Expert System Powered</span>
                </div>
            </div>
            <nav class="nav-tabs">
                <button class="nav-tab active" data-tab="find">&#128269; Find Boarding</button>
                <button class="nav-tab" data-tab="all">&#127970; All Boardings</button>
                <button class="nav-tab" data-tab="add">&#10133; Add Boarding</button>
                <button class="nav-tab" data-tab="about">&#8505; About</button>
            </nav>
        </div>
    </header>

    <!-- ============================================================
         Main Content
         ============================================================ -->
    <main class="main">

        <!-- ==================== Find Boarding Tab ==================== -->
        <div id="tab-find" class="tab-content active">
            <div class="search-layout">
                <!-- Filter Panel -->
                <div class="filter-panel">
                    <h3>&#9881; Search Filters</h3>

                    <div class="filter-group">
                        <label>University</label>
                        <select id="filterUniversity">
                            <option value="moratuwa" selected>University of Moratuwa</option>
                            <option value="colombo">University of Colombo</option>
                            <option value="kelaniya">University of Kelaniya</option>
                            <option value="jayewardenepura">University of Sri Jayewardenepura</option>
                            <option value="peradeniya">University of Peradeniya</option>
                            <option value="any">All Universities</option>
                        </select>
                    </div>

                    <div class="filter-group">
                        <label>Price Range (LKR/month)</label>
                        <div class="price-range">
                            <input type="number" id="filterMinPrice" placeholder="Min" min="0" step="1000">
                            <input type="number" id="filterMaxPrice" placeholder="Max" min="0" step="1000">
                        </div>
                    </div>

                    <div class="filter-group">
                        <label>Max Distance (km)</label>
                        <select id="filterDistance">
                            <option value="">Any Distance</option>
                            <option value="0.5">Within 0.5 km</option>
                            <option value="1">Within 1 km</option>
                            <option value="2">Within 2 km</option>
                            <option value="3">Within 3 km</option>
                            <option value="5">Within 5 km</option>
                            <option value="10">Within 10 km</option>
                        </select>
                    </div>

                    <div class="filter-group">
                        <label>Room Type</label>
                        <select id="filterRoomType">
                            <option value="any">Any</option>
                            <option value="single">Single Room</option>
                            <option value="shared">Shared Room</option>
                        </select>
                    </div>

                    <div class="filter-group">
                        <label>Min Bathrooms</label>
                        <select id="filterBathrooms">
                            <option value="">Any</option>
                            <option value="1">At least 1</option>
                            <option value="2">At least 2</option>
                        </select>
                    </div>

                    <div class="filter-group">
                        <label>Gender Preference</label>
                        <select id="filterGender">
                            <option value="any">Any</option>
                            <option value="male">Male</option>
                            <option value="female">Female</option>
                        </select>
                    </div>

                    <div class="filter-group">
                        <label>Required Facilities</label>
                        <div class="facilities-grid" id="filterFacilities">
                            <label class="facility-check"><input type="checkbox" value="wifi"> WiFi</label>
                            <label class="facility-check"><input type="checkbox" value="ac"> A/C</label>
                            <label class="facility-check"><input type="checkbox" value="furniture"> Furniture</label>
                            <label class="facility-check"><input type="checkbox" value="kitchen"> Kitchen</label>
                            <label class="facility-check"><input type="checkbox" value="parking"> Parking</label>
                            <label class="facility-check"><input type="checkbox" value="laundry"> Laundry</label>
                            <label class="facility-check"><input type="checkbox" value="hot_water"> Hot Water</label>
                            <label class="facility-check"><input type="checkbox" value="study_room"> Study Room</label>
                            <label class="facility-check"><input type="checkbox" value="cctv"> CCTV</label>
                            <label class="facility-check"><input type="checkbox" value="generator"> Generator</label>
                            <label class="facility-check"><input type="checkbox" value="meals"> Meals</label>
                        </div>
                    </div>

                    <button class="btn-search" onclick="performSearch()">&#128269; Search Boardings</button>
                    <button class="btn-reset" onclick="resetFilters()">Reset Filters</button>
                </div>

                <!-- Results Area -->
                <div class="results-area">
                    <div class="results-header">
                        <div>
                            <h3>Recommended Boardings</h3>
                            <span class="results-count" id="resultsCount"></span>
                        </div>
                        <select class="sort-select" id="sortSelect" onchange="sortResults()">
                            <option value="score">Sort by Relevance</option>
                            <option value="price_asc">Price: Low to High</option>
                            <option value="price_desc">Price: High to Low</option>
                            <option value="distance">Distance: Nearest</option>
                            <option value="rating">Rating: Highest</option>
                        </select>
                    </div>
                    <div class="cards-grid" id="searchResults">
                        <div class="loading-overlay"><div class="spinner"></div> Searching...</div>
                    </div>
                </div>
            </div>
        </div>

        <!-- ==================== All Boardings Tab ==================== -->
        <div id="tab-all" class="tab-content">
            <div class="browse-header">
                <input type="text" class="search-input" id="browseSearch"
                       placeholder="&#128269; Search by name, location, or university..."
                       oninput="filterBrowse()">
                <select class="sort-select" id="browseUniFilter" onchange="filterBrowse()">
                    <option value="">All Universities</option>
                    <option value="moratuwa">University of Moratuwa</option>
                    <option value="colombo">University of Colombo</option>
                    <option value="kelaniya">University of Kelaniya</option>
                    <option value="jayewardenepura">University of Sri Jayewardenepura</option>
                    <option value="peradeniya">University of Peradeniya</option>
                </select>
            </div>
            <div class="cards-grid" id="allBoardings">
                <div class="loading-overlay"><div class="spinner"></div> Loading...</div>
            </div>
        </div>

        <!-- ==================== Add Boarding Tab ==================== -->
        <div id="tab-add" class="tab-content">
            <div class="add-form">
                <h3>&#10133; Add New Boarding Place</h3>
                <div class="form-grid">
                    <div class="form-group">
                        <label>Boarding Name *</label>
                        <input type="text" id="addName" placeholder="e.g. Sunshine Boarding" required>
                    </div>
                    <div class="form-group">
                        <label>University *</label>
                        <select id="addUniversity">
                            <option value="moratuwa">University of Moratuwa</option>
                            <option value="colombo">University of Colombo</option>
                            <option value="kelaniya">University of Kelaniya</option>
                            <option value="jayewardenepura">University of Sri Jayewardenepura</option>
                            <option value="peradeniya">University of Peradeniya</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label>Location / Area *</label>
                        <input type="text" id="addLocation" placeholder="e.g. Katubedda">
                    </div>
                    <div class="form-group">
                        <label>Monthly Rent (LKR) *</label>
                        <input type="number" id="addPrice" placeholder="e.g. 15000" min="0">
                    </div>
                    <div class="form-group">
                        <label>Distance from University (km) *</label>
                        <input type="number" id="addDistance" placeholder="e.g. 1.5" min="0" step="0.1">
                    </div>
                    <div class="form-group">
                        <label>Room Type</label>
                        <select id="addRoomType">
                            <option value="single">Single Room</option>
                            <option value="shared">Shared Room</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label>Max Occupants</label>
                        <input type="number" id="addMaxOccupants" value="1" min="1" max="10">
                    </div>
                    <div class="form-group">
                        <label>Number of Bathrooms</label>
                        <input type="number" id="addBathrooms" value="1" min="1" max="5">
                    </div>
                    <div class="form-group">
                        <label>Gender Preference</label>
                        <select id="addGender">
                            <option value="any">Any</option>
                            <option value="male">Male Only</option>
                            <option value="female">Female Only</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label>Contact Number *</label>
                        <input type="text" id="addContact" placeholder="e.g. 071-1234567">
                    </div>
                    <div class="form-group full-width">
                        <label>Facilities</label>
                        <div class="form-facilities" id="addFacilities">
                            <label class="facility-check"><input type="checkbox" value="wifi"> WiFi</label>
                            <label class="facility-check"><input type="checkbox" value="ac"> Air Conditioning</label>
                            <label class="facility-check"><input type="checkbox" value="furniture"> Furniture</label>
                            <label class="facility-check"><input type="checkbox" value="kitchen"> Kitchen</label>
                            <label class="facility-check"><input type="checkbox" value="parking"> Parking</label>
                            <label class="facility-check"><input type="checkbox" value="laundry"> Laundry</label>
                            <label class="facility-check"><input type="checkbox" value="hot_water"> Hot Water</label>
                            <label class="facility-check"><input type="checkbox" value="study_room"> Study Room</label>
                            <label class="facility-check"><input type="checkbox" value="cctv"> CCTV</label>
                            <label class="facility-check"><input type="checkbox" value="generator"> Generator</label>
                            <label class="facility-check"><input type="checkbox" value="meals"> Meals Provided</label>
                        </div>
                    </div>
                    <button class="btn-submit" onclick="addBoarding()">&#10133; Add Boarding Place</button>
                </div>
            </div>
        </div>

        <!-- ==================== About Tab ==================== -->
        <div id="tab-about" class="tab-content">
            <div class="about-content">
                <div class="about-card">
                    <h3>&#127968; About CampusBodima</h3>
                    <p>CampusBodima is an expert system built with SWI-Prolog that helps university students in Sri Lanka
                    find the perfect boarding place near their university. The system uses rule-based reasoning and a
                    weighted scoring algorithm to recommend the best matches based on your preferences.</p>
                </div>

                <div class="about-card">
                    <h3>&#129504; How Recommendations Work</h3>
                    <p>Our expert system evaluates each boarding place against your criteria using a multi-factor scoring algorithm:</p>
                    <div class="score-breakdown">
                        <div class="score-item">
                            <div class="weight">30%</div>
                            <div class="label">Price Match</div>
                        </div>
                        <div class="score-item">
                            <div class="weight">25%</div>
                            <div class="label">Distance Score</div>
                        </div>
                        <div class="score-item">
                            <div class="weight">25%</div>
                            <div class="label">Facilities Match</div>
                        </div>
                        <div class="score-item">
                            <div class="weight">20%</div>
                            <div class="label">User Rating</div>
                        </div>
                    </div>
                </div>

                <div class="about-card">
                    <h3>&#127891; Supported Universities</h3>
                    <ul>
                        <li>University of Moratuwa - Katubedda, Moratuwa, Dehiwala, Mt. Lavinia</li>
                        <li>University of Colombo - Colombo 03, 07, Bambalapitiya, Wellawatte</li>
                        <li>University of Kelaniya - Kelaniya, Kiribathgoda, Kadawatha</li>
                        <li>University of Sri Jayewardenepura - Nugegoda, Maharagama, Kottawa</li>
                        <li>University of Peradeniya - Peradeniya, Kandy</li>
                    </ul>
                </div>

                <div class="about-card">
                    <h3>&#128736; Technology Stack</h3>
                    <ul>
                        <li><strong>Backend:</strong> SWI-Prolog Expert System with HTTP Server</li>
                        <li><strong>Rules Engine:</strong> Prolog-based filtering and scoring predicates</li>
                        <li><strong>Frontend:</strong> Modern HTML5, CSS3, Vanilla JavaScript</li>
                        <li><strong>API:</strong> RESTful JSON endpoints</li>
                    </ul>
                </div>
            </div>
        </div>
    </main>

    <!-- Toast Notification -->
    <div class="toast" id="toast"></div>

    <!-- ============================================================
         JavaScript
         ============================================================ -->
    <script>
        // ============================================================
        // State
        // ============================================================
        let allBoardingsData = [];
        let searchResultsData = [];

        // ============================================================
        // Tab Navigation
        // ============================================================
        document.querySelectorAll(".nav-tab").forEach(tab => {
            tab.addEventListener("click", () => {
                document.querySelectorAll(".nav-tab").forEach(t => t.classList.remove("active"));
                document.querySelectorAll(".tab-content").forEach(c => c.classList.remove("active"));
                tab.classList.add("active");
                document.getElementById("tab-" + tab.dataset.tab).classList.add("active");

                if (tab.dataset.tab === "all" && allBoardingsData.length === 0) {
                    loadAllBoardings();
                }
            });
        });

        // ============================================================
        // API Calls
        // ============================================================
        async function apiCall(url, method = "GET", body = null) {
            const opts = { method, headers: { "Content-Type": "application/json" } };
            if (body) opts.body = JSON.stringify(body);
            const res = await fetch(url, opts);
            return res.json();
        }

        // ============================================================
        // Search / Recommend
        // ============================================================
        async function performSearch() {
            const container = document.getElementById("searchResults");
            container.innerHTML = \'<div class="loading-overlay"><div class="spinner"></div> Searching...</div>\';

            const facilities = [];
            document.querySelectorAll("#filterFacilities input:checked").forEach(cb => {
                facilities.push(cb.value);
            });

            const criteria = {
                university: document.getElementById("filterUniversity").value,
                min_price: document.getElementById("filterMinPrice").value || null,
                max_price: document.getElementById("filterMaxPrice").value || null,
                max_distance: document.getElementById("filterDistance").value || null,
                room_type: document.getElementById("filterRoomType").value,
                min_bathrooms: document.getElementById("filterBathrooms").value || null,
                gender: document.getElementById("filterGender").value,
                facilities: facilities
            };

            // Convert string numbers to actual numbers
            if (criteria.min_price) criteria.min_price = Number(criteria.min_price);
            if (criteria.max_price) criteria.max_price = Number(criteria.max_price);
            if (criteria.max_distance) criteria.max_distance = Number(criteria.max_distance);
            if (criteria.min_bathrooms) criteria.min_bathrooms = Number(criteria.min_bathrooms);

            try {
                const data = await apiCall("/api/search", "POST", criteria);
                searchResultsData = data.results || [];
                document.getElementById("resultsCount").textContent = searchResultsData.length + " boarding(s) found";
                renderCards(container, searchResultsData, true);
            } catch (err) {
                container.innerHTML = \'<div class="empty-state"><div class="icon">&#9888;</div><h3>Search Error</h3><p>Could not connect to the server. Please try again.</p></div>\';
            }
        }

        function sortResults() {
            const sortBy = document.getElementById("sortSelect").value;
            const sorted = [...searchResultsData];
            switch (sortBy) {
                case "price_asc": sorted.sort((a, b) => a.price - b.price); break;
                case "price_desc": sorted.sort((a, b) => b.price - a.price); break;
                case "distance": sorted.sort((a, b) => a.distance - b.distance); break;
                case "rating": sorted.sort((a, b) => b.rating - a.rating); break;
                default: sorted.sort((a, b) => (b.score || 0) - (a.score || 0));
            }
            renderCards(document.getElementById("searchResults"), sorted, true);
        }

        function resetFilters() {
            document.getElementById("filterUniversity").value = "moratuwa";
            document.getElementById("filterMinPrice").value = "";
            document.getElementById("filterMaxPrice").value = "";
            document.getElementById("filterDistance").value = "";
            document.getElementById("filterRoomType").value = "any";
            document.getElementById("filterBathrooms").value = "";
            document.getElementById("filterGender").value = "any";
            document.querySelectorAll("#filterFacilities input").forEach(cb => cb.checked = false);
            performSearch();
        }

        // ============================================================
        // All Boardings
        // ============================================================
        async function loadAllBoardings() {
            const container = document.getElementById("allBoardings");
            container.innerHTML = \'<div class="loading-overlay"><div class="spinner"></div> Loading all boardings...</div>\';

            try {
                const data = await apiCall("/api/boardings");
                allBoardingsData = data.results || [];
                document.getElementById("totalCount").textContent = allBoardingsData.length + " Boardings Available";
                renderCards(container, allBoardingsData, false);
            } catch (err) {
                container.innerHTML = \'<div class="empty-state"><div class="icon">&#9888;</div><h3>Load Error</h3><p>Could not load boardings.</p></div>\';
            }
        }

        function filterBrowse() {
            const query = document.getElementById("browseSearch").value.toLowerCase();
            const uni = document.getElementById("browseUniFilter").value;
            const filtered = allBoardingsData.filter(b => {
                const matchesSearch = !query ||
                    b.name.toLowerCase().includes(query) ||
                    b.location.toLowerCase().includes(query) ||
                    (b.university_name && b.university_name.toLowerCase().includes(query));
                const matchesUni = !uni || b.university === uni;
                return matchesSearch && matchesUni;
            });
            renderCards(document.getElementById("allBoardings"), filtered, false);
        }

        // ============================================================
        // Add Boarding
        // ============================================================
        async function addBoarding() {
            const name = document.getElementById("addName").value.trim();
            const location = document.getElementById("addLocation").value.trim();
            const price = document.getElementById("addPrice").value;
            const distance = document.getElementById("addDistance").value;
            const contact = document.getElementById("addContact").value.trim();

            if (!name || !location || !price || !distance || !contact) {
                showToast("Please fill in all required fields (*)", true);
                return;
            }

            const facilities = [];
            document.querySelectorAll("#addFacilities input:checked").forEach(cb => {
                facilities.push(cb.value);
            });

            const data = {
                name: name,
                university: document.getElementById("addUniversity").value,
                location: location,
                price: Number(price),
                distance: Number(distance),
                room_type: document.getElementById("addRoomType").value,
                max_occupants: Number(document.getElementById("addMaxOccupants").value),
                bathrooms: Number(document.getElementById("addBathrooms").value),
                gender: document.getElementById("addGender").value,
                contact: contact,
                facilities: facilities,
                rating: 3.0
            };

            try {
                const res = await apiCall("/api/add", "POST", data);
                if (res.success) {
                    showToast("Boarding place added successfully!");
                    // Reset form
                    document.getElementById("addName").value = "";
                    document.getElementById("addLocation").value = "";
                    document.getElementById("addPrice").value = "";
                    document.getElementById("addDistance").value = "";
                    document.getElementById("addContact").value = "";
                    document.getElementById("addMaxOccupants").value = "1";
                    document.getElementById("addBathrooms").value = "1";
                    document.querySelectorAll("#addFacilities input").forEach(cb => cb.checked = false);
                    // Refresh all boardings data
                    allBoardingsData = [];
                    loadAllBoardings();
                } else {
                    showToast("Failed to add boarding: " + (res.message || "Unknown error"), true);
                }
            } catch (err) {
                showToast("Server error. Please try again.", true);
            }
        }

        // ============================================================
        // Render Cards
        // ============================================================
        const facilityIcons = {
            wifi: "&#128246;", ac: "&#10052;", furniture: "&#128186;", kitchen: "&#127859;",
            parking: "&#128663;", laundry: "&#128084;", hot_water: "&#9832;", study_room: "&#128218;",
            cctv: "&#128247;", generator: "&#9889;", meals: "&#127869;"
        };

        const facilityNames = {
            wifi: "WiFi", ac: "A/C", furniture: "Furniture", kitchen: "Kitchen",
            parking: "Parking", laundry: "Laundry", hot_water: "Hot Water",
            study_room: "Study Room", cctv: "CCTV", generator: "Generator", meals: "Meals"
        };

        const universityNames = {
            moratuwa: "University of Moratuwa",
            colombo: "University of Colombo",
            kelaniya: "University of Kelaniya",
            jayewardenepura: "Uni. of Sri Jayewardenepura",
            peradeniya: "University of Peradeniya"
        };

        function renderStars(rating) {
            const full = Math.floor(rating);
            const half = rating - full >= 0.5 ? 1 : 0;
            const empty = 5 - full - half;
            return "&#9733;".repeat(full) + (half ? "&#9734;" : "") + "&#9734;".repeat(empty);
        }

        function renderCards(container, boardings, showScore) {
            if (boardings.length === 0) {
                container.innerHTML = \'<div class="empty-state"><div class="icon">&#128269;</div><h3>No Boardings Found</h3><p>Try adjusting your filters to see more results.</p></div>\';
                return;
            }

            container.innerHTML = boardings.map(b => {
                const uniName = b.university_name || universityNames[b.university] || b.university;
                const facTags = (b.facilities || []).map(f =>
                    \'<span class="facility-tag">\' + (facilityIcons[f] || "") + " " + (facilityNames[f] || f) + "</span>"
                ).join("");
                const genderBadge = \'<span class="badge badge-\' + b.gender + \'">\' + b.gender + "</span>";
                const typeBadge = \'<span class="badge badge-\' + b.room_type + \'">\' + b.room_type + "</span>";

                return \'<div class="boarding-card">\' +
                    \'<div class="card-header">\' +
                        "<div>" +
                            "<h4>" + escapeHtml(b.name) + "</h4>" +
                            \'<div class="card-location">&#128205; \' + escapeHtml(b.location) + " &middot; " + escapeHtml(uniName) + "</div>" +
                        "</div>" +
                        (showScore && b.score != null ? \'<div class="card-score">\' + b.score + "% match</div>" : "") +
                    "</div>" +
                    \'<div class="card-body">\' +
                        \'<div class="card-price">LKR \' + Number(b.price).toLocaleString() + " <span>/month</span></div>" +
                        \'<div class="card-meta">\' +
                            \'<div class="meta-item"><div class="meta-icon">&#128207;</div><div><span class="meta-label">Distance</span><span class="meta-value">\' + b.distance + " km</span></div></div>" +
                            \'<div class="meta-item"><div class="meta-icon">&#128719;</div><div><span class="meta-label">Room</span><span class="meta-value">\' + typeBadge + " " + genderBadge + "</span></div></div>" +
                            \'<div class="meta-item"><div class="meta-icon">&#128701;</div><div><span class="meta-label">Bathrooms</span><span class="meta-value">\' + b.bathrooms + "</span></div></div>" +
                            \'<div class="meta-item"><div class="meta-icon">&#128101;</div><div><span class="meta-label">Occupants</span><span class="meta-value">Max \' + b.max_occupants + "</span></div></div>" +
                        "</div>" +
                        \'<div class="card-facilities">\' + facTags + "</div>" +
                    "</div>" +
                    \'<div class="card-footer">\' +
                        \'<div class="card-rating"><span class="stars">\' + renderStars(b.rating) + "</span> " + b.rating + "/5</div>" +
                        \'<div class="card-contact">&#128222; \' + escapeHtml(b.contact) + "</div>" +
                    "</div>" +
                "</div>";
            }).join("");
        }

        function escapeHtml(text) {
            const div = document.createElement("div");
            div.textContent = text;
            return div.innerHTML;
        }

        // ============================================================
        // Toast
        // ============================================================
        function showToast(message, isError = false) {
            const toast = document.getElementById("toast");
            toast.textContent = message;
            toast.className = "toast" + (isError ? " error" : "");
            toast.classList.add("show");
            setTimeout(() => toast.classList.remove("show"), 3000);
        }

        // ============================================================
        // Initial Load
        // ============================================================
        window.addEventListener("DOMContentLoaded", () => {
            performSearch();
            loadAllBoardings();
        });
    </script>
</body>
</html>'.
