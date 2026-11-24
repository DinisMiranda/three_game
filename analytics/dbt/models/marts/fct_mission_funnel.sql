-- One row per run (run_id): started -> floor 1 / 2 / 3 reached -> terminal result.
with mission_start as (
    select * from {{ ref('stg_mission_start') }}
),

mission_end as (
    select * from {{ ref('stg_mission_end') }}
),

floors as (
    -- Meridian Spire has 3 floors (mission_start.max_floor); a 4th floor needs a column here.
    select
        run_id,
        bool_or(floor = 1) as reached_floor_1,
        bool_or(floor = 2) as reached_floor_2,
        bool_or(floor = 3) as reached_floor_3,
        max(floor) as max_floor_reached
    from {{ ref('stg_floor_reached') }}
    group by run_id
),

battles as (
    select run_id, count(*) as battles_played, count_if(is_win) as battles_won
    from {{ ref('fct_battles') }}
    where run_id is not null
    group by run_id
),

final as (
    select
        mission_start.run_id,
        mission_start.session_id,
        mission_start.source,
        coalesce(mission_start.policy, 'player') as policy,
        mission_start.mission_id,
        mission_start.max_floor as mission_floors,
        mission_start.started_at,
        mission_end.ended_at,
        coalesce(floors.reached_floor_1, false) as reached_floor_1,
        coalesce(floors.reached_floor_2, false) as reached_floor_2,
        coalesce(floors.reached_floor_3, false) as reached_floor_3,
        coalesce(floors.max_floor_reached, 0) as max_floor_reached,
        -- no mission_end: the player is still in the run, or its lines were lost
        coalesce(mission_end.result, 'in_progress') as mission_result,
        coalesce(battles.battles_played, 0) as battles_played,
        coalesce(battles.battles_won, 0) as battles_won
    from mission_start
    left join mission_end on mission_start.run_id = mission_end.run_id
    left join floors on mission_start.run_id = floors.run_id
    left join battles on mission_start.run_id = battles.run_id
)

select * from final
