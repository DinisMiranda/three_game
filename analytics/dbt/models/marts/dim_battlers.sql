-- One row per battler type: a hero id or an enemy archetype, with side, role and appearances.
with roster as (
    select * from {{ ref('battler_roster') }}
),

participants as (
    select * from {{ ref('fct_battle_participants') }}
),

appearances as (
    select
        battler_key,
        any_value(side) as side,
        count(*) as battle_appearances,
        count_if(is_down) as times_downed
    from participants
    group by battler_key
),

final as (
    select
        coalesce(roster.battler_key, appearances.battler_key) as battler_key,
        coalesce(roster.side, appearances.side) as side,
        roster.display_name,
        roster.role_label,
        coalesce(appearances.battle_appearances, 0) as battle_appearances,
        coalesce(appearances.times_downed, 0) as times_downed,
        roster.battler_key is not null as is_in_roster
    from roster
    full outer join appearances on roster.battler_key = appearances.battler_key
)

select * from final
