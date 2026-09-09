CREATE TABLE public.labels (
	label_id text NOT NULL,
	"name" text NOT NULL,
	CONSTRAINT labels_pkey PRIMARY KEY (label_id)
);

CREATE TABLE public.contacts (
	id bigserial NOT NULL,
	chat_id text NOT NULL,
	"name" text NULL,
	created_at timestamptz DEFAULT now() NOT NULL,
	updated_at timestamptz DEFAULT now() NOT NULL,
	CONSTRAINT contacts_chat_id_key UNIQUE (chat_id),
	CONSTRAINT contacts_pkey PRIMARY KEY (id)
);

CREATE TABLE public.contact_history (
	id bigserial NOT NULL,
	chat_id text NOT NULL,
	"name" text NULL,
	label_id text NOT NULL,
	observed_at timestamptz DEFAULT now() NOT NULL,
	CONSTRAINT contact_history_pkey PRIMARY KEY (id)
);


