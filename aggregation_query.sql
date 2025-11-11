WITH
loan_base AS (
  SELECT *,
    first_due_date AS due_date
  FROM `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`
  WHERE day_maturity < 11
    and flag_bad_customer = 0
    AND EXTRACT(MONTH FROM first_due_date) = 9
    AND EXTRACT(YEAR FROM first_due_date) = 2025
),
notification_data AS (
  SELECT *
    -- customer_id,
    -- REGEXP_EXTRACT(deep_link, r'accountId=(\d+)') AS deal_reference,
    -- CAST(notification_created_at AS DATE) AS notification_date,
    -- notification_code,
    -- notification_status
  FROM `jago-bank-data-production.dwh_core.notification_current`
  WHERE notification_code IN (
    'Notification_DL_Repayment_Reminder',
    'Notification_DL_Overdue_BELL_PUSH_Reminder'
  )
  LIMIT 1
),
-- SELECT *
-- FROM notification_aggregated
-- ORDER BY total_notif_sent DESC
-- LIMIT 10;
-- SELECT
--   COUNT(*) as total_loans,
--   SUM(total_notif_sent) as all_notifications,
--   AVG(total_notif_sent) as avg_notif_per_loan,
--   SUM(total_notif_read) as all_read,
--   SUM(reminder_sent) as all_reminders,
--   SUM(dpd_sent) as all_dpd
-- FROM notification_aggregated;
-- SELECT
--   COUNT(DISTINCT loan.lfs_customer_id) as loans_in_cohort,
--   COUNT(DISTINCT CASE WHEN notif.customer_id IS NOT NULL THEN loan.lfs_customer_id END) as
-- loans_with_notifications,
--   COUNT(notif.notification_date) as total_notification_records_matched
-- FROM loan_base loan
-- LEFT JOIN notification_sample notif
--   ON loan.lfs_customer_id = notif.customer_id
--   AND loan.deal_reference = notif.deal_reference
collection_calls AS (
  SELECT
    card_no as deal_reference,
    CAST(date AS DATE) as call_date,
    status,
    remark,
    dialed_number,
    phone_type,
    person_contacted,
    collector
  FROM `jago-bank-data-production.digital_lending.digital_lending_collection_daily_report_vendor`
  WHERE business_date >= '2025-08-01'
    AND business_date <= CURRENT_DATE()
    AND card_no IS NOT NULL
  limit 1
),
loan_calls_classified AS (
  SELECT
    loan.lfs_customer_id,
    loan.deal_reference,
    loan.due_date,
    loan.cohort_name,
    loan.flag_bad_customer,
    call.call_date,
    call.status,
    call.remark,
    call.phone_type,
    call.person_contacted,
    call.collector,
    CASE
      WHEN call.status IN ('PAID', 'PTP', 'PTP - Reminder', 'PAYMENT PLAN', 'RENCANA PEMBAYARAN',
                            'Request for payment plan', 'Plan Approved', 'Broken Promise')
      THEN 'commitment_payment'

      WHEN call.status IN ('No Answer', 'EC - No answer', 'No Answer AutoDial',
                            'Busy Auto', 'Auto Busy', 'EC - Busy call', 'Busy',
                            'Call Rejected', 'Voice Mail', 'Voice Message Prompt',
                            'Dropped', 'DROP CALL', 'Outbound Local Channel Res Error',
                            'Outbound Pre-Routing Drop', 'ABORT', 'SCBR')
      THEN 'unsuccessful_call'

      WHEN call.status IN ('Call Back', 'Left Message', 'UNDER NEGOTIATION', 'RTP', 'WPC', 'Pickup')
      THEN 'successful_contact_no_commitment'

      WHEN call.status IN ('invalid', 'Resign / Moved', 'Skip Trace', 'Duplicate', 'Claim')
      THEN 'data_information'

      WHEN call.status IN ('NEW', 'TRANSFER', 'REASSIGN', 'ACTIVATE', 'Agent Error')
      THEN 'workflow'

      WHEN call.status IN ('WA - Sent', 'WA - Read')
      THEN 'alternative_channel'

      WHEN call.status IN ('Complaint - Behavior', 'Complaint - Vulnerable')
      THEN 'complaint_escalation'

      ELSE 'other'
    END AS status_category

  FROM loan_base loan
  LEFT JOIN collection_calls call
    ON loan.deal_reference = call.deal_reference
    AND call.call_date <= DATE_ADD(loan.due_date, INTERVAL 1 MONTH)
),
call_timing AS (
  SELECT
    deal_reference,
    MIN(CASE WHEN call_date < due_date THEN call_date END) AS first_call_before_due,
    MAX(CASE WHEN call_date < due_date THEN call_date END) AS last_call_before_due,
    MIN(CASE WHEN call_date >= due_date THEN call_date END) AS first_call_after_due,
    MAX(CASE WHEN call_date >= due_date THEN call_date END) AS last_call_after_due
  FROM loan_calls_classified
  WHERE call_date IS NOT NULL
  GROUP BY deal_reference
),

