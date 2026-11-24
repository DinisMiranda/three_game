-- One row per battler_down (emitted right after the killing action).
with events as (
    select * from {{ ref('stg_events') }} where event_name = 'battler_down'
),

extracted as (
    select
        event_id,
        battle_id,
        cast(payload ->> 'turn_number' as integer) as turn_number,
        payload ->> 'battler_id' as battler_id,
        payload ->> 'side' as side,
        payload ->> 'killer_id' as killer_id,
        payload ->> 'killer_side' as killer_side,
        payload ->> 'ability_id' as ability_id
    from events
)

select * from extracted
