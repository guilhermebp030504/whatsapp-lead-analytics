SELECT
    label_name,
    COUNT(*) AS total
FROM vw_leads_atual
GROUP BY label_name
ORDER BY total DESC;