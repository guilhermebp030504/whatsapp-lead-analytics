SELECT
    DATE(observed_at) AS data,
    COUNT(DISTINCT chat_id) AS leads
FROM contact_history
GROUP BY DATE(observed_at)
ORDER BY data
limit 10;