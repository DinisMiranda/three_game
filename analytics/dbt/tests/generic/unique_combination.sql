{% test unique_combination(model, combination_of_columns) %}
-- Fails for every key combination that appears more than once (composite grain check).
select {{ combination_of_columns | join(', ') }}, count(*) as n_rows
from {{ model }}
group by {{ combination_of_columns | join(', ') }}
having count(*) > 1
{% endtest %}
