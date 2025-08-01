
-- Connect By
with q1 as (select '0,1,2,3,4' c1 from dual
            UNION ALL
            select '5,6,7,8,9' c1 from dual)
select regexp_substr(c1,'[^,]+',1,level) from q1
connect by regexp_substr(c1,'[^,]+',1,level) is NOT NULL
group by regexp_substr(c1,'[^,]+',1,level);

-- XMLTable
with q1 as (select '0,1,2,3,4' c1 from dual
            UNION ALL
            select '5,6,7,8,9' c1 from dual)
select x1.t1 from q1
  cross join xmltable ('for $text in tokenize($input, ",") return $text'
                       passing q1.c1 as "input"
                       columns t1 varchar2(20) path '.') x1;

-- APEX_String
with q1 as (select '0,1,2,3,4' c1 from dual
            UNION ALL
            select '5,6,7,8,9' c1 from dual)
select ap.column_value from q1
 cross join APEX_STRING.split(q1.c1,',') ap;

-- Recursive queries
with q1 as (
select '0,1,2,3,4' c1 from dual
UNION ALL
select '5,6,7,8,9' c1 from dual
), cte1(xstr,xrest,xremoved) as (
select c1, c1, null from q1
UNION ALL
select xstr
      ,case when instr(xrest,',') = 0 then null else substr(xrest,instr(xrest,',')+1) end
      ,case when instr(xrest,',') = 0 then xrest else substr(xrest,1,instr(xrest,',')-1) end
from cte1 where xrest is not null
)
select xremoved from cte1 where xremoved is not null;
