-- Contract: every battle_id with a battle_start has exactly one battle_end, and no
-- battle_end is orphaned. A start with no end = crashed session or lost lines.
with starts as (
    select battle_id, count(*) as n_starts from {{ ref('stg_battle_start') }} group by battle_id
),

ends as (
    select battle_id, count(*) as n_ends from {{ ref('stg_battle_end') }} group by battle_id
),

final as (
    select
        coalesce(starts.battle_id, ends.battle_id) as battle_id,
        coalesce(starts.n_starts, 0) as n_starts,
        coalesce(ends.n_ends, 0) as n_ends
    from starts
    full outer join ends on starts.battle_id = ends.battle_id
)

select * from final where n_starts <> 1 or n_ends <> 1
