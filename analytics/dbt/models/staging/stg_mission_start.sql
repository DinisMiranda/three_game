-- One row per mission_start (one per run_id).
with events as (
    select * from {{ ref('stg_events') }} where event_name = 'mission_start'
),

extracted as (
    select
        run_id,
        session_id,
        source,
        event_ts_utc as started_at,
        payload ->> 'mission_id' as mission_id,
        cast(payload ->> 'max_floor' as integer) as max_floor,
        payload ->> 'policy' as policy
    from events
)

select * from extracted
