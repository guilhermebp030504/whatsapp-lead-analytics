-- public.vw_historico_leads fonte

CREATE OR REPLACE VIEW public.vw_historico_leads
AS SELECT h.chat_id,
    h.name,
    h.label_id,
    COALESCE(l.name, 'Label '::text || h.label_id) AS label_name,
    h.observed_at,
    lag(h.label_id) OVER (PARTITION BY h.chat_id ORDER BY h.observed_at) AS previous_label_id
   FROM contact_history h
     LEFT JOIN labels l ON l.label_id = h.label_id;


-- public.vw_leads_atual fonte

CREATE OR REPLACE VIEW public.vw_leads_atual
AS SELECT DISTINCT ON (h.chat_id) h.chat_id,
    h.name,
    h.label_id,
    l.name AS label_name,
    h.observed_at
   FROM contact_history h
     LEFT JOIN labels l ON l.label_id = h.label_id
  ORDER BY h.chat_id, h.observed_at DESC;