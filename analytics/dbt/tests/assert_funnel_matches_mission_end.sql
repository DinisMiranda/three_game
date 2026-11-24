-- mission_end.max_floor_reached must agree with the floor_reached events of the run.
with mission_end as (
    select run_id, max_floor_reached from {{ ref('stg_mission_end') }}
),

funnel as (
    select run_id, max_floor_reached from {{ ref('fct_mission_funnel') }}
)

select mission_end.run_id, mission_end.max_floor_reached, funnel.max_floor_reached as from_events
from mission_end
inner join funnel on mission_end.run_id = funnel.run_id
where mission_end.max_floor_reached <> funnel.max_floor_reached
