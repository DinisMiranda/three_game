-- One row per floor_reached (floor 1 on mission start, then one per advance).
with events as (
    select * from {{ ref('stg_events') }} where event_name = 'floor_reached'
),

extracted as (
    select
        event_id,
        run_id,
        event_ts_utc as reached_at,
        payload ->> 'mission_id' as mission_id,
        cast(payload ->> 'floor' as integer) as floor
    from events
)

select * from extracted
