-- One row per policy x floor: win rate, pacing and HP cost, i.e. "is any floor a wall?".
with battles as (
    select * from {{ ref('fct_battles') }}
),

final as (
    select
        policy,
        floor,
        count(*) as battles,
        count_if(result = 'win') as wins,
        count_if(result = 'loss') as losses,
        count_if(result = 'quit') as quits,
        count_if(result = 'win') / count(*) as win_rate,
        avg(turns) as mean_turns,
        median(turns) as median_turns,
        avg(rounds) as mean_rounds,
        avg(party_hp_lost_pct) as mean_party_hp_lost_pct
    from battles
    group by policy, floor
)

select * from final
