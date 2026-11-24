{% test not_negative(model, column_name) %}
-- Fails on any row where the column is below zero (damage, HP, energy, counts).
select {{ column_name }}
from {{ model }}
where {{ column_name }} < 0
{% endtest %}
