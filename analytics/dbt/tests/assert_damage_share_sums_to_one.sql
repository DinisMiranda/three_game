-- Hero damage shares are a partition of party damage within each policy.
-- 1e-9 tolerates floating-point rounding in the sum of ratios.
select policy, sum(damage_share) as total_share
from {{ ref('mart_hero_performance') }}
group by policy
having sum(total_damage) > 0 and abs(sum(damage_share) - 1) > 1e-9
