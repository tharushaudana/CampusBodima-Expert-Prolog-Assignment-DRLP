% ============================================================
% start.pl - Entry Point for CampusBodima Expert System
% ============================================================
%
% Usage: swipl start.pl
% Then open http://localhost:8080 in your browser.
%
% To use a custom port:
%   swipl -g "start_server(9090)" start.pl
%
% ============================================================

:- use_module(boarding).
:- use_module(rules).
:- use_module(interface).

:- initialization(start_server).
