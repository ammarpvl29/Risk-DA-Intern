WITH
model_scores_split AS 
(
  SELECT
    SPLIT(primary_key, '|')[OFFSET(0)] AS customer_id,
    SPLIT(primary_key, '|')[OFFSET(1)] AS appid,
    SPLIT(primary_key, '|')[OFFSET(2)] AS period,
    flag_takeup,
    -- split_tagging,
    scores,
    scores_bin

    from `data-prd-adhoc.dl_whitelist_checkers.df_scores_newoffers_20250930`
    -- from `data-prd-adhoc.dl_whitelist_checkers.df_scores_carryovers_20250930`
    -- from `data-prd-adhoc.dl_whitelist_checkers.df_scores_carryovers_20251106`
  where primary_key is not null
)
,
joined_data AS 
(
  select x.*,y.cbas_created_date,y.calibrated_score_bin,y.calibrated_score
  from model_scores_split x
  left join `jago-bank-data-production.datascience_digital_lending.ews_inferences_monthly` y
  on x.customer_id = y.customer_id_lfs
  and LAST_DAY(date(cbas_created_date)) <= LAST_DAY(DATE_SUB(date(period), INTERVAL 1 MONTH))
  where cbas_created_month > '2024-01-01'
),
joined_data_summary
as
(
  select * from joined_data
  qualify DENSE_RANK() OVER (PARTITION BY customer_id,period ORDER BY LAST_DAY(date(cbas_created_date)) DESC,calibrated_score ASC,appid ASC)=1
),
join_data_null
as 
(
  select  x.* 
  from model_scores_split x left join joined_data y
  on x.customer_id=y.customer_id 
  where y.customer_id is null
),
join_data_null1 AS 
(
  select x.*,y.cbas_created_date,y.calibrated_score_bin,y.calibrated_score
  from join_data_null x
  left join `jago-bank-data-production.datascience_digital_lending.ews_inferences_monthly` y
  on x.customer_id = y.customer_id_lfs
  and LAST_DAY(date(cbas_created_date)) = LAST_DAY(date(period))
  where cbas_created_month > '2024-01-01'
),
gabungan
as
(
  select *, 2 as sources1 from join_data_null1
  union all 
  select *, 1 as sources1 from joined_data_summary
),
gabungan_summary
as
(
  select *  
  from gabungan
  qualify DENSE_RANK() OVER (PARTITION BY customer_id,period ORDER BY sources1 asc)=1
)
-- select period,split_tagging,scores_bin,calibrated_score_bin,flag_takeup,count(distinct customer_id) as count_customer

select period,scores_bin,calibrated_score_bin,flag_takeup,count(distinct customer_id) as count_customer
from gabungan_summary
group by 1,2,3,4
order by 1,2,3,4