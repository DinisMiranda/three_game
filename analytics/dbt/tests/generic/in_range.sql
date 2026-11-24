{% test in_range(model, column_name, min_value=none, max_value=none) %}
-- Fails on any non-null value outside [min_value, max_value] (either bound optional).
select {{ column_name }}
from {{ model }}
where {{ column_name }} is not null
  and (
    false
    {% if min_value is not none %} or {{ column_name }} < {{ min_value }} {% endif %}
    {% if max_value is not none %} or {{ column_name }} > {{ max_value }} {% endif %}
  )
{% endtest %}
