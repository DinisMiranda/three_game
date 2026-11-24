-- One row per battle_end (closes a battle_id): result and pacing.
with events as (
    select * from {{ ref('stg_events') }} where event_name = 'battle_end'
),

extracted as (
    select
        battle_id,
        event_ts_utc as ended_at,
        payload ->> 'result' as result,
        cast(payload ->> 'turns' as integer) as turns,
        cast(payload ->> 'rounds' as integer) as rounds,
        cast(payload ->> 'duration_ms' as bigint) as duration_ms,
        cast(payload -> 'surviving_party' as varchar[]) as surviving_party,
        cast(payload ->> 'party_hp_remaining' as integer) as party_hp_remaining,
        cast(payload ->> 'enemies_remaining' as integer) as enemies_remaining
    from events
)

select * from extracted
