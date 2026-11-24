-- One row per turn_start (a living battler's turn, after the energy restore).
with events as (
    select * from {{ ref('stg_events') }} where event_name = 'turn_start'
),

extracted as (
    select
        event_id,
        battle_id,
        cast(payload ->> 'turn_number' as integer) as turn_number,
        cast(payload ->> 'round_number' as integer) as round_number,
        payload ->> 'actor_id' as actor_id,
        payload ->> 'actor_side' as actor_side,
        cast(payload ->> 'actor_hp' as integer) as actor_hp,
        cast(payload ->> 'actor_energy' as integer) as actor_energy
    from events
)

select * from extracted
