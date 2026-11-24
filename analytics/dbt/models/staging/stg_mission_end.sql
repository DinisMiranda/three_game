-- One row per mission_end (closes a run_id).
with events as (
    select * from {{ ref('stg_events') }} where event_name = 'mission_end'
),

extracted as (
    select
        run_id,
        event_ts_utc as ended_at,
        payload ->> 'mission_id' as mission_id,
        payload ->> 'result' as result,
        cast(payload ->> 'max_floor_reached' as integer) as max_floor_reached
    from events
)

select * from extracted
