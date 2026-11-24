-- One row per battle_start (opens a battle_id): floor, lineups, HP totals.
with events as (
    select * from {{ ref('stg_events') }} where event_name = 'battle_start'
),

extracted as (
    select
        battle_id,
        run_id,
        session_id,
        source,
        event_ts_utc as started_at,
        cast(payload ->> 'floor' as integer) as floor,
        payload ->> 'mission_id' as mission_id,
        cast(payload -> 'party_ids' as varchar[]) as party_ids,
        cast(payload -> 'enemy_ids' as varchar[]) as enemy_ids,
        cast(payload -> 'enemy_type_ids' as varchar[]) as enemy_type_ids,
        cast(payload ->> 'party_hp_total' as integer) as party_hp_total,
        cast(payload ->> 'enemy_hp_total' as integer) as enemy_hp_total,
        cast(payload ->> 'seed' as bigint) as rng_seed,
        payload ->> 'policy' as policy
    from events
)

select * from extracted
