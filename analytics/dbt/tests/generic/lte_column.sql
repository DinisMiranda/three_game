{% test lte_column(model, column_name, other_column) %}
-- Fails where column_name > other_column (e.g. target_hp_after > target_hp_before).
select {{ column_name }}, {{ other_column }}
from {{ model }}
where {{ column_name }} > {{ other_column }}
{% endtest %}
