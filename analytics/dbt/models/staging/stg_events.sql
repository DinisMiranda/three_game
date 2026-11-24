-- One row per telemetry event: typed envelope, raw payload JSON, de-duplicated on event_id.
with raw_events as (
    select * from {{ source('telemetry', 'events') }}
),

typed as (
    select
        event_id,
        cast(schema_version as integer) as schema_version,
        event_name,
        cast(event_seq as bigint) as event_seq,
        cast(ts_utc as timestamptz) as event_ts_utc,
        session_id,
        run_id,
        battle_id,
        source,
        game_version,
        platform,
        payload,
        _source_file as source_file,
        _loaded_at as loaded_at
    from raw_events
),

deduped as (
    select *
    from typed
    -- raw.events is already idempotent by event_id; this guards against any other loader.
    qualify row_number() over (partition by event_id order by loaded_at, source_file) = 1
)

select * from deduped