calls_predictive AS (
  SELECT
    deal_reference,
    COUNT(call_date) AS pred_total_calls,
    COUNTIF(status_category = 'commitment_payment') AS pred_commitment_payment,
    COUNTIF(status_category = 'unsuccessful_call') AS pred_unsuccessful_call,
    COUNTIF(status_category = 'successful_contact_no_commitment') AS pred_successful_no_commit,
    COUNTIF(status_category = 'data_information') AS pred_data_info,
    COUNTIF(status_category = 'workflow') AS pred_workflow,
    COUNTIF(status_category = 'alternative_channel') AS pred_alt_channel,
    COUNTIF(status_category = 'complaint_escalation') AS pred_complaint,
    COUNT(DISTINCT collector) AS pred_collectors
  FROM loan_calls_classified
  WHERE remark LIKE 'Predictive%'
  GROUP BY deal_reference
),
calls_manual AS (
  SELECT
    deal_reference,
    COUNT(call_date) AS manual_total_calls,
    COUNTIF(status_category = 'commitment_payment') AS manual_commitment_payment,
    COUNTIF(status_category = 'unsuccessful_call') AS manual_unsuccessful_call,
    COUNTIF(status_category = 'successful_contact_no_commitment') AS manual_successful_no_commit,
    COUNTIF(status_category = 'data_information') AS manual_data_info,
    COUNTIF(status_category = 'workflow') AS manual_workflow,
    COUNTIF(status_category = 'alternative_channel') AS manual_alt_channel,
    COUNTIF(status_category = 'complaint_escalation') AS manual_complaint,
    COUNT(DISTINCT collector) AS manual_collectors
  FROM loan_calls_classified
  WHERE remark NOT LIKE 'Predictive%' OR remark IS NULL
  GROUP BY deal_reference
),
calls_rpc AS (
  SELECT
    deal_reference,
    COUNT(call_date) AS rpc_total_calls,
    COUNTIF(status_category = 'commitment_payment') AS rpc_commitment_payment,
    COUNTIF(status_category = 'unsuccessful_call') AS rpc_unsuccessful_call,
    COUNTIF(status_category = 'successful_contact_no_commitment') AS rpc_successful_no_commit,
    COUNTIF(status_category = 'data_information') AS rpc_data_info,
    COUNTIF(status_category = 'workflow') AS rpc_workflow,
    COUNTIF(status_category = 'alternative_channel') AS rpc_alt_channel,
    COUNTIF(status_category = 'complaint_escalation') AS rpc_complaint,
    COUNT(DISTINCT collector) AS rpc_collectors
  FROM loan_calls_classified
  WHERE person_contacted = 'RPC'
  GROUP BY deal_reference
),
calls_tpc AS (
  SELECT
    deal_reference,
    COUNT(call_date) AS tpc_total_calls,
    COUNTIF(status_category = 'commitment_payment') AS tpc_commitment_payment,
    COUNTIF(status_category = 'unsuccessful_call') AS tpc_unsuccessful_call,
    COUNTIF(status_category = 'successful_contact_no_commitment') AS tpc_successful_no_commit,
    COUNTIF(status_category = 'data_information') AS tpc_data_info,
    COUNTIF(status_category = 'workflow') AS tpc_workflow,
    COUNTIF(status_category = 'alternative_channel') AS tpc_alt_channel,
    COUNTIF(status_category = 'complaint_escalation') AS tpc_complaint,
    COUNT(DISTINCT collector) AS tpc_collectors
  FROM loan_calls_classified
  WHERE person_contacted = 'TPC'
  GROUP BY deal_reference
),
calls_main_phone AS (
  SELECT
    deal_reference,
    COUNT(call_date) AS main_total_calls,
    COUNTIF(status_category = 'commitment_payment') AS main_commitment_payment,
    COUNTIF(status_category = 'unsuccessful_call') AS main_unsuccessful_call,
    COUNTIF(status_category = 'successful_contact_no_commitment') AS main_successful_no_commit,
    COUNTIF(status_category = 'data_information') AS main_data_info,
    COUNTIF(status_category = 'workflow') AS main_workflow,
    COUNTIF(status_category = 'alternative_channel') AS main_alt_channel,
    COUNTIF(status_category = 'complaint_escalation') AS main_complaint,
    COUNT(DISTINCT collector) AS main_collectors
  FROM loan_calls_classified
  WHERE phone_type = 'Main Phone'
  GROUP BY deal_reference
),
calls_emergency AS (
  SELECT
    deal_reference,
    COUNT(call_date) AS emerg_total_calls,
    COUNTIF(status_category = 'commitment_payment') AS emerg_commitment_payment,
    COUNTIF(status_category = 'unsuccessful_call') AS emerg_unsuccessful_call,
    COUNTIF(status_category = 'successful_contact_no_commitment') AS emerg_successful_no_commit,
    COUNTIF(status_category = 'data_information') AS emerg_data_info,
    COUNTIF(status_category = 'workflow') AS emerg_workflow,
    COUNTIF(status_category = 'alternative_channel') AS emerg_alt_channel,
    COUNTIF(status_category = 'complaint_escalation') AS emerg_complaint,
    COUNT(DISTINCT collector) AS emerg_collectors
  FROM loan_calls_classified
  WHERE phone_type = 'Emergency Contact'
  GROUP BY deal_reference
),
calls_office AS (
  SELECT
    deal_reference,
    COUNT(call_date) AS office_total_calls,
    COUNTIF(status_category = 'commitment_payment') AS office_commitment_payment,
    COUNTIF(status_category = 'unsuccessful_call') AS office_unsuccessful_call,
    COUNTIF(status_category = 'successful_contact_no_commitment') AS office_successful_no_commit,
    COUNTIF(status_category = 'data_information') AS office_data_info,
    COUNTIF(status_category = 'workflow') AS office_workflow,
    COUNTIF(status_category = 'alternative_channel') AS office_alt_channel,
    COUNTIF(status_category = 'complaint_escalation') AS office_complaint,
    COUNT(DISTINCT collector) AS office_collectors
  FROM loan_calls_classified
  WHERE phone_type = 'Office'
  GROUP BY deal_reference
),
loan_collection_summary AS (
  SELECT
    loan.lfs_customer_id,
    loan.deal_reference,
    loan.due_date,

    timing.first_call_before_due,
    DATE_DIFF(timing.first_call_before_due, loan.due_date, DAY) as diff_first_call_and_before_due,
    timing.last_call_before_due,
    DATE_DIFF(timing.last_call_before_due, loan.due_date, DAY) as diff_last_call_and_before_due,
    timing.first_call_after_due,
    DATE_DIFF(timing.first_call_after_due, loan.due_date, DAY) as diff_first_call_and_after_due,
    timing.last_call_after_due,
    DATE_DIFF(timing.last_call_after_due, loan.due_date, DAY) as diff_last_call_and_after_due,

    loan.cohort_name,
    loan.flag_bad_customer,

    -- bot
    COALESCE(pred.pred_total_calls, 0) AS pred_total_calls,
    COALESCE(pred.pred_commitment_payment, 0) AS pred_commitment_payment,
    COALESCE(pred.pred_unsuccessful_call, 0) AS pred_unsuccessful_call,
    COALESCE(pred.pred_successful_no_commit, 0) AS pred_successful_no_commit,
    COALESCE(pred.pred_data_info, 0) AS pred_data_info,
    COALESCE(pred.pred_workflow, 0) AS pred_workflow,
    COALESCE(pred.pred_alt_channel, 0) AS pred_alt_channel,
    COALESCE(pred.pred_complaint, 0) AS pred_complaint,
    pred.pred_collectors,

    -- manual
    COALESCE(manual.manual_total_calls, 0) AS manual_total_calls,
    COALESCE(manual.manual_commitment_payment, 0) AS manual_commitment_payment,
    COALESCE(manual.manual_unsuccessful_call, 0) AS manual_unsuccessful_call,
    COALESCE(manual.manual_successful_no_commit, 0) AS manual_successful_no_commit,
    COALESCE(manual.manual_data_info, 0) AS manual_data_info,
    COALESCE(manual.manual_workflow, 0) AS manual_workflow,
    COALESCE(manual.manual_alt_channel, 0) AS manual_alt_channel,
    COALESCE(manual.manual_complaint, 0) AS manual_complaint,
    manual.manual_collectors,

    -- right party
    COALESCE(rpc.rpc_total_calls, 0) AS rpc_total_calls,
    COALESCE(rpc.rpc_commitment_payment, 0) AS rpc_commitment_payment,
    COALESCE(rpc.rpc_unsuccessful_call, 0) AS rpc_unsuccessful_call,
    COALESCE(rpc.rpc_successful_no_commit, 0) AS rpc_successful_no_commit,
    COALESCE(rpc.rpc_data_info, 0) AS rpc_data_info,
    COALESCE(rpc.rpc_workflow, 0) AS rpc_workflow,
    COALESCE(rpc.rpc_alt_channel, 0) AS rpc_alt_channel,
    COALESCE(rpc.rpc_complaint, 0) AS rpc_complaint,
    rpc.rpc_collectors,

    -- 3rd party
    COALESCE(tpc.tpc_total_calls, 0) AS tpc_total_calls,
    COALESCE(tpc.tpc_commitment_payment, 0) AS tpc_commitment_payment,
    COALESCE(tpc.tpc_unsuccessful_call, 0) AS tpc_unsuccessful_call,
    COALESCE(tpc.tpc_successful_no_commit, 0) AS tpc_successful_no_commit,
    COALESCE(tpc.tpc_data_info, 0) AS tpc_data_info,
    COALESCE(tpc.tpc_workflow, 0) AS tpc_workflow,
    COALESCE(tpc.tpc_alt_channel, 0) AS tpc_alt_channel,
    COALESCE(tpc.tpc_complaint, 0) AS tpc_complaint,
    tpc.tpc_collectors,

    -- main phone
    COALESCE(main.main_total_calls, 0) AS main_total_calls,
    COALESCE(main.main_commitment_payment, 0) AS main_commitment_payment,
    COALESCE(main.main_unsuccessful_call, 0) AS main_unsuccessful_call,
    COALESCE(main.main_successful_no_commit, 0) AS main_successful_no_commit,
    COALESCE(main.main_data_info, 0) AS main_data_info,
    COALESCE(main.main_workflow, 0) AS main_workflow,
    COALESCE(main.main_alt_channel, 0) AS main_alt_channel,
    COALESCE(main.main_complaint, 0) AS main_complaint,
    main.main_collectors,

    -- econ
    COALESCE(emerg.emerg_total_calls, 0) AS emerg_total_calls,
    COALESCE(emerg.emerg_commitment_payment, 0) AS emerg_commitment_payment,
    COALESCE(emerg.emerg_unsuccessful_call, 0) AS emerg_unsuccessful_call,
    COALESCE(emerg.emerg_successful_no_commit, 0) AS emerg_successful_no_commit,
    COALESCE(emerg.emerg_data_info, 0) AS emerg_data_info,
    COALESCE(emerg.emerg_workflow, 0) AS emerg_workflow,
    COALESCE(emerg.emerg_alt_channel, 0) AS emerg_alt_channel,
    COALESCE(emerg.emerg_complaint, 0) AS emerg_complaint,
    emerg.emerg_collectors,

    -- work call
    COALESCE(office.office_total_calls, 0) AS office_total_calls,
    COALESCE(office.office_commitment_payment, 0) AS office_commitment_payment,
    COALESCE(office.office_unsuccessful_call, 0) AS office_unsuccessful_call,
    COALESCE(office.office_successful_no_commit, 0) AS office_successful_no_commit,
    COALESCE(office.office_data_info, 0) AS office_data_info,
    COALESCE(office.office_workflow, 0) AS office_workflow,
    COALESCE(office.office_alt_channel, 0) AS office_alt_channel,
    COALESCE(office.office_complaint, 0) AS office_complaint,
    office.office_collectors

  FROM loan_base loan
  LEFT JOIN call_timing timing USING (deal_reference)
  LEFT JOIN calls_predictive pred USING (deal_reference)
  LEFT JOIN calls_manual manual USING (deal_reference)
  LEFT JOIN calls_rpc rpc USING (deal_reference)
  LEFT JOIN calls_tpc tpc USING (deal_reference)
  LEFT JOIN calls_main_phone main USING (deal_reference)
  LEFT JOIN calls_emergency emerg USING (deal_reference)
  LEFT JOIN calls_office office USING (deal_reference)
),
vintage_data AS (
  SELECT
    lfs_customer_id,
    deal_reference,
    acct_3dpd_max
  FROM `jago-bank-data-production.data_mart.credit_risk_vintage_account_direct_lending`
  WHERE business_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
),
final_summary AS (
  SELECT
    vintage.acct_3dpd_max,
    summary.*
  FROM loan_collection_summary summary
  LEFT JOIN vintage_data vintage
  ON summary.lfs_customer_id = vintage.lfs_customer_id
    AND summary.deal_reference = vintage.deal_reference
),
notification_data AS (
  SELECT
    customer_id,
    REGEXP_EXTRACT(deep_link, r'accountId=(\d+)') AS deal_reference,
    CAST(notification_created_at AS DATE) AS notification_date,
    notification_code,
    notification_status
  FROM `jago-bank-data-production.dwh_core.notification_current`
  WHERE notification_code IN (
    'Notification_DL_Repayment_Reminder',
    'Notification_DL_Overdue_BELL_PUSH_Reminder'
  )
),
notification_aggregated AS (
  SELECT
    loan.lfs_customer_id,
    loan.deal_reference,

    COALESCE(COUNT(notif.notification_date), 0) AS total_notif_sent,
    COALESCE(COUNTIF(notif.notification_status = 'READ'), 0) AS total_notif_read,
    COALESCE(COUNTIF(notif.notification_status = 'UNREAD'), 0) AS total_notif_unread,

    COALESCE(COUNTIF(notif.notification_code = 'Notification_DL_Repayment_Reminder'), 0) AS reminder_sent,
    COALESCE(COUNTIF(notif.notification_code = 'Notification_DL_Repayment_Reminder'
            AND notif.notification_status = 'READ'), 0) AS reminder_read,

    COALESCE(COUNTIF(notif.notification_code = 'Notification_DL_Overdue_BELL_PUSH_Reminder'), 0) AS
dpd_sent,
    COALESCE(COUNTIF(notif.notification_code = 'Notification_DL_Overdue_BELL_PUSH_Reminder'
            AND notif.notification_status = 'READ'), 0) AS dpd_read

  FROM loan_base loan
  LEFT JOIN notification_data notif
    ON loan.lfs_customer_id = notif.customer_id
    AND loan.deal_reference = notif.deal_reference
    AND notif.notification_date <= DATE_ADD(loan.due_date, INTERVAL 1 MONTH)
  GROUP BY loan.lfs_customer_id, loan.deal_reference
),
final_dataset AS (
  SELECT
    coll.*,

    notif.total_notif_sent,
    notif.total_notif_read,
    notif.total_notif_unread,
    notif.reminder_sent,
    notif.reminder_read,
    notif.dpd_sent,
    notif.dpd_read

  FROM final_summary coll 
  LEFT JOIN notification_aggregated notif
    ON coll.lfs_customer_id = notif.lfs_customer_id
    AND coll.deal_reference = notif.deal_reference
)
SELECT *
FROM final_dataset
ORDER BY pred_total_calls DESC
LIMIT 10
  -- SELECT
  --   COUNT(*) as total_loans,

  --   COUNTIF(acct_3dpd_max = 0) as paid_on_time,
  --   COUNTIF(acct_3dpd_max > 0) as went_past_due,

  --   SUM(pred_total_calls) as all_pred_calls,
  --   SUM(manual_total_calls) as all_manual_calls,
  --   AVG(pred_total_calls + manual_total_calls) as avg_calls_per_loan,

  --   SUM(total_notif_sent) as all_notifications,
  --   AVG(total_notif_sent) as avg_notif_per_loan,

  --   COUNTIF(pred_total_calls + manual_total_calls > 0) as loans_with_calls,
  --   COUNTIF(total_notif_sent > 0) as loans_with_notifications
  -- FROM final_dataset;
-- LIMIT 20;
-- SELECT *
-- FROM loan_collection_summary
-- WHERE flag_bad_customer = 1
-- ORDER BY pred_total_calls DESC
-- LIMIT 20;