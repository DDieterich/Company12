
with q1 as (select '1,2,3,4,5' c1 from dual)
select regexp_substr(c1,'[^,]+',1,level) from q1
connect by regexp_substr(c1,'[^,]+',1,level);
