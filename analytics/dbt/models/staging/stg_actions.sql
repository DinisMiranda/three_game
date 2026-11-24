-- One row per resolved hit (grenade on 3 targets = 3 rows sharing action_seq).
with events as (
    select * from {{ ref('stg_events') }} where event_name = 'action'
),

extracted as (
    select
        event_id,
        battle_id,
        run_id,
        event_seq,
        cast(payload ->> 'turn_number' as integer) as turn_number,
        cast(payload ->> 'action_seq' as integer) as action_seq,
        cast(payload ->> 'hit_index' as integer) as hit_index,
        payload ->> 'actor_id' as actor_id,
        payload ->> 'actor_side' as actor_side,
        payload ->> 'ability_id' as ability_id,
        payload ->> 'target_id' as target_id,
        payload ->> 'target_side' as target_side,
        cast(payload ->> 'damage' as integer) as damage,
        payload ->> 'hit_kind' as hit_kind,
        cast(payload ->> 'is_crit' as boolean) as is_crit,
        cast(payload ->> 'shield_absorbed' as integer) as shield_absorbed,
        cast(payload ->> 'energy_cost' as integer) as energy_cost,
        cast(payload ->> 'target_hp_before' as integer) as target_hp_before,
        cast(payload ->> 'target_hp_after' as integer) as target_hp_after,
        cast(payload ->> 'is_kill' as boolean) as is_kill
    from events
)

select * from extracted
