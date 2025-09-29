-- business_date, start_date facility, maturity_facility, tenor, nik, cif, customer_lfs, status (active/no), dpd_max, dpd_final, dpd_bucket_max, dpd_bucket_final, collect_max, collect_final (stg loan facility per tanggal), plafond awal, plafond, outstanding,  latest_plafond awal, latest_plafond, latest_outstanding (latest master loan facility), first_wo_date, latest_wo_date, amount_wo, is_wo, latest_recovery_date, amount_recovery, is_reovery, acct_3, acct_10, acct_30, balance_3, balance_10, balance_30 (max dan max ever)
-- active kalau fasilitas expired/karyawan

-- create or replace table `data-prd-adhoc.credit_risk_adhoc.credit_risk_coc_direct_lending_fang` as (

-- Update



with 
master_loan_facility as 
(
  select distinct
    business_date
    , status
    , cif
    , facility_reference
    , facility_type
    , plafond
    , plafond_awal
    , start_date
    , maturity_date
    , nomor_pk_awal
  from `jago-bank-data-production.one_reporting_views.master_loan_facility`
  where business_date IN
    ( 
      '2023-12-31',
      '2024-01-31','2024-02-29','2024-03-31','2024-04-30','2024-05-31','2024-06-30',
      '2024-07-31','2024-08-31','2024-09-30','2024-10-31','2024-11-30', '2024-12-31',
      '2025-01-31','2025-02-28','2025-03-31','2025-04-30','2025-05-31','2025-06-30', 
      '2025-07-31','2025-08-31',current_date()-2
    )
    and facility_type like 'FJDL'
)
, stg_loan_facility as 
(
  select distinct
    business_date
    , facility_type
    , facility_reference
    , deal_type
    , cif
    , deal_reference
    , start_date_facility
    , maturity_date_facility
    , start_date
    , maturity_date
    , collect as collect_final
    , plafond_awal * -1 as plafond_awal
    , plafond *-1 as plafond
    , case when (plafond_awal * -1)>(plafond *-1) then (plafond_awal * -1) else (plafond *-1) end as latest_plafond
    , outstanding * -1 as OS
    , pastdue_days_principal as dpd_max
    , pastdue_days_final as dpd_final
    , product_group_description
  from `jago-bank-data-production.one_reporting_views.staging_loan_facility`
  WHERE 
    business_date IN
    ( 
      '2023-12-31',
      '2024-01-31','2024-02-29','2024-03-31','2024-04-30','2024-05-31','2024-06-30',
      '2024-07-31','2024-08-31','2024-09-30','2024-10-31','2024-11-30', '2024-12-31',
      '2025-01-31','2025-02-28','2025-03-31','2025-04-30','2025-05-31','2025-06-30', 
      '2025-07-31','2025-08-31',current_date()-2
    )
    AND 
    (deal_type like 'JAG%' OR deal_type in ('PBL01','PBL02'))
)
-- Flow Rate
, flow_rate as 
(
  select 
    business_date
    , facility_reference
    , deal_reference
    , cif
    , (case when dpd_max=0 or dpd_max is null then 0 else 
      case when dpd_max<=30 then 1 else 
      case when dpd_max<=60 then 2 else 
      case when dpd_max<=90 then 3 else 
      case when dpd_max<=120 then 4 else 
      case when dpd_max<=150 then 5 else 
      case when dpd_max<=180 then 6 else 7 end end end end end end end) as dpd_bucket_max
    , (case when dpd_final=0 or dpd_final is null then 0 else 
      case when dpd_final<=30 then 1 else 
      case when dpd_final<=60 then 2 else 
      case when dpd_final<=90 then 3 else 
      case when dpd_final<=120 then 4 else 
      case when dpd_final<=150 then 5 else 
      case when dpd_final<=180 then 6 else 7 end end end end end end end) as dpd_bucket_final
    , (case when dpd_max = 0 or dpd_max is null then 1 else
      case when dpd_max<=90 then 2 else 
      case when dpd_max<=120 then 3 else 
      case when dpd_max<=150 then 4 else 5 end end end end) as collect_max
    , collect_final
  from stg_loan_facility
)
-- Master Loan Report
, master_loan_report as 
(
  select 
    business_date,
    cif,
    facility_reference,
    deal_reference, 
    deal_type,
    start_date, 
    maturity_date, 
    plafond, 
    outstanding,
    status
  from `jago-bank-data-production.one_reporting_views.master_loan_report`
  where business_date in 
      (
        '2023-12-31',
        '2024-01-31','2024-02-29','2024-03-31','2024-04-30','2024-05-31','2024-06-30',
        '2024-07-31','2024-08-31','2024-09-30','2024-10-31','2024-11-30', '2024-12-31',
        '2025-01-31','2025-02-28','2025-03-31','2025-04-30','2025-05-31','2025-06-30', 
        '2025-07-31','2025-08-31',current_date()-2
    )
    and (deal_type like 'JAG%' OR deal_type in ('PBL01','PBL02'))
),
master_loan_report_summary as 
(
  select 
    business_date,
    cif,
    facility_reference,
    deal_type,
    COUNTIF(status = 'ACTIVE') AS active_loan,
    MAX(CASE WHEN status = 'ACTIVE' THEN start_date ELSE NULL END) AS latest_start_date,
  from master_loan_report
  where business_date in 
      (
        '2023-12-31',
        '2024-01-31','2024-02-29','2024-03-31','2024-04-30','2024-05-31','2024-06-30',
        '2024-07-31','2024-08-31','2024-09-30','2024-10-31','2024-11-30', '2024-12-31',
        '2025-01-31','2025-02-28','2025-03-31','2025-04-30','2025-05-31','2025-06-30', 
        '2025-07-31','2025-08-31',current_date()-2
    )
    and (deal_type like 'JAG%' OR deal_type in ('PBL01','PBL02'))
    group by 1,2,3,4
)
-- Raw Historical
, 
raw_credit_risk_historical_data AS 
(
  SELECT x.business_date,
         facility_reference,
         count(*) as total_account_ever,
         max(days_past_due_max) as days_past_due_max,
         sum(balance_xdpd_max)        AS balance_xdpd_max,
         sum(balance_3dpd_max)        AS balance_3dpd_max,
         sum(balance_10dpd_max)       AS balance_10dpd_max,
         sum(balance_30dpd_max)       AS balance_30dpd_max,
         sum(balance_xdpd_max_ever)        AS balance_xdpd_max_ever,
         sum(balance_3dpd_max_ever)        AS balance_3dpd_max_ever,
         sum(balance_10dpd_max_ever)       AS balance_10dpd_max_ever
        ,sum(balance_30dpd_max_ever)       AS balance_30dpd_max_ever
  FROM `jago-bank-data-production.data_mart_stg.credit_risk_loan_account_historical_dimension` x
  left join master_loan_report y
  on x.business_date=y.business_date and x.deal_reference=y.deal_reference
  WHERE x.business_date IN 
    (
      '2023-12-31',
      '2024-01-31','2024-02-29','2024-03-31','2024-04-30','2024-05-31','2024-06-30',
      '2024-07-31','2024-08-31','2024-09-30','2024-10-31','2024-11-30', '2024-12-31',
      '2025-01-31','2025-02-28','2025-03-31','2025-04-30','2025-05-31','2025-06-30', 
      '2025-07-31','2025-08-31',current_date()-2
    )
    group by 1,2
), 

raw_credit_risk_historical_data_summary AS 
(
  SELECT 
         facility_reference,
         max(days_past_due_max_ever) days_past_due_max_ever,
  FROM `jago-bank-data-production.data_mart_stg.credit_risk_loan_account_historical_dimension` x
  left join master_loan_report y
  on x.business_date=y.business_date and x.deal_reference=y.deal_reference
  WHERE x.business_date IN 
    (
      '2023-12-31',
      '2024-01-31','2024-02-29','2024-03-31','2024-04-30','2024-05-31','2024-06-30',
      '2024-07-31','2024-08-31','2024-09-30','2024-10-31','2024-11-30', '2024-12-31',
      '2025-01-31','2025-02-28','2025-03-31','2025-04-30','2025-05-31','2025-06-30', 
      '2025-07-31','2025-08-31',current_date()-2
    )
    group by 1
),

customer as 
(
  SELECT distinct 
    id_number 
    , max(case when customer_source like 'LFS' then customer_id else null end) as customer_lfs
    , max(case when customer_source like 'LP' then customer_id else null end) as customer_lp
  FROM `jago-bank-data-production.data_mart.customer`
  WHERE business_date = current_date()-2
  group by 1
)
-- CKPN
, 
ckpn as (
  select 
      business_date
    , deal_ref
    , facility_ref
    , stage
    -- , cast(bucket_code as int64) as bucket_code
    , ckpn_kredit
    , ckpn_longgar_tarik
    , coalesce(ckpn_kredit,0) + coalesce(ckpn_longgar_tarik,0) as ckpn_volume
  from `jago-bank-data-production.psak.impairment_konven`
  where 
    business_date in 
      (
        '2023-12-31',
        '2024-01-31','2024-02-29','2024-03-31','2024-04-30','2024-05-31','2024-06-30',
        '2024-07-31','2024-08-31','2024-09-30','2024-10-31','2024-11-30', '2024-12-31',
        '2025-01-31','2025-02-28','2025-03-31','2025-04-30','2025-05-31','2025-06-30', 
        '2025-07-31','2025-08-31',current_date()-2
      )
    AND 
    (deal_type like 'JAG%' OR deal_type in ('PBL01','PBL02'))
), 
write_off as 
(
  select distinct
    last_day(business_date) as business_date
    , cif
    , loan_deal_reference
    , deal_type
    , account
    , start_date
    , last_day(start_date) as wo_date
    , beginning_balance*-1 as wo_amount
    , ending_balance*-1 as wo_ending_balance 
    , principal_wo*-1 as principal_wo 
    , interest_wo*-1 as interest_wo
    , beginning_balance_recovery*-1 as beginning_balance_recovery
    , ytd_recovery*-1 as ytd_recovery,
  from `jago-bank-data-production.one_reporting_views.loan_write_off`
  where business_date>='2025-01-01' and last_day(business_date) = last_day(start_date) 
  and  business_date in 
      (
        '2023-12-31',
        '2024-01-31','2024-02-29','2024-03-31','2024-04-30','2024-05-31','2024-06-30',
        '2024-07-31','2024-08-31','2024-09-30','2024-10-31','2024-11-30', '2024-12-31',
        '2025-01-31','2025-02-28','2025-03-31','2025-04-30','2025-05-31','2025-06-30', 
        '2025-07-31','2025-08-31',current_date()-2
      )
    AND 
    (deal_type like 'JAG%' OR deal_type in ('PBL01','PBL02'))
), 
wo_master_loan as 
(
  select 
    wo.business_date,
    mlr.facility_reference,
    wo.wo_date,
    mlr.deal_type,
    count(*) as total_wo_act,
    sum(wo.wo_amount) as wo_amount,
    sum(ytd_recovery) as recovery_amount,
    sum(wo_ending_balance) as wo_ending_balance,
    sum(principal_wo) as principal_wo,
    sum(interest_wo) as interest_wo
  from write_off wo
  left join master_loan_report mlr
    on wo.loan_deal_reference = mlr.deal_reference and wo.business_date = mlr.business_date
  group by 1,2,3,4
),
wo_master_loan_ever as 
(
  select 
    mlr.facility_reference,
    min(wo.wo_date) as wo_date_ever,
    sum(wo.wo_amount) as wo_amount_ever,
    sum(ytd_recovery) as recovery_amount_ever,
    count(distinct deal_reference) as total_wo_act_ever
  from write_off wo
  left join master_loan_report mlr
    on wo.loan_deal_reference = mlr.deal_reference and wo.business_date = mlr.business_date
  group by 1
)
-- Aggregasi
, combined as
(
  select distinct
      mlf.business_date
    , mlf.facility_reference
    , case when slf.business_date is null then 'C' else 'A' end as flag_slf
    , date_diff(mlf.business_date,mlf.start_date,month) as mob_facility
    , FORMAT_DATE('%Y%m', mlf.start_date) as month_booking_facility 
    , mlf.start_date as start_date_facility
    , mlf.maturity_date as maturity_date_facility
    , DATE_DIFF(mlf.maturity_date, mlf.start_date, MONTH) AS tenor_facility
    , c.id_number
    , mlf.cif as customer_id_lp
    , c.customer_lfs as customer_id_lfs
    , mlf.status as status_facility
    , CASE 
        WHEN mlf.status = 'ACTIVE' THEN 'ACTIVE'
        WHEN mlf.status = 'CLOSED' AND woe.wo_date_ever is not null AND (mlf.business_date>=wo_date_ever) THEN 'WO'
        ELSE 'INACTIVE'
      END AS status_final_facility
    , coalesce(coalesce(slf.deal_type,wo.deal_type),mlrs.deal_type) AS deal_type
    , mlf.plafond_awal as plafond_awal_master_facility
    , mlf.plafond as plafond_master_facility
    , slf.plafond_awal  as plafond_awal_active_facility
    , slf.plafond as plafond_active_facility
    , slf.latest_plafond as latest_plafond_active_facility
    , slf.OS as os_active_facility
    , round(slf.OS / slf.latest_plafond,6) as utility_active_facility
    , slf.dpd_max as dpd_max_facility
    , slf.dpd_final as dpd_final_facility
    , mlrs.latest_start_date
    , mlrs.active_loan
    ,b.total_account_ever
    , fr.dpd_bucket_max
    , fr.dpd_bucket_final
    , fr.collect_max
    , fr.collect_final
    , ckpn.ckpn_kredit
    , ckpn.ckpn_longgar_tarik
    , CASE
        WHEN wo.wo_date is not null THEN 1 ELSE 0
      END as is_wo
    , wo.wo_date
    , wo.wo_amount
    , total_wo_act
    , wo_date_ever
    , case when mlf.business_date>=wo_date_ever then woe.wo_amount_ever else null end as wo_amount_ever
    ,total_wo_act_ever
    , CASE
        WHEN wo.recovery_amount is not null THEN 1 ELSE 0
      END as is_recovery
     , case when mlf.business_date>=wo_date_ever then woe.recovery_amount_ever else null end as recovery_amount_ever
     ,recovery_amount_ever
     ,case when mlf.business_date>=wo_date_ever then b1.days_past_due_max_ever else  b.days_past_due_max end AS days_past_due_max
     ,b1.days_past_due_max_ever
    , case when mlf.business_date>=wo_date_ever then woe.wo_amount_ever else b.balance_xdpd_max *-1 end AS balance_xdpd_max
    , case when mlf.business_date>=wo_date_ever then woe.wo_amount_ever else b.balance_3dpd_max *-1 end AS balance_3dpd_max
    , case when mlf.business_date>=wo_date_ever then woe.wo_amount_ever else b.balance_10dpd_max *-1 end AS balance_10dpd_max
    , case when mlf.business_date>=wo_date_ever then woe.wo_amount_ever else b.balance_30dpd_max *-1 end AS balance_30dpd_max
    , b.balance_xdpd_max_ever *-1 AS balance_xdpd_max_ever
    , b.balance_3dpd_max_ever *-1 AS balance_3dpd_max_ever
    , b.balance_10dpd_max_ever *-1 AS balance_10dpd_max_ever
    , b.balance_30dpd_max_ever *-1 AS balance_30dpd_max_ever
  from master_loan_facility mlf
  left join stg_loan_facility slf
    on mlf.facility_reference = slf.facility_reference and mlf.business_date = slf.business_date
  left join flow_rate fr
    on slf.deal_reference = fr.deal_reference and slf.business_date = fr.business_date
  left join customer c
    on mlf.cif = c.customer_lp
  left join ckpn
    on slf.business_date = ckpn.business_date and slf.facility_reference = ckpn.facility_ref
  left join wo_master_loan wo
    on mlf.facility_reference = wo.facility_reference 
    and mlf.business_date = wo.business_date
  left join raw_credit_risk_historical_data b
    ON mlf.facility_reference = b.facility_reference
      AND mlf.business_date = b.business_date
  left join raw_credit_risk_historical_data_summary b1
   ON mlf.facility_reference = b1.facility_reference
  left join master_loan_report_summary mlrs
   ON mlf.facility_reference = mlrs.facility_reference
      AND mlf.business_date = mlrs.business_date
  left join wo_master_loan_ever woe
  on  mlf.facility_reference = woe.facility_reference
)
select * from combined


------data quality check
--1
-- select business_date,facility_reference,count(*) 
-- from combined
-- group by business_date,facility_reference
-- having count(*)>1


--2
-- select business_date,count(*)
-- from combined
-- group by business_date
-- order by business_date desc

--3
-- select * from combined
-- where status_final_facility not like 'ACTIVE'

--4
-- select distinct deal_type
-- from combined

--5
-- select distinct business_date, sum(wo_amount) from combined
-- group by 1




-- -- Previous 
-- with 
-- master_loan_facility as (
--   select distinct
--     business_date
--     , status
--     , cif
--     , facility_reference
--     , facility_type
--     , plafond
--     , plafond_awal
--     , start_date
--     , maturity_date
--     , nomor_pk_awal
--   from `jago-bank-data-production.one_reporting_views.master_loan_facility`
--   where business_date IN
--     ( 
--       '2023-12-31',
--       '2024-01-31','2024-02-29','2024-03-31','2024-04-30','2024-05-31','2024-06-30',
--       '2024-07-31','2024-08-31','2024-09-30','2024-10-31','2024-11-30', '2024-12-31',
--       '2025-01-31','2025-02-28','2025-03-31','2025-04-30','2025-05-31','2025-06-30', 
--       '2025-07-31','2025-08-31'
--     )
-- )

-- , stg_loan_facility as (
--   select distinct
--     business_date
--     , facility_type
--     , facility_reference
--     , deal_type
--     , cif
--     , deal_reference
--     , start_date_facility
--     , maturity_date_facility
--     , start_date
--     , maturity_date
--     , collect as collect_final
--     , plafond_awal
--     , plafond
--     , outstanding * -1 as OS
--     , pastdue_days_principal as dpd_max
--     , pastdue_days_final as dpd_final
--   from `jago-bank-data-production.one_reporting_views.staging_loan_facility`
--   WHERE 
--     business_date IN
--     ( 
--       '2023-12-31',
--       '2024-01-31','2024-02-29','2024-03-31','2024-04-30','2024-05-31','2024-06-30',
--       '2024-07-31','2024-08-31','2024-09-30','2024-10-31','2024-11-30', '2024-12-31',
--       '2025-01-31','2025-02-28','2025-03-31','2025-04-30','2025-05-31','2025-06-30', 
--       '2025-07-31','2025-08-31'
--     )
--     AND 
--     deal_type in (
--       'JAG01','JAG08','JAG31',
--       'PBL01','PBL02'
--     )
-- )

-- -- Flow Rate
-- , flow_rate as (
--   select distinct
--     business_date
--     , facility_reference
--     , deal_reference
--     , cif
--     , (case when dpd_max=0 or dpd_max is null then 0 else 
--       case when dpd_max<=30 then 1 else 
--       case when dpd_max<=60 then 2 else 
--       case when dpd_max<=90 then 3 else 
--       case when dpd_max<=120 then 4 else 
--       case when dpd_max<=150 then 5 else 
--       case when dpd_max<=180 then 6 else 7 end end end end end end end) as dpd_bucket_max
--     , (case when dpd_final=0 or dpd_final is null then 0 else 
--       case when dpd_final<=30 then 1 else 
--       case when dpd_final<=60 then 2 else 
--       case when dpd_final<=90 then 3 else 
--       case when dpd_final<=120 then 4 else 
--       case when dpd_final<=150 then 5 else 
--       case when dpd_final<=180 then 6 else 7 end end end end end end end) as dpd_bucket_final
--     , (case when dpd_max = 0 or dpd_max is null then 1 else
--       case when dpd_max<=90 then 2 else 
--       case when dpd_max<=120 then 3 else 
--       case when dpd_max<=150 then 4 else 5 end end end end) as collect_max
--     , collect_final
--     , sum(OS) as OS
--   from stg_loan_facility
--   group by 1,2,3,4,5,6,7,8
-- )

-- -- Master Loan Report
-- , master_loan_report as (
--   select 
--     business_date,
--     cif,
--     facility_reference,
--     deal_reference, 
--     deal_type,
--     start_date, 
--     maturity_date, 
--     plafond, 
--     outstanding,
--   from `jago-bank-data-production.one_reporting_views.master_loan_report`
--   where business_date in 
--       (
--         '2023-12-31',
--         '2024-01-31','2024-02-29','2024-03-31','2024-04-30','2024-05-31','2024-06-30',
--         '2024-07-31','2024-08-31','2024-09-30','2024-10-31','2024-11-30', '2024-12-31',
--         '2025-01-31','2025-02-28','2025-03-31','2025-04-30','2025-05-31','2025-06-30', 
--         '2025-07-31','2025-08-31'
--       )
--     and deal_type in (
--       'JAG01','JAG08','JAG31',
--       'PBL01','PBL02'
--     )
-- )

-- -- Raw Historical
-- , raw_credit_risk_historical_data AS (
--   SELECT * FROM `jago-bank-data-production.data_mart_stg.credit_risk_loan_account_historical_dimension`
--   WHERE business_date IN 
--     (
--       '2023-12-31',
--       '2024-01-31','2024-02-29','2024-03-31','2024-04-30','2024-05-31','2024-06-30',
--       '2024-07-31','2024-08-31','2024-09-30','2024-10-31','2024-11-30', '2024-12-31',
--       '2025-01-31','2025-02-28','2025-03-31','2025-04-30','2025-05-31','2025-06-30', 
--       '2025-07-31','2025-08-31'
--     )
-- )

-- -- Customer
-- , customer as (
--   SELECT distinct 
--     id_number 
--     , max(case when customer_source like 'LFS' then customer_id else null end) as customer_lfs
--     , max(case when customer_source like 'LP' then customer_id else null end) as customer_lp
--   FROM `jago-bank-data-production.data_mart.customer`
--   WHERE business_date = "2025-09-21"
--   group by 1
-- )

-- -- CKPN
-- , ckpn as (
--   select distinct
--     business_date
--     , deal_ref
--     , facility_ref
--     -- , cast(bucket_code as int64) as bucket_code
--     , ckpn_kredit
--     , ckpn_longgar_tarik
--     , SUM(ckpn_kredit + ckpn_longgar_tarik) as ckpn_volume
--   from `jago-bank-data-production.psak.impairment_konven`
--   where 
--     business_date in 
--       (
--         '2023-12-31',
--         '2024-01-31','2024-02-29','2024-03-31','2024-04-30','2024-05-31','2024-06-30',
--         '2024-07-31','2024-08-31','2024-09-30','2024-10-31','2024-11-30', '2024-12-31',
--         '2025-01-31','2025-02-28','2025-03-31','2025-04-30','2025-05-31','2025-06-30', 
--         '2025-07-31','2025-08-31'
--       )
--     AND 
--     deal_type in ('JAG01','JAG08','JAG31','PBL01','PBL02')
--   group by 1,2,3,4,5
-- )

-- -- Write Off
-- , 
-- -- with
-- write_off as (
--   select 
--     last_day(business_date) as business_date
--     , cif
--     , loan_deal_reference
--     , deal_type
--     , account
--     , start_date
--     , last_day(start_date) as wo_date
--     , beginning_balance*-1 as wo_amount
--     , ending_balance*-1 as ending_balance 
--     , principal_wo*-1 as principal_wo 
--     , interest_wo*-1 as interest_wo
--     , beginning_balance_recovery*-1 as beginning_balance_recovery
--     , ytd_recovery*-1 as ytd_recovery,
--   from `jago-bank-data-production.one_reporting_views.loan_write_off`
--   where business_date>='2025-01-01' and last_day(business_date) = last_day(start_date) 
--   and  business_date in 
--       (
--         '2023-12-31',
--         '2024-01-31','2024-02-29','2024-03-31','2024-04-30','2024-05-31','2024-06-30',
--         '2024-07-31','2024-08-31','2024-09-30','2024-10-31','2024-11-30', '2024-12-31',
--         '2025-01-31','2025-02-28','2025-03-31','2025-04-30','2025-05-31','2025-06-30', 
--         '2025-07-31','2025-08-31'
--       )
--     and deal_type in (
--       'JAG01','JAG08','JAG31',
--       'PBL01','PBL02'
--     )
-- )

-- , wo as (
--   SELECT
--     business_date, 
--     loan_deal_reference,
--     wo_date,
--     sum(wo_amount) as wo_amount,
--     sum(ytd_recovery) as recovery_amount,
--   FROM write_off 
--   group by 1,2,3
-- )

-- , wo_master_loan as (
--   select 
--     wo.business_date,
--     mlr.facility_reference,
--     wo.wo_date,
--     mlr.deal_type,
--     sum(wo.wo_amount) as wo_amount,
--     sum(wo.recovery_amount) as recovery_amount,
--   from wo
--   left join master_loan_report mlr
--     on wo.loan_deal_reference = mlr.deal_reference and wo.business_date = mlr.business_date
--   group by 1,2,3,4
-- )
-- -- select distinct business_date, sum(wo_amount) from wo_master_loan group by 1

-- -- select * from wo_master_loan

-- -- Aggregasi
-- , combined as (
--   select distinct
--       mlf.business_date
--     , case when slf.business_date is null then 'C' else 'A' end as flag_slf
--     , mlf.start_date as start_date_facility
--     , mlf.maturity_date as maturity_date_facility
--     , DATE_DIFF(mlf.maturity_date, mlf.start_date, MONTH) AS tenor
--     , c.id_number
--     , mlf.cif
--     , c.customer_lfs as customer_id_lfs
--     , mlf.status
--     , CASE 
--         WHEN mlf.status = 'ACTIVE' OR coalesce(slf.deal_type,wo.deal_type) = 'JAG01' THEN 'ACTIVE'
--         ELSE 'INACTIVE'
--       END AS status_final
--     , coalesce(slf.deal_type,wo.deal_type) as deal_type
--     , mlf.plafond_awal as plafond_awal_master_loan
--     , mlf.plafond as plafond_master_loan
--     , slf.plafond_awal as plafond_awal_staging_loan
--     , slf.plafond as plafond_staging_loan
--     , fr.OS
--     , slf.dpd_max
--     , slf.dpd_final
--     , fr.dpd_bucket_max
--     , fr.dpd_bucket_final
--     , fr.collect_max
--     , fr.collect_final
--     , ckpn.ckpn_kredit
--     , ckpn.ckpn_longgar_tarik
--     , CASE
--         WHEN wo.wo_date is not null THEN 1 ELSE 0
--       END as is_wo
--     , wo.wo_date
--     , wo.wo_amount
--     , CASE
--         WHEN wo.recovery_amount is not null THEN 1 ELSE 0
--       END as is_recovery
--     , wo.recovery_amount
--     --  latest_recovery_date, 
--     -- acct_3, acct_10, acct_30, balance_3, balance_10, balance_30 (max dan max ever)
--     , b.balance_3dpd_max_ever *-1 AS balance_3dpd_max_ever
--     , b.balance_10dpd_max_ever *-1 AS balance_10dpd_max_ever
--     , b.balance_30dpd_max_ever *-1 AS balance_30dpd_max_ever
--     , b.balance_3dpd_max_daily_ever *-1 AS balance_3dpd_max_daily_ever
--     , b.balance_10dpd_max_daily_ever *-1 AS balance_10dpd_max_daily_ever
--     , b.balance_30dpd_max_daily_ever *-1 AS balance_30dpd_max_daily_ever
--     , IF(b.balance_3dpd_max_ever * -1 > 0, 1, 0) AS acct_3dpd_max_ever
--     , IF(b.balance_10dpd_max_ever * -1 > 0, 1, 0) AS acct_10dpd_max_ever
--     , IF(b.balance_30dpd_max_ever *-1 > 0, 1, 0) AS acct_30dpd_max_ever
--     , IF(b.balance_3dpd_max_daily_ever * -1 > 0, 1, 0) AS acct_3dpd_max_daily_ever
--     , IF(b.balance_10dpd_max_daily_ever * -1 > 0, 1, 0) AS acct_10dpd_max_daily_ever
--     , IF(b.balance_30dpd_max_daily_ever *-1 > 0, 1, 0) AS acct_30dpd_max_daily_ever
--   from master_loan_facility mlf
--   left join stg_loan_facility slf
--     on mlf.facility_reference = slf.facility_reference and mlf.business_date = slf.business_date
--   left join flow_rate fr
--     on slf.deal_reference = fr.deal_reference and slf.business_date = fr.business_date
--   left join customer c
--     on mlf.cif = c.customer_lp
--   left join ckpn
--     on slf.business_date = ckpn.business_date and slf.facility_reference = ckpn.facility_ref
--   left join wo_master_loan wo
--     on mlf.facility_reference = wo.facility_reference 
--     and mlf.business_date = wo.business_date
--   left join raw_credit_risk_historical_data b
--     ON mlf.nomor_pk_awal = b.initial_agreement_number
--       AND mlf.business_date = b.business_date
-- )
-- -- select * from combined
-- select distinct deal_type from combined

-- -- , combined_2 as (
-- --   select distinct
-- --     business_date
-- --     -- , status
-- --     -- , dpd_bucket_max
-- --     -- , sum(OS) as OS
-- --     , sum(wo_amount) as wo_amount
-- --   from combined
-- --   -- where business_date IN 
-- --     -- ('2025-07-31')
-- --     -- ('2025-05-31','2025-06-30','2025-07-31','2025-08-31')
-- --   group by 1
-- -- )

-- -- select distinct business_date, sum(wo_amount) from combined
-- -- group by 1
-- -- where status = 'ACTIVE'

-- -- select * from combined_2


-- ------------------------------------------------------------------------------------------------------------------------
-- -- Checker
-- -- Aggregasi
-- -- , combined as (
-- --   select 
-- --     x.business_date
-- --     , x.dpd_bucket_max
-- --     , SUM(x.OS) as OS
-- --     , SUM(ckpn_kredit + ckpn_longgar_tarik) as ckpn_volume
-- --     -- , sum(wo_amount) as wo_amount
-- --   from flow_rate x
-- --   left join ckpn y
-- --     on x.business_date = y.business_date and x.facility_reference = y.facility_ref
-- --   -- left join wo z
-- --   --   on x.deal_reference = z.loan_deal_reference
-- --   group by 1,2
-- -- )

-- -- -- Match
-- -- select * from combined where business_date IN 
-- -- ('2025-05-31','2025-06-30','2025-07-31','2025-08-31')

-- -- select business_date, sum(wo_amount) from wo
-- -- group by 1