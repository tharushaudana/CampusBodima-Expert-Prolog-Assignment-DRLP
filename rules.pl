% ============================================================
% rules.pl - Expert System Rules for Boarding Recommendation
% CampusBodima Expert System
% ============================================================

:- module(rules, [
    recommend/2,
    filter_boardings/2,
    all_boardings/1,
    add_boarding/2,
    boarding_to_dict/2,
    boarding_to_dict_with_score/3
]).

:- use_module(boarding).

% ============================================================
% Individual Filter Predicates
% ============================================================

% Match university - if 'any' or unspecified, match all
matches_university(ID, University) :-
    (   University == any
    ->  boarding(ID, _, _, _, _, _, _, _, _, _, _, _, _, _)
    ;   boarding(ID, _, University, _, _, _, _, _, _, _, _, _, _, _)
    ).

% Match price range
matches_price(ID, MinPrice, MaxPrice) :-
    boarding(ID, _, _, _, Price, _, _, _, _, _, _, _, _, _),
    (MinPrice == any -> true ; Price >= MinPrice),
    (MaxPrice == any -> true ; Price =< MaxPrice).

% Match maximum distance from university
matches_distance(ID, MaxDistance) :-
    boarding(ID, _, _, _, _, Distance, _, _, _, _, _, _, _, _),
    (MaxDistance == any -> true ; Distance =< MaxDistance).

% Match room type (single/shared)
matches_room_type(ID, RoomType) :-
    (   RoomType == any
    ->  boarding(ID, _, _, _, _, _, _, _, _, _, _, _, _, _)
    ;   boarding(ID, _, _, _, _, _, RoomType, _, _, _, _, _, _, _)
    ).

% Match minimum number of bathrooms
matches_bathrooms(ID, MinBathrooms) :-
    boarding(ID, _, _, _, _, _, _, _, Bathrooms, _, _, _, _, _),
    (MinBathrooms == any -> true ; Bathrooms >= MinBathrooms).

% Match gender preference
matches_gender(ID, Gender) :-
    boarding(ID, _, _, _, _, _, _, _, _, _, BoardingGender, _, _, _),
    (   Gender == any
    ->  true
    ;   BoardingGender == any
    ->  true
    ;   BoardingGender == Gender
    ).

% Match required facilities (all must be present)
matches_facilities(ID, RequiredFacilities) :-
    boarding(ID, _, _, _, _, _, _, _, _, BoardingFacilities, _, _, _, _),
    (   RequiredFacilities == []
    ->  true
    ;   subset(RequiredFacilities, BoardingFacilities)
    ).

% Match availability
matches_available(ID) :-
    boarding(ID, _, _, _, _, _, _, _, _, _, _, _, _, yes).

% ============================================================
% Combined Filter
% ============================================================

% filter_boardings(+Criteria, -Results)
% Criteria is a dict with optional keys:
%   university, min_price, max_price, max_distance,
%   room_type, min_bathrooms, gender, facilities

filter_boardings(Criteria, Results) :-
    get_criterion(Criteria, university, any, University),
    get_criterion(Criteria, min_price, any, MinPrice),
    get_criterion(Criteria, max_price, any, MaxPrice),
    get_criterion(Criteria, max_distance, any, MaxDistance),
    get_criterion(Criteria, room_type, any, RoomType),
    get_criterion(Criteria, min_bathrooms, any, MinBathrooms),
    get_criterion(Criteria, gender, any, Gender),
    get_criterion(Criteria, facilities, [], Facilities),
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

% Helper to get a criterion value with default
get_criterion(Criteria, Key, Default, Value) :-
    (   is_dict(Criteria),
        get_dict(Key, Criteria, RawValue),
        RawValue \== null,
        RawValue \== ""
    ->  Value = RawValue
    ;   Value = Default
    ).

% ============================================================
% Scoring System
% ============================================================

% score_boarding(+ID, +Criteria, -Score)
% Computes a relevance score (0-100) for a boarding given criteria

score_boarding(ID, Criteria, Score) :-
    price_score(ID, Criteria, PScore),
    distance_score(ID, Criteria, DScore),
    facility_score(ID, Criteria, FScore),
    rating_score(ID, RScore),
    Score is PScore * 0.30 + DScore * 0.25 + FScore * 0.25 + RScore * 0.20.

% Price score: closer to budget midpoint = higher score
price_score(ID, Criteria, Score) :-
    boarding(ID, _, _, _, Price, _, _, _, _, _, _, _, _, _),
    get_criterion(Criteria, min_price, any, MinPrice),
    get_criterion(Criteria, max_price, any, MaxPrice),
    (   MinPrice == any, MaxPrice == any
    ->  % No price preference: cheaper is better (normalize to 0-40000 range)
        Score is max(0, 100 - (Price / 400))
    ;   MinPrice == any
    ->  (Price =< MaxPrice -> Score is 100 - ((MaxPrice - Price) / MaxPrice * 50) ; Score is 0)
    ;   MaxPrice == any
    ->  (Price >= MinPrice -> Score is 100 ; Score is 0)
    ;   % Both specified: closer to midpoint = better
        Mid is (MinPrice + MaxPrice) / 2,
        Range is MaxPrice - MinPrice,
        (   Range > 0
        ->  Diff is abs(Price - Mid),
            Score is max(0, 100 - (Diff / Range * 100))
        ;   Score is 100
        )
    ).

