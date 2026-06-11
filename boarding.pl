% ============================================================
% boarding.pl - Boarding Place Data for Sri Lankan Universities
% CampusBodima Expert System
% ============================================================

:- module(boarding, [
    boarding/14,
    next_id/1,
    university_name/2,
    facility_label/2,
    all_facilities/1,
    all_universities/1
]).

:- dynamic boarding/14.
:- dynamic next_id/1.

% boarding(ID, Name, University, Location, Price, Distance, RoomType, MaxOccupants, Bathrooms, Facilities, Gender, Contact, Rating, Available)

% ============================================================
% University name mappings
% ============================================================

university_name(moratuwa, 'University of Moratuwa').
university_name(colombo, 'University of Colombo').
university_name(kelaniya, 'University of Kelaniya').
university_name(jayewardenepura, 'University of Sri Jayewardenepura').
university_name(peradeniya, 'University of Peradeniya').

% ============================================================
% Facility labels for display
% ============================================================

facility_label(wifi, 'WiFi').
facility_label(ac, 'Air Conditioning').
facility_label(furniture, 'Furniture').
facility_label(kitchen, 'Kitchen').
facility_label(parking, 'Parking').
facility_label(laundry, 'Laundry').
facility_label(hot_water, 'Hot Water').
facility_label(study_room, 'Study Room').
facility_label(cctv, 'CCTV').
facility_label(generator, 'Generator').
facility_label(meals, 'Meals Provided').

all_facilities([wifi, ac, furniture, kitchen, parking, laundry, hot_water, study_room, cctv, generator, meals]).

all_universities([moratuwa, colombo, kelaniya, jayewardenepura, peradeniya]).

% ============================================================
% Sample Boarding Data - University of Moratuwa (12 entries)
% ============================================================

boarding(1, 'Sunshine Boarding', moratuwa, 'Katubedda',
    15000, 0.3, single, 1, 1,
    [wifi, furniture, kitchen, laundry], male,
    '071-2345678', 4.2, yes).

boarding(2, 'Green Villa Annex', moratuwa, 'Katubedda',
    12000, 0.5, shared, 2, 1,
    [wifi, furniture, kitchen], male,
    '077-3456789', 3.8, yes).

boarding(3, 'Lake View Rooms', moratuwa, 'Moratuwa Town',
    22000, 1.2, single, 1, 1,
    [wifi, ac, furniture, kitchen, parking, hot_water], any,
    '076-4567890', 4.5, yes).

boarding(4, 'Perera Boarding House', moratuwa, 'Katubedda',
    10000, 0.4, shared, 3, 1,
    [wifi, furniture], male,
    '071-5678901', 3.5, yes).

boarding(5, 'Royal Residency', moratuwa, 'Dehiwala',
    35000, 3.5, single, 1, 2,
    [wifi, ac, furniture, kitchen, parking, hot_water, cctv, generator, laundry], any,
    '077-6789012', 4.8, yes).

boarding(6, 'Nilmini Ladies Hostel', moratuwa, 'Moratuwa Town',
    14000, 0.8, shared, 2, 1,
    [wifi, furniture, kitchen, laundry, cctv], female,
    '076-7890123', 4.0, yes).

boarding(7, 'Mount Lodge', moratuwa, 'Mount Lavinia',
    28000, 4.0, single, 1, 1,
    [wifi, ac, furniture, kitchen, parking, hot_water, study_room], any,
    '071-8901234', 4.3, yes).

boarding(8, 'K-Zone Student Inn', moratuwa, 'Katubedda',
    9000, 0.2, shared, 4, 1,
    [wifi, furniture], male,
    '077-9012345', 3.2, yes).

boarding(9, 'Saman Boarding', moratuwa, 'Piliyandala',
    11000, 5.0, single, 1, 1,
    [wifi, furniture, kitchen, parking], male,
    '076-0123456', 3.6, yes).

boarding(10, 'Chamari Girls Annex', moratuwa, 'Moratuwa Town',
    16000, 1.0, single, 1, 1,
    [wifi, furniture, kitchen, laundry, hot_water, cctv], female,
    '071-1234560', 4.1, yes).

boarding(11, 'Palm Grove Residence', moratuwa, 'Panadura',
    13000, 7.0, shared, 2, 1,
    [wifi, furniture, kitchen, parking, laundry], any,
    '077-2345601', 3.4, no).

boarding(12, 'Silver Star Boarding', moratuwa, 'Dehiwala',
    25000, 3.2, single, 1, 2,
    [wifi, ac, furniture, kitchen, parking, hot_water, study_room, cctv], male,
    '076-3456012', 4.6, yes).

% ============================================================
% Sample Boarding Data - University of Colombo (5 entries)
% ============================================================

