-- Contract: is_kill = (target_hp_before > 0 and target_hp_after = 0).
select action_hit_id, target_hp_before, target_hp_after, is_kill
from {{ ref('fct_actions') }}
where is_kill <> (target_hp_before > 0 and target_hp_after = 0)
