# Mission progression and Earth time

The campaign has no seven-day deadline. Construction of the solar panel and all three crew stations unlocks Surface Survey; completing it unlocks Frozen Horizon; completing that unlocks Lifeline. Existing expedition controls and objectives are retained. Completing Lifeline leaves the outpost available for future story missions.

The existing astronomical clock advances continuously. Rest / maintain base advances it by 24 Earth hours and applies the existing daily resource calculations. Continuous exploration also accumulates resource time, applying one daily accounting update per 24 hours. Accounting is deferred while an expedition or an unresolved decision is active; accrued time is retained in saves. Consumption remains batched daily to preserve existing balance, rather than introducing per-second survival pressure.

Legacy sol field and method names remain internal for compatibility. They represent resource accounting periods, not lunar solar days or story unlocks. Old saves are re-evaluated without the seven-day success condition; genuine resource failures remain failures. Checkpoints retain their existing restore behavior.

Validated with test_mission_progression, test_crew_dialogue, test_orbital_motion, and test_expedition_lifecycle. Historical tests that assert calendar unlock dates or automatic victory after seven periods need revised expectations.