boarding(13, 'Colombo City Lodge', colombo, 'Colombo 03',
    30000, 0.8, single, 1, 1,
    [wifi, ac, furniture, kitchen, hot_water, cctv, generator], any,
    '071-4560123', 4.4, yes).

boarding(14, 'Bambalapitiya Student Home', colombo, 'Bambalapitiya',
    18000, 1.5, shared, 2, 1,
    [wifi, furniture, kitchen, laundry], male,
    '077-5601234', 3.9, yes).

boarding(15, 'Wellawatte Boarding', colombo, 'Wellawatte',
    20000, 2.0, single, 1, 1,
    [wifi, furniture, kitchen, parking, laundry, hot_water], any,
    '076-6012345', 4.0, yes).

boarding(16, 'Kollupitiya Ladies Residence', colombo, 'Kollupitiya',
    32000, 1.0, single, 1, 2,
    [wifi, ac, furniture, kitchen, hot_water, cctv, laundry, study_room], female,
    '071-7012345', 4.7, yes).

boarding(17, 'Colombo 07 Budget Rooms', colombo, 'Colombo 07',
    12000, 0.5, shared, 3, 1,
    [wifi, furniture], male,
    '077-8123456', 3.3, yes).

% ============================================================
% Sample Boarding Data - University of Kelaniya (5 entries)
% ============================================================

boarding(18, 'Kelaniya Comfort Stay', kelaniya, 'Kelaniya',
    14000, 0.6, single, 1, 1,
    [wifi, furniture, kitchen, laundry], male,
    '076-9234567', 4.0, yes).

boarding(19, 'Dalugama Student Annex', kelaniya, 'Dalugama',
    10000, 1.0, shared, 2, 1,
    [wifi, furniture, kitchen], any,
    '071-0345678', 3.5, yes).

boarding(20, 'Kiribathgoda Boarding', kelaniya, 'Kiribathgoda',
    16000, 2.5, single, 1, 1,
    [wifi, furniture, kitchen, parking, hot_water, laundry], male,
    '077-1456789', 4.2, yes).

boarding(21, 'Kadawatha Rose Villa', kelaniya, 'Kadawatha',
    22000, 4.0, single, 1, 2,
    [wifi, ac, furniture, kitchen, parking, hot_water, cctv, study_room], any,
    '076-2567890', 4.5, yes).

boarding(22, 'Kelaniya Girls Hostel', kelaniya, 'Kelaniya',
    13000, 0.4, shared, 2, 1,
    [wifi, furniture, kitchen, cctv, laundry], female,
    '071-3678901', 3.8, yes).

% ============================================================
% Sample Boarding Data - University of Sri Jayewardenepura (4 entries)
% ============================================================

boarding(23, 'Nugegoda Premier Rooms', jayewardenepura, 'Nugegoda',
    20000, 0.7, single, 1, 1,
    [wifi, ac, furniture, kitchen, hot_water, parking], any,
    '077-4789012', 4.3, yes).

boarding(24, 'Gangodawila Budget Stay', jayewardenepura, 'Gangodawila',
    9500, 0.5, shared, 3, 1,
    [wifi, furniture], male,
    '076-5890123', 3.4, yes).

boarding(25, 'Maharagama Student Lodge', jayewardenepura, 'Maharagama',
    15000, 3.0, single, 1, 1,
    [wifi, furniture, kitchen, parking, laundry], male,
    '071-6901234', 3.9, yes).

boarding(26, 'Kottawa Ladies Home', jayewardenepura, 'Kottawa',
    17000, 5.0, shared, 2, 1,
    [wifi, furniture, kitchen, laundry, cctv, hot_water], female,
    '077-7012345', 4.1, no).

% ============================================================
% Sample Boarding Data - University of Peradeniya (4 entries)
% ============================================================

boarding(27, 'Peradeniya Green House', peradeniya, 'Peradeniya',
    12000, 0.5, single, 1, 1,
    [wifi, furniture, kitchen, laundry], male,
    '076-8123456', 4.0, yes).

boarding(28, 'Kandy City Boarding', peradeniya, 'Kandy',
    25000, 6.0, single, 1, 2,
    [wifi, ac, furniture, kitchen, parking, hot_water, cctv, generator], any,
    '071-9234567', 4.4, yes).

boarding(29, 'Peradeniya Budget Inn', peradeniya, 'Peradeniya',
    8500, 0.3, shared, 4, 1,
    [wifi, furniture], male,
    '077-0345678', 3.1, yes).

boarding(30, 'Kandy Lotus Residence', peradeniya, 'Kandy',
    18000, 5.5, single, 1, 1,
    [wifi, furniture, kitchen, parking, hot_water, laundry, study_room], female,
    '076-1456789', 4.2, yes).

% ============================================================
% Next ID counter for dynamically added boardings
% ============================================================

next_id(31).
