SELECT
    label_name,
    COUNT(*) AS total
FROM vw_leads_atual
GROUP BY label_id, label_name
ORDER BY label_id::int , total DESC;