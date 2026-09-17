Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org

ERROR: Failed to read the root certificate store.
   at: get_system_ca_certificates (platform/windows/os_windows.cpp:2582)
[godot_ai game_helper] registered mcp capture (debugger active=false, logger=true)
--- FULL-CYCLE AUTO-PLAY PROBE (1800 ticks, deterministic) — POLICY: CLEAN (min trace, heat lever @0.60) ---
start: dirty $5000 clean $1500 | phase COUNCIL
tick     0 | COUNCIL    | dirty $5000   clean $1500   | gw_heat 0.200 combined 0.200 | central 0.000 alert 0 | grudge 0.000 | jobs 1/0 | insp 0
tick   120 | COUNCIL    | dirty $36540  clean $76020  | gw_heat 0.249 combined 0.249 | central 0.000 alert 0 | grudge 0.000 | jobs 2/2 | insp 0
tick   240 | OPERATIONS | dirty $65816  clean $150540 | gw_heat 0.346 combined 0.346 | central 0.000 alert 0 | grudge 0.000 | jobs 2/2 | insp 0
tick   240 | OPERATIONS | dirty $65816  clean $150540 | gw_heat 0.346 combined 0.346 | central 0.000 alert 0 | grudge 0.000 | jobs 2/2 | insp 0
tick   360 | OPERATIONS | dirty $90993  clean $225060 | gw_heat 0.376 combined 0.376 | central 0.380 alert 0 | grudge 0.000 | jobs 4/4 | insp 0
tick   480 | OPERATIONS | dirty $111568 clean $299580 | gw_heat 0.390 combined 0.390 | central 0.395 alert 0 | grudge 0.000 | jobs 7/7 | insp 0
tick   600 | OPERATIONS | dirty $130476 clean $374100 | gw_heat 0.400 combined 0.400 | central 0.405 alert 0 | grudge 0.000 | jobs 10/10 | insp 0
tick   720 | OPERATIONS | dirty $148163 clean $448620 | gw_heat 0.406 combined 0.406 | central 0.411 alert 0 | grudge 0.000 | jobs 13/13 | insp 0
tick   840 | OPERATIONS | dirty $165213 clean $523140 | gw_heat 0.409 combined 0.409 | central 0.415 alert 0 | grudge 0.000 | jobs 16/16 | insp 0
tick   960 | OPERATIONS | dirty $182019 clean $597660 | gw_heat 0.408 combined 0.408 | central 0.415 alert 0 | grudge 0.000 | jobs 19/19 | insp 0
tick  1080 | OPERATIONS | dirty $198808 clean $672180 | gw_heat 0.407 combined 0.407 | central 0.414 alert 0 | grudge 0.000 | jobs 22/22 | insp 0
tick  1200 | OPERATIONS | dirty $215512 clean $746700 | gw_heat 0.414 combined 0.414 | central 0.419 alert 0 | grudge 0.000 | jobs 25/25 | insp 0
tick  1320 | CRISIS     | dirty $231675 clean $821220 | gw_heat 0.414 combined 0.414 | central 0.420 alert 0 | grudge 0.000 | jobs 28/28 | insp 0
tick  1320 | CRISIS     | dirty $231675 clean $821220 | gw_heat 0.414 combined 0.414 | central 0.420 alert 0 | grudge 0.000 | jobs 28/28 | insp 0
tick  1440 | CRISIS     | dirty $247776 clean $895740 | gw_heat 0.411 combined 0.411 | central 0.418 alert 0 | grudge 0.000 | jobs 31/31 | insp 0
tick  1560 | CRISIS     | dirty $264251 clean $970260 | gw_heat 0.409 combined 0.409 | central 0.416 alert 0 | grudge 0.000 | jobs 34/34 | insp 0
tick  1680 | RECKONING  | dirty $281280 clean $1044780 | gw_heat 0.409 combined 0.409 | central 0.414 alert 0 | grudge 0.000 | jobs 37/37 | insp 0
tick  1680 | RECKONING  | dirty $281280 clean $1044780 | gw_heat 0.409 combined 0.409 | central 0.414 alert 0 | grudge 0.000 | jobs 37/37 | insp 0
tick  1800 | COUNCIL    | dirty $298022 clean $1119300 | gw_heat 0.411 combined 0.411 | central 0.416 alert 0 | grudge 0.000 | jobs 40/40 | insp 0
tick  1800 | COUNCIL    | dirty $298022 clean $1119300 | gw_heat 0.411 combined 0.411 | central 0.416 alert 0 | grudge 0.000 | jobs 40/40 | insp 0
--- SUMMARY ---
jobs: offered 40 / resolved 40  (still unresolved at end: 0)
inspections fired: 0 (case-driven: 0 — raw heat under the bar at fire time)
phase transitions: 4 (expect 4: COUNCIL->OPERATIONS->CRISIS->RECKONING->[cycle 2 COUNCIL])
cycle reached: 2, phase at end: COUNCIL
dirty cash: min $5000  max $298022  end $298022
clean capital at end: $1119300
central pressure: peak 0.420 (bar 0.60)  central_alert ever fired: NO
glass wharf end: heat 0.411  cases 0 (peak 0)  combined 0.411  inspection_ticks 0
resolved-job net evidence (sum of evidence_generated): -13.300  (>0 => cases should accrue)
jobs offered by origin: FAILED_RACKET=2, ?6=1, RIVAL_PROVOCATION=37
DEAD STRETCH (full, all-still incl. cash): 0 / 15 samples (a sample spans 120 ticks)
PRESSURE PLATEAU (heat+central+grudge frozen, ignoring cash): 5 / 15 samples
VERDICT: LOOP ALIVE
