-- Contract: energy is charged on hit_index = 0 only, so sum(energy_cost) is correct.
select action_hit_id, hit_index, energy_cost
from {{ ref('fct_actions') }}
where hit_index > 0 and energy_cost <> 0
