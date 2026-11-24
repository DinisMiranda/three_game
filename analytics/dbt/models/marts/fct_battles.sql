-- One row per battle (battle_id): lineup and HP from battle_start, outcome from battle_end.
with battle_start as (
    select * from {{ ref('stg_battle_start') }}
),

battle_end as (
    select * from {{ ref('stg_battle_end') }}
),

joined as (
    select
        battle_start.battle_id,
        battle_start.run_id,
        battle_start.session_id,
        battle_start.source,
        -- player data carries no policy; label it so marts can group sim and human side by side
        coalesce(battle_start.policy, 'player') as policy,
        battle_start.mission_id,
        battle_start.floor,
        battle_start.rng_seed,
        battle_start.started_at,
        battle_end.ended_at,
        battle_end.result,
        coalesce(battle_end.result = 'win', false) as is_win,
        battle_end.turns,
        battle_end.rounds,
        battle_end.duration_ms,
        len(battle_start.party_ids) as party_size,
        len(battle_start.enemy_ids) as enemy_count,
        battle_start.enemy_type_ids,
        battle_start.party_hp_total,
        battle_start.enemy_hp_total,
        battle_end.party_hp_remaining,
        battle_start.party_hp_total - battle_end.party_hp_remaining as party_hp_lost,
        len(battle_end.surviving_party) as party_survivors,
        battle_end.enemies_remaining
    from battle_start
    -- left join: a start with no end keeps result null and fails the not_null test
    left join battle_end on battle_start.battle_id = battle_end.battle_id
),

final as (
    select
        *,
        party_hp_lost / nullif(party_hp_total, 0) as party_hp_lost_pct
    from joined
)

select * from final
