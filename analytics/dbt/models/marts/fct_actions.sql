-- One row per resolved hit, enriched with battle context and battler keys.
with actions as (
    select * from {{ ref('stg_actions') }}
),

battles as (
    select battle_id, policy, source, floor, result from {{ ref('fct_battles') }}
),

participants as (
    select battle_id, battler_id, battler_key from {{ ref('fct_battle_participants') }}
),

final as (
    select
        actions.event_id as action_hit_id,
        actions.battle_id,
        actions.run_id,
        battles.policy,
        battles.source,
        battles.floor,
        battles.result as battle_result,
        actions.turn_number,
        actions.action_seq,
        actions.hit_index,
        actions.actor_id,
        actor.battler_key as actor_key,
        actions.actor_side,
        actions.ability_id,
        actions.target_id,
        target.battler_key as target_key,
        actions.target_side,
        actions.hit_kind,
        actions.hit_kind <> 'effect' as is_damage_attempt,
        actions.damage,
        actions.is_crit,
        actions.shield_absorbed,
        actions.energy_cost,
        actions.target_hp_before,
        actions.target_hp_after,
        actions.is_kill
    from actions
    left join battles on actions.battle_id = battles.battle_id
    left join participants as actor
        on actions.battle_id = actor.battle_id and actions.actor_id = actor.battler_id
    left join participants as target
        on actions.battle_id = target.battle_id and actions.target_id = target.battler_id
)

select * from final
