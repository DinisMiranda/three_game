-- Contract: synthetic and human data never share a session.
select session_id
from {{ ref('stg_events') }}
group by session_id
having count(distinct source) > 1
