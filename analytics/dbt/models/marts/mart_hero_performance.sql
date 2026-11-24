-- One row per policy x hero: damage share, damage per action, crit rate, deaths.
with party_actions as (
    select * from {{ ref('fct_actions') }} where actor_side = 'party'
),

party_participants as (
    select * from {{ ref('fct_battle_participants') }} where side = 'party'
),

battles as (
    select battle_id, policy from {{ ref('fct_battles') }}
),

action_stats as (
    select
        policy,
        actor_key as hero_id,
        count_if(hit_index = 0) as actions,  -- one decision = one action_seq = one hit_index 0
        count(*) as hits,
        sum(damage) as total_damage,
        count_if(is_damage_attempt) as damage_attempts,
        count_if(is_damage_attempt and is_crit) as crits,
        sum(energy_cost) as energy_spent
    from party_actions
    group by policy, actor_key
),

participation as (
    select
        battles.policy,
        party_participants.battler_key as hero_id,
        count(*) as battles_played,
        count_if(party_participants.is_down) as deaths
    from party_participants
    inner join battles on party_participants.battle_id = battles.battle_id
    group by battles.policy, party_participants.battler_key
),

final as (
    select
        participation.policy,
        participation.hero_id,
        participation.battles_played,
        coalesce(action_stats.actions, 0) as actions,
        coalesce(action_stats.hits, 0) as hits,
        coalesce(action_stats.total_damage, 0) as total_damage,
        coalesce(action_stats.total_damage, 0)
        / nullif(sum(coalesce(action_stats.total_damage, 0)) over (partition by participation.policy), 0)
            as damage_share,
        action_stats.total_damage / nullif(action_stats.actions, 0) as damage_per_action,
        action_stats.crits / nullif(action_stats.damage_attempts, 0) as crit_rate,
        coalesce(action_stats.energy_spent, 0) as energy_spent,
        participation.deaths,
        participation.deaths / participation.battles_played as death_rate_per_battle
    from participation
    left join action_stats
        on participation.policy = action_stats.policy
        and participation.hero_id = action_stats.hero_id
)

select * from final
