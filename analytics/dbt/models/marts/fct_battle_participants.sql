-- One row per battler in a battle (battle_id, battler_id): slot, side, and how it fell.
with battle_start as (
    select battle_id, party_ids, enemy_ids, enemy_type_ids from {{ ref('stg_battle_start') }}
),

battler_down as (
    select * from {{ ref('stg_battler_down') }}
),

party_slots as (
    select battle_id, party_ids, unnest(range(len(party_ids))) as slot_index
    from battle_start
),

enemy_slots as (
    select battle_id, enemy_ids, enemy_type_ids, unnest(range(len(enemy_ids))) as slot_index
    from battle_start
),

participants as (
    -- DuckDB lists are 1-based, range() is 0-based
    select
        battle_id,
        party_ids[slot_index + 1] as battler_id,
        party_ids[slot_index + 1] as battler_key,
        'party' as side,
        slot_index
    from party_slots
    union all
    select
        battle_id,
        enemy_ids[slot_index + 1] as battler_id,
        enemy_type_ids[slot_index + 1] as battler_key,
        'enemy' as side,
        slot_index
    from enemy_slots
),

final as (
    select
        participants.battle_id,
        participants.battler_id,
        participants.battler_key,
        participants.side,
        participants.slot_index,
        battler_down.battler_id is not null as is_down,
        battler_down.turn_number as turn_of_death,
        battler_down.killer_id,
        battler_down.ability_id as killed_by_ability_id
    from participants
    left join battler_down
        on participants.battle_id = battler_down.battle_id
        and participants.battler_id = battler_down.battler_id
)

select * from final