% Distance score: closer = better
distance_score(ID, Criteria, Score) :-
    boarding(ID, _, _, _, _, Distance, _, _, _, _, _, _, _, _),
    get_criterion(Criteria, max_distance, any, MaxDistance),
    (   MaxDistance == any
    ->  % No distance preference: closer is still better (max 10km)
        Score is max(0, 100 - (Distance / 10 * 100))
    ;   MaxDistance > 0
    ->  Score is max(0, 100 - (Distance / MaxDistance * 100))
    ;   Score is 100
    ).

% Facility score: percentage of requested facilities that match
facility_score(ID, Criteria, Score) :-
    boarding(ID, _, _, _, _, _, _, _, _, BoardingFacilities, _, _, _, _),
    get_criterion(Criteria, facilities, [], Requested),
    (   Requested == []
    ->  % No facility preference: more facilities = better
        length(BoardingFacilities, Count),
        Score is min(100, Count * 10)
    ;   length(Requested, Total),
        include(facility_in(BoardingFacilities), Requested, Matched),
        length(Matched, MatchCount),
        (Total > 0 -> Score is (MatchCount / Total) * 100 ; Score is 100)
    ).

facility_in(BoardingFacilities, Facility) :-
    member(Facility, BoardingFacilities).

% Rating score: direct mapping from 1-5 to 0-100
rating_score(ID, Score) :-
    boarding(ID, _, _, _, _, _, _, _, _, _, _, _, Rating, _),
    Score is (Rating / 5.0) * 100.

% ============================================================
% Recommendation Engine
% ============================================================

% recommend(+Criteria, -SortedResults)
% Returns list of boarding dicts sorted by score (descending)

recommend(Criteria, SortedResults) :-
    filter_boardings(Criteria, IDs),
    maplist(score_and_pack(Criteria), IDs, Scored),
    sort(1, @>=, Scored, SortedPairs),
    maplist(unpack_scored, SortedPairs, SortedResults).

score_and_pack(Criteria, ID, Score-ID) :-
    score_boarding(ID, Criteria, Score).

unpack_scored(Score-ID, boarding_result{id: ID, score: RoundedScore}) :-
    RoundedScore is round(Score * 10) / 10.

% ============================================================
% Get All Boardings
% ============================================================

all_boardings(Boardings) :-
    findall(ID, boarding(ID, _, _, _, _, _, _, _, _, _, _, _, _, _), IDs),
    maplist(boarding_to_dict, IDs, Boardings).

% ============================================================
% Add New Boarding
% ============================================================

add_boarding(Data, NewID) :-
    retract(next_id(CurrentID)),
    NewID = CurrentID,
    NextID is CurrentID + 1,
    assert(next_id(NextID)),
    get_dict(name, Data, Name),
    get_dict(university, Data, University),
    get_dict(location, Data, Location),
    get_dict(price, Data, Price),
    get_dict(distance, Data, Distance),
    get_dict(room_type, Data, RoomType),
    get_dict(max_occupants, Data, MaxOccupants),
    get_dict(bathrooms, Data, Bathrooms),
    get_dict(facilities, Data, Facilities),
    get_dict(gender, Data, Gender),
    get_dict(contact, Data, Contact),
    get_dict(rating, Data, Rating),
    assert(boarding(NewID, Name, University, Location, Price, Distance,
                    RoomType, MaxOccupants, Bathrooms, Facilities,
                    Gender, Contact, Rating, yes)).

% ============================================================
% Convert Boarding to Dict (for JSON serialization)
% ============================================================

boarding_to_dict(ID, Dict) :-
    boarding(ID, Name, University, Location, Price, Distance,
             RoomType, MaxOccupants, Bathrooms, Facilities,
             Gender, Contact, Rating, Available),
    university_name(University, UniversityName),
    Dict = boarding{
        id: ID,
        name: Name,
        university: University,
        university_name: UniversityName,
        location: Location,
        price: Price,
        distance: Distance,
        room_type: RoomType,
        max_occupants: MaxOccupants,
        bathrooms: Bathrooms,
        facilities: Facilities,
        gender: Gender,
        contact: Contact,
        rating: Rating,
        available: Available
    }.

boarding_to_dict_with_score(ID, Score, Dict) :-
    boarding_to_dict(ID, BaseDict),
    put_dict(score, BaseDict, Score, Dict).

% ============================================================
% Helper: subset check
% ============================================================

subset([], _).
subset([H|T], Set) :-
    member(H, Set),
    subset(T, Set).
