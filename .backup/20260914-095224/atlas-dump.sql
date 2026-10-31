--
-- PostgreSQL database dump
--

\restrict 4TFuQsagra5G3S6fPc9qJokWMRjJMKTObA1ILuDKn981O91cOuqzWp1le3lT5en

-- Dumped from database version 17.11
-- Dumped by pg_dump version 17.11

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: app_user; Type: TABLE; Schema: public; Owner: atlas
--

CREATE TABLE public.app_user (
    id integer NOT NULL,
    username text NOT NULL,
    email text,
    full_name text,
    role text DEFAULT 'admin'::text NOT NULL,
    password_hash text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_login_at timestamp with time zone
);


ALTER TABLE public.app_user OWNER TO atlas;

--
-- Name: app_user_id_seq; Type: SEQUENCE; Schema: public; Owner: atlas
--

CREATE SEQUENCE public.app_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.app_user_id_seq OWNER TO atlas;

--
-- Name: app_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: atlas
--

ALTER SEQUENCE public.app_user_id_seq OWNED BY public.app_user.id;


--
-- Name: asset; Type: TABLE; Schema: public; Owner: atlas
--

CREATE TABLE public.asset (
    asset_id text NOT NULL,
    asset_name text NOT NULL,
    asset_type text,
    asset_category text,
    ip_address inet,
    ip_or_type_raw text,
    cluster text,
    datacenter text,
    current_location text,
    site_id integer,
    room_id integer,
    rack_id integer,
    parent_asset_id text,
    attachment_label text,
    capacity text,
    replacement_target text,
    usage_status text,
    usage_status_label text,
    usage_start_date date,
    handover_date date,
    handover_status text,
    purchase_invoice text,
    purchase_price_vnd numeric(18,0),
    supplier_code text,
    supplier_name text,
    warranty_months integer,
    warranty_end_date date,
    description text,
    source_sheet text,
    source_row integer,
    review_flags text[] DEFAULT '{}'::text[] NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.asset OWNER TO atlas;

--
-- Name: asset_event; Type: TABLE; Schema: public; Owner: atlas
--

CREATE TABLE public.asset_event (
    id bigint NOT NULL,
    asset_id text NOT NULL,
    event_sequence integer NOT NULL,
    event_type text,
    event_date date,
    location text,
    usage_object text,
    notes text,
    declared_transition_count integer,
    source_column text,
    source_row integer,
    review_flags text[] DEFAULT '{}'::text[] NOT NULL
);


ALTER TABLE public.asset_event OWNER TO atlas;

--
-- Name: asset_event_id_seq; Type: SEQUENCE; Schema: public; Owner: atlas
--

CREATE SEQUENCE public.asset_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.asset_event_id_seq OWNER TO atlas;

--
-- Name: asset_event_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: atlas
--

ALTER SEQUENCE public.asset_event_id_seq OWNED BY public.asset_event.id;


--
-- Name: placement; Type: TABLE; Schema: public; Owner: atlas
--

CREATE TABLE public.placement (
    id bigint NOT NULL,
    asset_id text NOT NULL,
    rack_id integer NOT NULL,
    start_u integer NOT NULL,
    size_u integer DEFAULT 1 NOT NULL,
    from_date date,
    to_date date,
    CONSTRAINT placement_check CHECK (((start_u > 0) AND (size_u > 0)))
);


ALTER TABLE public.placement OWNER TO atlas;

--
-- Name: placement_id_seq; Type: SEQUENCE; Schema: public; Owner: atlas
--

CREATE SEQUENCE public.placement_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.placement_id_seq OWNER TO atlas;

--
-- Name: placement_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: atlas
--

ALTER SEQUENCE public.placement_id_seq OWNED BY public.placement.id;


--
-- Name: rack; Type: TABLE; Schema: public; Owner: atlas
--

CREATE TABLE public.rack (
    id integer NOT NULL,
    room_id integer NOT NULL,
    code text NOT NULL,
    height_u integer DEFAULT 42 NOT NULL
);


ALTER TABLE public.rack OWNER TO atlas;

--
-- Name: rack_id_seq; Type: SEQUENCE; Schema: public; Owner: atlas
--

CREATE SEQUENCE public.rack_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.rack_id_seq OWNER TO atlas;

--
-- Name: rack_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: atlas
--

ALTER SEQUENCE public.rack_id_seq OWNED BY public.rack.id;


--
-- Name: room; Type: TABLE; Schema: public; Owner: atlas
--

CREATE TABLE public.room (
    id integer NOT NULL,
    site_id integer NOT NULL,
    code text NOT NULL,
    name text
);


ALTER TABLE public.room OWNER TO atlas;

--
-- Name: room_id_seq; Type: SEQUENCE; Schema: public; Owner: atlas
--

CREATE SEQUENCE public.room_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.room_id_seq OWNER TO atlas;

--
-- Name: room_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: atlas
--

ALTER SEQUENCE public.room_id_seq OWNED BY public.room.id;


--
-- Name: site; Type: TABLE; Schema: public; Owner: atlas
--

CREATE TABLE public.site (
    id integer NOT NULL,
    name text NOT NULL,
    kind text DEFAULT 'datacenter'::text NOT NULL
);


ALTER TABLE public.site OWNER TO atlas;

--
-- Name: site_id_seq; Type: SEQUENCE; Schema: public; Owner: atlas
--

CREATE SEQUENCE public.site_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.site_id_seq OWNER TO atlas;

--
-- Name: site_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: atlas
--

ALTER SEQUENCE public.site_id_seq OWNED BY public.site.id;


--
-- Name: status_catalog; Type: TABLE; Schema: public; Owner: atlas
--

CREATE TABLE public.status_catalog (
    code text NOT NULL,
    label text NOT NULL,
    tag_style text DEFAULT 'idle'::text NOT NULL,
    attention boolean DEFAULT false NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.status_catalog OWNER TO atlas;

--
-- Name: supplier; Type: TABLE; Schema: public; Owner: atlas
--

CREATE TABLE public.supplier (
    code text NOT NULL,
    name text NOT NULL
);


ALTER TABLE public.supplier OWNER TO atlas;

--
-- Name: user_session; Type: TABLE; Schema: public; Owner: atlas
--

CREATE TABLE public.user_session (
    token text NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL
);


ALTER TABLE public.user_session OWNER TO atlas;

--
-- Name: app_user id; Type: DEFAULT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.app_user ALTER COLUMN id SET DEFAULT nextval('public.app_user_id_seq'::regclass);


--
-- Name: asset_event id; Type: DEFAULT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.asset_event ALTER COLUMN id SET DEFAULT nextval('public.asset_event_id_seq'::regclass);


--
-- Name: placement id; Type: DEFAULT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.placement ALTER COLUMN id SET DEFAULT nextval('public.placement_id_seq'::regclass);


--
-- Name: rack id; Type: DEFAULT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.rack ALTER COLUMN id SET DEFAULT nextval('public.rack_id_seq'::regclass);


--
-- Name: room id; Type: DEFAULT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.room ALTER COLUMN id SET DEFAULT nextval('public.room_id_seq'::regclass);


--
-- Name: site id; Type: DEFAULT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.site ALTER COLUMN id SET DEFAULT nextval('public.site_id_seq'::regclass);


--
-- Data for Name: app_user; Type: TABLE DATA; Schema: public; Owner: atlas
--

COPY public.app_user (id, username, email, full_name, role, password_hash, is_active, created_at, last_login_at) FROM stdin;
2	admin	vydh@matbao.com	Đặng Hùng Vỹ	admin	scrypt$16384$8$1$Amteir3lhU6vVYdc+yM3Og==$e1dL1Q8+vSvngaoAtYdJOp7SN2VgkurFnhH03sHX1EM=	t	2026-09-10 02:35:30.130115+00	2026-09-14 02:22:27.278362+00
\.


--
-- Data for Name: asset; Type: TABLE DATA; Schema: public; Owner: atlas
--

COPY public.asset (asset_id, asset_name, asset_type, asset_category, ip_address, ip_or_type_raw, cluster, datacenter, current_location, site_id, room_id, rack_id, parent_asset_id, attachment_label, capacity, replacement_target, usage_status, usage_status_label, usage_start_date, handover_date, handover_status, purchase_invoice, purchase_price_vnd, supplier_code, supplier_name, warranty_months, warranty_end_date, description, source_sheet, source_row, review_flags, updated_at) FROM stdin;
SSD-2TB-005	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07	disk	component	\N	disk	MBO	ODS	ODS	1	\N	\N	\N	\N	1.92TB	\N	in_use	Đang sử dụng	2023-10-04	2023-10-04	Đã bàn giao	1705	3400000	MB045564	Công Ty Cổ Phần Giải Pháp Máy Chủ Việt	36	2026-10-01	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07 | SSD | Cụm: MBO	TỔNG HỢP	7	{}	2026-09-10 02:47:38.301245+00
SSD-2TB-006	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07	disk	component	\N	disk	MBO	ODS	ODS	1	\N	\N	\N	\N	1.92TB	\N	in_use	Đang sử dụng	2023-10-04	2023-10-04	Đã bàn giao	1705	3400000	MB045564	Công Ty Cổ Phần Giải Pháp Máy Chủ Việt	36	2026-10-01	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07 | SSD | Cụm: MBO	TỔNG HỢP	8	{}	2026-09-10 02:47:38.301245+00
SSD-2TB-007	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07	disk	component	\N	disk	MBO	ODS	ODS	1	\N	\N	\N	\N	1.92TB	\N	in_use	Đang sử dụng	2023-10-04	2023-10-04	Đã bàn giao	1705	3400000	MB045564	Công Ty Cổ Phần Giải Pháp Máy Chủ Việt	36	2026-10-01	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07 | SSD | Cụm: MBO	TỔNG HỢP	9	{}	2026-09-10 02:47:38.301245+00
SSD-2TB-008	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07	disk	component	\N	disk	MBO	ODS	ODS	1	\N	\N	\N	\N	1.92TB	\N	in_use	Đang sử dụng	2023-10-04	2023-10-04	Đã bàn giao	1705	3400000	MB045564	Công Ty Cổ Phần Giải Pháp Máy Chủ Việt	36	2026-10-01	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07 | SSD | Cụm: MBO	TỔNG HỢP	10	{}	2026-09-10 02:47:38.301245+00
SSD-2TB-009	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07	disk	component	\N	disk	MBO	ODS	ODS	1	\N	\N	\N	\N	1.92TB	\N	in_use	Đang sử dụng	2023-10-04	2023-10-04	Đã bàn giao	1705	3400000	MB045564	Công Ty Cổ Phần Giải Pháp Máy Chủ Việt	36	2026-10-01	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07 | SSD | Cụm: MBO	TỔNG HỢP	11	{}	2026-09-10 02:47:38.301245+00
SSD-2TB-010	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07	disk	component	\N	disk	MBO	ODS	ODS	1	\N	\N	\N	\N	1.92TB	\N	in_use	Đang sử dụng	2023-10-04	2023-10-04	Đã bàn giao	1705	3400000	MB045564	Công Ty Cổ Phần Giải Pháp Máy Chủ Việt	36	2026-10-01	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07 | SSD | Cụm: MBO	TỔNG HỢP	12	{}	2026-09-10 02:47:38.301245+00
SSD-2TB-011	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07	disk	component	\N	disk	MBO	ODS	ODS	1	\N	\N	\N	\N	1.92TB	\N	in_use	Đang sử dụng	2023-10-04	2023-10-04	Đã bàn giao	1705	3400000	MB045564	Công Ty Cổ Phần Giải Pháp Máy Chủ Việt	36	2026-10-01	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07 | SSD | Cụm: MBO	TỔNG HỢP	13	{}	2026-09-10 02:47:38.301245+00
SSD-2TB-012	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07	disk	component	\N	disk	MBO	ODS	ODS	1	\N	\N	\N	\N	1.92TB	\N	in_use	Đang sử dụng	2023-10-04	2023-10-04	Đã bàn giao	1705	3400000	MB045564	Công Ty Cổ Phần Giải Pháp Máy Chủ Việt	36	2026-10-01	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07 | SSD | Cụm: MBO	TỔNG HỢP	14	{}	2026-09-10 02:47:38.301245+00
SW-J6-12	Thiết bị chuyển mạch Switch Cisco Nexus N3K-C3064PQ	switch	component	\N	switch	MBO	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_stock	Chưa sử dụng	2023-10-04	2023-10-04	Đã bàn giao	00000042	28000000	MB2766984	CÔNG TY TNHH THƯƠNG MẠI DỊCH VỤ CÔNG NGHỆ MCSG	12	2024-10-01	Thiết bị chuyển mạch Switch Cisco Nexus N3K-C3064PQ | nexus n3k-c3064pq-10gx | Cụm: MBO	TỔNG HỢP	15	{}	2026-09-10 02:47:38.301245+00
SW-J6-13	Thiết bị chuyển mạch Switch Cisco Nexus N3K-C3064PQ	switch	component	\N	switch	MBO	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_stock	Chưa sử dụng	2023-10-04	2023-10-04	Đã bàn giao	00000042	28000000	MB2766984	CÔNG TY TNHH THƯƠNG MẠI DỊCH VỤ CÔNG NGHỆ MCSG	12	2024-10-01	Thiết bị chuyển mạch Switch Cisco Nexus N3K-C3064PQ | nexus n3k-c3064pq-10gx | Cụm: MBO	TỔNG HỢP	16	{}	2026-09-10 02:47:38.301245+00
SVR-P7-3839	Bộ máy chủ Supermicro	server	server	103.110.128.1	103.110.128.1	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	203570000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Bộ máy chủ Supermicro | CMC101 | Cụm: CMC1	TỔNG HỢP	17	{}	2026-09-10 02:47:38.301245+00
SVR-P7-3637	Bộ máy chủ Supermicro	server	server	103.110.128.2	103.110.128.2	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	203570000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Bộ máy chủ Supermicro | CMC102 | Cụm: CMC1	TỔNG HỢP	18	{}	2026-09-10 02:47:38.301245+00
SVR-P7-3334	Bộ máy chủ Supermicro	server	server	103.110.128.3	103.110.128.3	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	203570000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Bộ máy chủ Supermicro | CMC103 | Cụm: CMC1	TỔNG HỢP	19	{}	2026-09-10 02:47:38.301245+00
SVR-P7-3132	Bộ máy chủ Supermicro	server	server	103.110.128.4	103.110.128.4	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	203570000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Bộ máy chủ Supermicro | CMC104 | Cụm: CMC1	TỔNG HỢP	20	{}	2026-09-10 02:47:38.301245+00
SVR-P7-2829	Bộ máy chủ Supermicro	server	server	103.110.128.5	103.110.128.5	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	203570000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Bộ máy chủ Supermicro | CMC105 | Cụm: CMC1	TỔNG HỢP	21	{}	2026-09-10 02:47:38.301245+00
SVR-P7-2627	Bộ máy chủ Supermicro	server	server	103.110.128.6	103.110.128.6	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	203570000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Bộ máy chủ Supermicro | CMC106 | Cụm: CMC1	TỔNG HỢP	22	{}	2026-09-10 02:47:38.301245+00
SVR-P7-2324	Bộ máy chủ Supermicro	server	server	103.110.128.7	103.110.128.7	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	203570000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Bộ máy chủ Supermicro | CMC107 | Cụm: CMC1	TỔNG HỢP	23	{}	2026-09-10 02:47:38.301245+00
SSD-8TB-001	Ổ cứng 2.5" 7.68TB SSD hiệu Samsung	disk	component	\N	disk	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	7.68TB	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	17587000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Ổ cứng 2.5" 7.68TB SSD hiệu Samsung | SSD | Cụm: CMC1	TỔNG HỢP	24	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SSD-8TB-002	Ổ cứng 2.5" 7.68TB SSD hiệu Samsung	disk	component	\N	disk	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	7.68TB	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	17587000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Ổ cứng 2.5" 7.68TB SSD hiệu Samsung | SSD | Cụm: CMC1	TỔNG HỢP	25	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SSD-8TB-003	Ổ cứng 2.5" 7.68TB SSD hiệu Samsung	disk	component	\N	disk	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	7.68TB	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	17587000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Ổ cứng 2.5" 7.68TB SSD hiệu Samsung | SSD | Cụm: CMC1	TỔNG HỢP	26	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SSD-8TB-004	Ổ cứng 2.5" 7.68TB SSD hiệu Samsung	disk	component	\N	disk	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	7.68TB	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	17587000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Ổ cứng 2.5" 7.68TB SSD hiệu Samsung | SSD | Cụm: CMC1	TỔNG HỢP	27	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SSD-8TB-005	Ổ cứng 2.5" 7.68TB SSD hiệu Samsung	disk	component	\N	disk	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	7.68TB	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	17587000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Ổ cứng 2.5" 7.68TB SSD hiệu Samsung | SSD | Cụm: CMC1	TỔNG HỢP	28	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SSD-8TB-006	Ổ cứng 2.5" 7.68TB SSD hiệu Samsung	disk	component	\N	disk	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	7.68TB	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	17587000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Ổ cứng 2.5" 7.68TB SSD hiệu Samsung | SSD | Cụm: CMC1	TỔNG HỢP	29	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SSD-8TB-007	Ổ cứng 2.5" 7.68TB SSD hiệu Samsung	disk	component	\N	disk	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	7.68TB	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	17587000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Ổ cứng 2.5" 7.68TB SSD hiệu Samsung | SSD | Cụm: CMC1	TỔNG HỢP	30	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SSD-8TB-008	Ổ cứng 2.5" 7.68TB SSD hiệu Samsung	disk	component	\N	disk	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	7.68TB	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	17587000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Ổ cứng 2.5" 7.68TB SSD hiệu Samsung | SSD | Cụm: CMC1	TỔNG HỢP	31	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SSD-8TB-009	Ổ cứng 2.5" 7.68TB SSD hiệu Samsung	disk	component	\N	disk	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	7.68TB	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	17587000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Ổ cứng 2.5" 7.68TB SSD hiệu Samsung | SSD | Cụm: CMC1	TỔNG HỢP	32	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SSD-8TB-010	Ổ cứng 2.5" 7.68TB SSD hiệu Samsung	disk	component	\N	disk	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	7.68TB	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	17587000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Ổ cứng 2.5" 7.68TB SSD hiệu Samsung | SSD | Cụm: CMC1	TỔNG HỢP	33	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SSD-240-001	Ổ cứng 2.5" 240G SSD hiệu Samsung	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	240G	\N	in_stock	Chưa sử dụng	\N	2023-05-04	Đã bàn giao	000000005	1328000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Ổ cứng 2.5" 240G SSD hiệu Samsung | SSD	TỔNG HỢP	34	{}	2026-09-10 02:47:38.301245+00
SSD-240-002	Ổ cứng 2.5" 240G SSD hiệu Samsung	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	240G	\N	in_stock	Chưa sử dụng	\N	2023-05-04	Đã bàn giao	000000005	1328000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Ổ cứng 2.5" 240G SSD hiệu Samsung | SSD	TỔNG HỢP	35	{}	2026-09-10 02:47:38.301245+00
SSD-240-003	Ổ cứng 2.5" 240G SSD hiệu Samsung	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	240G	\N	in_stock	Chưa sử dụng	\N	2023-05-04	Đã bàn giao	000000005	1328000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Ổ cứng 2.5" 240G SSD hiệu Samsung | SSD	TỔNG HỢP	36	{}	2026-09-10 02:47:38.301245+00
SSD-240-004	Ổ cứng 2.5" 240G SSD hiệu Samsung	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	240G	\N	in_stock	Chưa sử dụng	\N	2023-05-04	Đã bàn giao	000000005	1328000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Ổ cứng 2.5" 240G SSD hiệu Samsung | SSD	TỔNG HỢP	37	{}	2026-09-10 02:47:38.301245+00
SSD-960-001	Ổ cứng 2.5" 960GB SSD hiệu Samsung	disk	component	\N	disk	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	mbcadc5	960GB	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	2654000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Ổ cứng 2.5" 960GB SSD hiệu Samsung | SSD | Cụm: MBIN & MBCA	TỔNG HỢP	38	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SSD-960-002	Ổ cứng 2.5" 960GB SSD hiệu Samsung	disk	component	\N	disk	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	mbcadc5	960GB	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	2654000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Ổ cứng 2.5" 960GB SSD hiệu Samsung | SSD | Cụm: MBIN & MBCA	TỔNG HỢP	39	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SSD-960-003	Ổ cứng 2.5" 960GB SSD hiệu Samsung	disk	component	\N	disk	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	mbcadc5	960GB	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	2654000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Ổ cứng 2.5" 960GB SSD hiệu Samsung | SSD | Cụm: MBIN & MBCA	TỔNG HỢP	40	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SSD-960-004	Ổ cứng 2.5" 960GB SSD hiệu Samsung	disk	component	\N	disk	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	mbcadc6	960GB	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	2654000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Ổ cứng 2.5" 960GB SSD hiệu Samsung | SSD | Cụm: MBIN & MBCA	TỔNG HỢP	41	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SSD-960-005	Ổ cứng 2.5" 960GB SSD hiệu Samsung	disk	component	\N	disk	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	mbcadc6	960GB	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	2654000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Ổ cứng 2.5" 960GB SSD hiệu Samsung | SSD | Cụm: MBIN & MBCA	TỔNG HỢP	42	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SSD-960-006	Ổ cứng 2.5" 960GB SSD hiệu Samsung	disk	component	\N	disk	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	mbcadc6	960GB	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	2654000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Ổ cứng 2.5" 960GB SSD hiệu Samsung | SSD | Cụm: MBIN & MBCA	TỔNG HỢP	43	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0001	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1943000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01 | Cáp 40Gb | Cụm: CMC1	TỔNG HỢP	44	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0002	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1943000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01 | Cáp 40Gb | Cụm: CMC1	TỔNG HỢP	45	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0003	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1943000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01 | Cáp 40Gb | Cụm: CMC1	TỔNG HỢP	46	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0004	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1943000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01 | Cáp 40Gb | Cụm: CMC1	TỔNG HỢP	47	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0005	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1943000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01 | Cáp 40Gb | Cụm: CMC1	TỔNG HỢP	48	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0006	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1943000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01 | Cáp 40Gb | Cụm: CMC1	TỔNG HỢP	49	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0007	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1943000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01 | Cáp 40Gb | Cụm: CMC1	TỔNG HỢP	50	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0008	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1943000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01 | Cáp 40Gb | Cụm: CMC1	TỔNG HỢP	51	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0009	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1943000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01 | Cáp 40Gb | Cụm: CMC1	TỔNG HỢP	52	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0010	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1943000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01 | Cáp 40Gb | Cụm: CMC1	TỔNG HỢP	53	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0011	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1943000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01 | Cáp 40Gb | Cụm: CMC1	TỔNG HỢP	54	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0012	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1943000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01 | Cáp 40Gb | Cụm: CMC1	TỔNG HỢP	55	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0013	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1943000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01 | Cáp 40Gb | Cụm: CMC1	TỔNG HỢP	56	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0014	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1943000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 40GbE QSFP CBL -NTWK-0446-01 | Cáp 40Gb | Cụm: CMC1	TỔNG HỢP	57	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0001	Cáp kết nối mạng 10GbE SFP+CBL-0349L	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1193000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 10GbE SFP+CBL-0349L | Cáp 10Gb | Cụm: CMC1	TỔNG HỢP	58	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0002	Cáp kết nối mạng 10GbE SFP+CBL-0349L	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1193000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 10GbE SFP+CBL-0349L | Cáp 10Gb | Cụm: CMC1	TỔNG HỢP	59	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0003	Cáp kết nối mạng 10GbE SFP+CBL-0349L	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1193000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 10GbE SFP+CBL-0349L | Cáp 10Gb | Cụm: CMC1	TỔNG HỢP	60	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0004	Cáp kết nối mạng 10GbE SFP+CBL-0349L	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1193000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 10GbE SFP+CBL-0349L | Cáp 10Gb | Cụm: CMC1	TỔNG HỢP	61	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0005	Cáp kết nối mạng 10GbE SFP+CBL-0349L	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1193000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 10GbE SFP+CBL-0349L | Cáp 10Gb | Cụm: CMC1	TỔNG HỢP	62	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SOFDBC13A	RAM 16GB RAM ECC REG DDR4 BUS 2133 16G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	16G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 16GB RAM ECC REG DDR4 BUS 2133 16G (MICRON) | RAM 16G | Cụm: POC Openstack	TỔNG HỢP	837	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0006	Cáp kết nối mạng 10GbE SFP+CBL-0349L	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1193000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 10GbE SFP+CBL-0349L | Cáp 10Gb | Cụm: CMC1	TỔNG HỢP	63	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0007	Cáp kết nối mạng 10GbE SFP+CBL-0349L	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1193000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 10GbE SFP+CBL-0349L | Cáp 10Gb | Cụm: CMC1	TỔNG HỢP	64	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0008	Cáp kết nối mạng 10GbE SFP+CBL-0349L	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1193000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 10GbE SFP+CBL-0349L | Cáp 10Gb | Cụm: CMC1	TỔNG HỢP	65	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0009	Cáp kết nối mạng 10GbE SFP+CBL-0349L	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1193000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 10GbE SFP+CBL-0349L | Cáp 10Gb | Cụm: CMC1	TỔNG HỢP	66	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0010	Cáp kết nối mạng 10GbE SFP+CBL-0349L	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1193000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 10GbE SFP+CBL-0349L | Cáp 10Gb | Cụm: CMC1	TỔNG HỢP	67	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0011	Cáp kết nối mạng 10GbE SFP+CBL-0349L	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1193000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 10GbE SFP+CBL-0349L | Cáp 10Gb | Cụm: CMC1	TỔNG HỢP	68	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0012	Cáp kết nối mạng 10GbE SFP+CBL-0349L	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1193000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 10GbE SFP+CBL-0349L | Cáp 10Gb | Cụm: CMC1	TỔNG HỢP	69	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0013	Cáp kết nối mạng 10GbE SFP+CBL-0349L	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1193000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 10GbE SFP+CBL-0349L | Cáp 10Gb | Cụm: CMC1	TỔNG HỢP	70	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0014	Cáp kết nối mạng 10GbE SFP+CBL-0349L	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	1193000	MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	36	2026-05-01	Cáp kết nối mạng 10GbE SFP+CBL-0349L | Cáp 10Gb | Cụm: CMC1	TỔNG HỢP	71	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SW-P7-44	Thiết bị chuyển mạch cho mạng LAN_ SWN3 KC3064PQ10GX	switch	component	\N	switch	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	000000005	37900000	MB2197020	CÔNG TY CỔ PHẦN TƯ VẤN VÀ ĐÀO TẠO CÔNG NGHỆ THÔNG TIN VNE	36	2026-05-01	Thiết bị chuyển mạch cho mạng LAN_ SWN3 KC3064PQ10GX | nexus n3k-c3064pq-10gx | Cụm: CMC1	TỔNG HỢP	72	{}	2026-09-10 02:47:38.301245+00
SW-P7-45	Thiết bị chuyển mạch cho mạng LAN_ SWN3 KC3064PQ10GX	switch	component	\N	switch	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	00000086	37900000	MB2197020	CÔNG TY CỔ PHẦN TƯ VẤN VÀ ĐÀO TẠO CÔNG NGHỆ THÔNG TIN VNE	36	2026-05-01	Thiết bị chuyển mạch cho mạng LAN_ SWN3 KC3064PQ10GX | nexus n3k-c3064pq-10gx | Cụm: CMC1	TỔNG HỢP	73	{}	2026-09-10 02:47:38.301245+00
SW-P7-47	Thiết bị chuyển mạch cho mạng LAN_ WS-C3850 -48T-L	switch	component	\N	switch	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	00000086	19400000	MB2197020	CÔNG TY CỔ PHẦN TƯ VẤN VÀ ĐÀO TẠO CÔNG NGHỆ THÔNG TIN VNE	36	2026-05-01	Thiết bị chuyển mạch cho mạng LAN_ WS-C3850 -48T-L | cisco ws-c3850-48t-l | Cụm: CMC1	TỔNG HỢP	74	{}	2026-09-10 02:47:38.301245+00
SW-P7-48	Thiết bị chuyển mạch cho mạng LAN_ WS-C3850 -48T-L	switch	component	\N	switch	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	00000086	19400000	MB2197020	CÔNG TY CỔ PHẦN TƯ VẤN VÀ ĐÀO TẠO CÔNG NGHỆ THÔNG TIN VNE	36	2026-05-01	Thiết bị chuyển mạch cho mạng LAN_ WS-C3850 -48T-L | cisco ws-c3850-48t-l | Cụm: CMC1	TỔNG HỢP	75	{}	2026-09-10 02:47:38.301245+00
CAP-STACK-001	Cáp dùng cho thiết bị mạng_STACK-T1-50CM	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	00000086	1230000	MB2197020	CÔNG TY CỔ PHẦN TƯ VẤN VÀ ĐÀO TẠO CÔNG NGHỆ THÔNG TIN VNE	36	2026-05-01	Cáp dùng cho thiết bị mạng_STACK-T1-50CM | Cáp Stack | Cụm: CMC1	TỔNG HỢP	76	{}	2026-09-10 02:47:38.301245+00
CAP-STACK-002	Cáp dùng cho thiết bị mạng_STACK-T1-50CM	cable	component	\N	cáp	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2024-05-04	2023-05-04	Đã bàn giao	00000086	1230000	MB2197020	CÔNG TY CỔ PHẦN TƯ VẤN VÀ ĐÀO TẠO CÔNG NGHỆ THÔNG TIN VNE	36	2026-05-01	Cáp dùng cho thiết bị mạng_STACK-T1-50CM | Cáp Stack | Cụm: CMC1	TỔNG HỢP	77	{}	2026-09-10 02:47:38.301245+00
NGUON-600-001	Bộ nguồn máy chủ Supermicro 600W Platinum	power_supply	component	\N	Nguồn	monitor	Kho	Kho	32	\N	\N	\N	\N	\N	SVR-J2-3334	in_use	Đang sử dụng	2024-04-23	2024-04-23	Đã bàn giao	00000003	4455000	MB2194010	Công Ty TNHH Kỹ Thuật Hạ Tầng IT	1	2024-04-23	Bộ nguồn máy chủ Supermicro 600W Platinum | Nguồn | Cụm: monitor	TỔNG HỢP	78	{unmapped_ip_or_type}	2026-09-10 02:47:38.301245+00
SVR-J5-0607	Cluster801	network_or_host	component	103.15.49.73	103.15.49.73	Cluster8	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-05-01	\N	\N	\N	\N	\N	\N	\N	\N	Cluster801 | Cụm: Cluster8	TỔNG HỢP	79	{}	2026-09-10 02:47:38.301245+00
SVR-J5-0910	Cluster802	network_or_host	component	103.15.49.74	103.15.49.74	Cluster8	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-05-01	\N	\N	\N	\N	\N	\N	\N	\N	Cluster802 | Cụm: Cluster8	TỔNG HỢP	80	{}	2026-09-10 02:47:38.301245+00
SVR-J5-1112	Cluster803	network_or_host	component	103.15.49.75	103.15.49.75	Cluster8	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-05-01	\N	\N	\N	\N	\N	\N	\N	\N	Cluster803 | Cụm: Cluster8	TỔNG HỢP	81	{}	2026-09-10 02:47:38.301245+00
SVR-J5-1415	Cluster804	network_or_host	component	103.15.49.76	103.15.49.76	Cluster8	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-05-01	\N	\N	\N	\N	\N	\N	\N	\N	Cluster804 | Cụm: Cluster8	TỔNG HỢP	82	{}	2026-09-10 02:47:38.301245+00
SVR-J5-1617	Cluster805	network_or_host	component	103.15.49.77	103.15.49.77	Cluster8	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-05-01	\N	\N	\N	\N	\N	\N	\N	\N	Cluster805 | Cụm: Cluster8	TỔNG HỢP	83	{}	2026-09-10 02:47:38.301245+00
SVR-J5-1920	Cluster806	network_or_host	component	103.15.49.79	103.15.49.79	Cluster8	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-05-01	\N	\N	\N	\N	\N	\N	\N	\N	Cluster806 | Cụm: Cluster8	TỔNG HỢP	84	{}	2026-09-10 02:47:38.301245+00
SVR-J5-2122	Cluster807	network_or_host	component	103.15.49.72	103.15.49.72	Cluster8	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-05-01	\N	\N	\N	\N	\N	\N	\N	\N	Cluster807 | Cụm: Cluster8	TỔNG HỢP	85	{}	2026-09-10 02:47:38.301245+00
SVR-J5-2425	Cluster808	network_or_host	component	103.15.49.162	103.15.49.162	Cluster8	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-05-01	\N	\N	\N	\N	\N	\N	\N	\N	Cluster808 | Cụm: Cluster8	TỔNG HỢP	86	{}	2026-09-10 02:47:38.301245+00
SVR-J5-2627	Cluster809	network_or_host	component	103.15.49.160	103.15.49.160	Cluster8	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-05-01	\N	\N	\N	\N	\N	\N	\N	\N	Cluster809 | Cụm: Cluster8	TỔNG HỢP	87	{}	2026-09-10 02:47:38.301245+00
SVR-J5-2930	Cluster810	network_or_host	component	103.15.49.186	103.15.49.186	Cluster8	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use_needs_replacement	Đang sử dụng cần được thay thế	2019-05-01	\N	\N	\N	\N	\N	\N	\N	\N	Cluster810 | Cụm: Cluster8	TỔNG HỢP	88	{}	2026-09-10 02:47:38.301245+00
SVR-J5-3132	Cluster811	network_or_host	component	103.15.49.180	103.15.49.180	Cluster8	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use_needs_replacement	Đang sử dụng cần được thay thế	2019-05-01	\N	\N	\N	\N	\N	\N	\N	\N	Cluster811 | Cụm: Cluster8	TỔNG HỢP	89	{}	2026-09-10 02:47:38.301245+00
SVR-J5-3435	Cluster812	network_or_host	component	103.15.49.187	103.15.49.187	Cluster8	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use_needs_replacement	Đang sử dụng cần được thay thế	2019-05-01	\N	\N	\N	\N	\N	\N	\N	\N	Cluster812 | Cụm: Cluster8	TỔNG HỢP	90	{}	2026-09-10 02:47:38.301245+00
SVR-J5-3637	Cluster813	network_or_host	component	103.15.49.188	103.15.49.188	Cluster8	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use_needs_replacement	Đang sử dụng cần được thay thế	2019-05-01	\N	\N	\N	\N	\N	\N	\N	\N	Cluster813 | Cụm: Cluster8	TỔNG HỢP	91	{}	2026-09-10 02:47:38.301245+00
SW-J5-39	nexus n3k-c3064pq-10gx	switch	component	\N	switch	Cluster8	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-05-01	\N	\N	\N	\N	\N	\N	\N	\N	nexus n3k-c3064pq-10gx | Cụm: Cluster8	TỔNG HỢP	92	{}	2026-09-10 02:47:38.301245+00
SW-J5-40	nexus n3k-c3064pq-10gx	switch	component	\N	switch	Cluster8	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-05-01	\N	\N	\N	\N	\N	\N	\N	\N	nexus n3k-c3064pq-10gx | Cụm: Cluster8	TỔNG HỢP	93	{}	2026-09-10 02:47:38.301245+00
SW-J5-43	Cisco WS-C3750E-48PD	switch	component	\N	switch	Cluster8	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-05-01	\N	\N	\N	\N	\N	\N	\N	\N	Cisco WS-C3750E-48PD | Cụm: Cluster8	TỔNG HỢP	94	{}	2026-09-10 02:47:38.301245+00
SW-J5-45	nexus n3k-c3064pq-10gx	switch	component	\N	switch	\N	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-05-01	\N	\N	\N	\N	\N	\N	\N	\N	nexus n3k-c3064pq-10gx	TỔNG HỢP	95	{}	2026-09-10 02:47:38.301245+00
SW-J5-46	nexus n3k-c3064pq-10gx	switch	component	\N	switch	\N	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-05-01	\N	\N	\N	\N	\N	\N	\N	\N	nexus n3k-c3064pq-10gx	TỔNG HỢP	96	{}	2026-09-10 02:47:38.301245+00
SVR-J6-1516	backup	network_or_host	component	103.15.49.64	103.15.49.64	backup	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_stock	Chưa sử dụng	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	backup | Cụm: backup	TỔNG HỢP	97	{}	2026-09-10 02:47:38.301245+00
SVR-J6-1819	cluster910	network_or_host	component	103.15.49.65	103.15.49.65	Cluster9	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use_needs_replacement	Đang sử dụng cần được thay thế	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	cluster910 | Cụm: Cluster9	TỔNG HỢP	98	{}	2026-09-10 02:47:38.301245+00
SVR-J6-2021	cluster913	network_or_host	component	103.15.49.37	103.15.49.37	Cluster9	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use_needs_replacement	Đang sử dụng cần được thay thế	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	cluster913 | Cụm: Cluster9	TỔNG HỢP	99	{}	2026-09-10 02:47:38.301245+00
SVR-J6-2324	cluster914	network_or_host	component	103.15.49.36	103.15.49.36	Cluster9	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use_needs_replacement	Đang sử dụng cần được thay thế	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	cluster914 | Cụm: Cluster9	TỔNG HỢP	100	{}	2026-09-10 02:47:38.301245+00
SVR-J6-2526	cluster924	network_or_host	component	103.15.49.181	103.15.49.181	Cluster9	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use_needs_replacement	Đang sử dụng cần được thay thế	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	cluster924 | Cụm: Cluster9	TỔNG HỢP	101	{}	2026-09-10 02:47:38.301245+00
SVR-J6-4041	cluster927	network_or_host	component	103.15.49.38	103.15.49.38	Cluster9	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use_needs_replacement	Đang sử dụng cần được thay thế	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	cluster927 | Cụm: Cluster9	TỔNG HỢP	104	{}	2026-09-10 02:47:38.301245+00
SVR-J6-3839	cluster928	network_or_host	component	103.15.49.39	103.15.49.39	Cluster9	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use_needs_replacement	Đang sử dụng cần được thay thế	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	cluster928 | Cụm: Cluster9	TỔNG HỢP	105	{}	2026-09-10 02:47:38.301245+00
SVR-J6-3536	cluster929	network_or_host	component	103.15.49.40	103.15.49.40	Cluster9	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use_needs_replacement	Đang sử dụng cần được thay thế	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	cluster929 | Cụm: Cluster9	TỔNG HỢP	106	{}	2026-09-10 02:47:38.301245+00
SVR-J6-3334	cluster930	network_or_host	component	103.15.49.46	103.15.49.46	Cluster9	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use_needs_replacement	Đang sử dụng cần được thay thế	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	cluster930 | Cụm: Cluster9	TỔNG HỢP	107	{}	2026-09-10 02:47:38.301245+00
SW-J6-43	nexus n3k-c3064pq-10gx	switch	component	\N	switch	Cluster9	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	nexus n3k-c3064pq-10gx | Cụm: Cluster9	TỔNG HỢP	108	{}	2026-09-10 02:47:38.301245+00
SW-J6-44	nexus n3k-c3064pq-10gx	switch	component	\N	switch	Cluster9	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	nexus n3k-c3064pq-10gx | Cụm: Cluster9	TỔNG HỢP	109	{}	2026-09-10 02:47:38.301245+00
SW-J6-46	Cisco WS-C2970G-24TS-E	switch	component	\N	switch	Cluster9	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	Cisco WS-C2970G-24TS-E | Cụm: Cluster9	TỔNG HỢP	110	{}	2026-09-10 02:47:38.301245+00
SVR-J3-2425	extra backup	server	server	\N	server	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_stock	Chưa sử dụng	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	extra backup | Cụm: ClusterX1	TỔNG HỢP	111	{}	2026-09-10 02:47:38.301245+00
SVR-J3-2627	backup	server	server	\N	server	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_stock	Chưa sử dụng	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	backup | Cụm: ClusterX1	TỔNG HỢP	112	{}	2026-09-10 02:47:38.301245+00
SVR-J3-2931	clusterx102	network_or_host	component	103.15.49.42	103.15.49.42	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	clusterx102 | Cụm: ClusterX1	TỔNG HỢP	113	{}	2026-09-10 02:47:38.301245+00
SVR-J3-3234	clusterx103	network_or_host	component	103.15.49.43	103.15.49.43	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	clusterx103 | Cụm: ClusterX1	TỔNG HỢP	114	{}	2026-09-10 02:47:38.301245+00
SVR-J3-3637	clusterx110	network_or_host	component	103.15.49.66	103.15.49.66	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	clusterx110 | Cụm: ClusterX1	TỔNG HỢP	115	{}	2026-09-10 02:47:38.301245+00
SVR-J3-3839	clusterx111	network_or_host	component	103.15.49.164	103.15.49.164	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	clusterx111 | Cụm: ClusterX1	TỔNG HỢP	116	{}	2026-09-10 02:47:38.301245+00
SVR-J3-4142	clusterx112	network_or_host	component	103.15.49.171	103.15.49.171	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	clusterx112 | Cụm: ClusterX1	TỔNG HỢP	117	{}	2026-09-10 02:47:38.301245+00
SVR-J3-4344	clusterx113	network_or_host	component	103.15.49.167	103.15.49.167	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	clusterx113 | Cụm: ClusterX1	TỔNG HỢP	118	{}	2026-09-10 02:47:38.301245+00
SW-J3-45	Cisco Nexus 3048	switch	component	\N	switch	\N	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	Cisco Nexus 3048	TỔNG HỢP	119	{}	2026-09-10 02:47:38.301245+00
SW-J3-46	Cisco Nexus 3048	switch	component	\N	switch	\N	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	Cisco Nexus 3048	TỔNG HỢP	120	{}	2026-09-10 02:47:38.301245+00
SVR-J4-0304	clusterx114	network_or_host	component	103.15.49.169	103.15.49.169	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	clusterx114 | Cụm: ClusterX1	TỔNG HỢP	121	{}	2026-09-10 02:47:38.301245+00
SVR-J4-0506	clusterx115	network_or_host	component	103.15.49.165	103.15.49.165	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	clusterx115 | Cụm: ClusterX1	TỔNG HỢP	122	{}	2026-09-10 02:47:38.301245+00
SVR-J4-0809	clusterx116	network_or_host	component	103.15.49.204	103.15.49.204	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	clusterx116 | Cụm: ClusterX1	TỔNG HỢP	123	{}	2026-09-10 02:47:38.301245+00
SVR-J4-1011	clusterx118	network_or_host	component	103.15.49.201	103.15.49.201	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	clusterx118 | Cụm: ClusterX1	TỔNG HỢP	124	{}	2026-09-10 02:47:38.301245+00
SVR-J4-1314	clusterx119	network_or_host	component	103.15.49.202	103.15.49.202	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	clusterx119 | Cụm: ClusterX1	TỔNG HỢP	125	{}	2026-09-10 02:47:38.301245+00
SVR-J4-1516	clusterx120	network_or_host	component	103.15.49.203	103.15.49.203	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	clusterx120 | Cụm: ClusterX1	TỔNG HỢP	126	{}	2026-09-10 02:47:38.301245+00
SVR-J4-1819	clusterx123	network_or_host	component	103.15.49.176	103.15.49.176	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	clusterx123 | Cụm: ClusterX1	TỔNG HỢP	127	{}	2026-09-10 02:47:38.301245+00
SVR-J4-2021	clusterx124	network_or_host	component	103.15.49.177	103.15.49.177	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	clusterx124 | Cụm: ClusterX1	TỔNG HỢP	128	{}	2026-09-10 02:47:38.301245+00
SVR-J4-2324	clusterx125	network_or_host	component	103.15.49.183	103.15.49.183	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	clusterx125 | Cụm: ClusterX1	TỔNG HỢP	129	{}	2026-09-10 02:47:38.301245+00
SVR-J4-2526	clusterx126	network_or_host	component	103.15.49.184	103.15.49.184	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	clusterx126 | Cụm: ClusterX1	TỔNG HỢP	130	{}	2026-09-10 02:47:38.301245+00
SVR-J4-2829	clusterx127	network_or_host	component	103.15.49.185	103.15.49.185	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	clusterx127 | Cụm: ClusterX1	TỔNG HỢP	131	{}	2026-09-10 02:47:38.301245+00
SVR-J4-3031	clusterx128	network_or_host	component	103.15.49.253	103.15.49.253	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	clusterx128 | Cụm: ClusterX1	TỔNG HỢP	132	{}	2026-09-10 02:47:38.301245+00
SVR-J4-4041	clusterx129	network_or_host	component	103.15.49.81	103.15.49.81	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	clusterx129 | Cụm: ClusterX1	TỔNG HỢP	133	{}	2026-09-10 02:47:38.301245+00
SVR-J4-3839	clusterx130	network_or_host	component	103.15.49.67	103.15.49.67	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	clusterx130 | Cụm: ClusterX1	TỔNG HỢP	134	{}	2026-09-10 02:47:38.301245+00
SVR-J4-3536	clusterx131	network_or_host	component	103.15.49.80	103.15.49.80	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	clusterx131 | Cụm: ClusterX1	TỔNG HỢP	135	{}	2026-09-10 02:47:38.301245+00
SVR-J4-3334	clusterx132	network_or_host	component	103.15.49.48	103.15.49.48	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	clusterx132 | Cụm: ClusterX1	TỔNG HỢP	136	{}	2026-09-10 02:47:38.301245+00
SW-J4-43	nexus n3k-c3064pq-10gx	switch	component	\N	switch	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	nexus n3k-c3064pq-10gx | Cụm: ClusterX1	TỔNG HỢP	137	{}	2026-09-10 02:47:38.301245+00
SVR-J6-0910	mbo-node1	network_or_host	component	103.15.49.7	103.15.49.7	MBO	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	mbo-node1 | Cụm: MBO	TỔNG HỢP	140	{}	2026-09-10 02:47:38.301245+00
SVR-J6-0708	mbo-node2	network_or_host	component	103.15.49.8	103.15.49.8	MBO	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	mbo-node2 | Cụm: MBO	TỔNG HỢP	141	{}	2026-09-10 02:47:38.301245+00
SVR-J6-0405	mbo-node3	network_or_host	component	103.15.49.9	103.15.49.9	MBO	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	mbo-node3 | Cụm: MBO	TỔNG HỢP	142	{}	2026-09-10 02:47:38.301245+00
SVR-AQ53-3031	vnpt101	network_or_host	component	103.138.89.132	103.138.89.132	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2020-07-01	\N	\N	\N	\N	\N	\N	\N	\N	vnpt101 | Cụm: VNPT1	TỔNG HỢP	143	{}	2026-09-10 02:47:38.301245+00
SVR-AQ53-1718	vnpt102	network_or_host	component	103.138.89.133	103.138.89.133	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2020-07-01	\N	\N	\N	\N	\N	\N	\N	\N	vnpt102 | Cụm: VNPT1	TỔNG HỢP	144	{}	2026-09-10 02:47:38.301245+00
SVR-AQ53-2627	vnpt103	network_or_host	component	103.138.89.134	103.138.89.134	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2020-07-01	\N	\N	\N	\N	\N	\N	\N	\N	vnpt103 | Cụm: VNPT1	TỔNG HỢP	145	{}	2026-09-10 02:47:38.301245+00
SVR-AQ53-2425	vnpt104	network_or_host	component	103.138.89.135	103.138.89.135	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2020-07-01	\N	\N	\N	\N	\N	\N	\N	\N	vnpt104 | Cụm: VNPT1	TỔNG HỢP	146	{}	2026-09-10 02:47:38.301245+00
SVR-AQ53-2223	vnpt105	network_or_host	component	103.138.89.136	103.138.89.136	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2020-07-01	\N	\N	\N	\N	\N	\N	\N	\N	vnpt105 | Cụm: VNPT1	TỔNG HỢP	147	{}	2026-09-10 02:47:38.301245+00
SVR-AQ53-2021	vnpt106	network_or_host	component	103.138.89.137	103.138.89.137	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2020-07-01	\N	\N	\N	\N	\N	\N	\N	\N	vnpt106 | Cụm: VNPT1	TỔNG HỢP	148	{}	2026-09-10 02:47:38.301245+00
SVR-AQ54-3637	vnpt107	network_or_host	component	103.138.89.138	103.138.89.138	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2020-07-01	\N	\N	\N	\N	\N	\N	\N	\N	vnpt107 | Cụm: VNPT1	TỔNG HỢP	149	{}	2026-09-10 02:47:38.301245+00
SVR-AQ54-3435	vnpt108	network_or_host	component	103.138.89.139	103.138.89.139	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2020-07-01	\N	\N	\N	\N	\N	\N	\N	\N	vnpt108 | Cụm: VNPT1	TỔNG HỢP	150	{}	2026-09-10 02:47:38.301245+00
SVR-AQ54-3233	vnpt109	network_or_host	component	103.138.89.140	103.138.89.140	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2020-07-01	\N	\N	\N	\N	\N	\N	\N	\N	vnpt109 | Cụm: VNPT1	TỔNG HỢP	151	{}	2026-09-10 02:47:38.301245+00
SVR-AQ54-2930	vnpt110	network_or_host	component	103.138.89.141	103.138.89.141	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	vnpt110 | Cụm: VNPT1	TỔNG HỢP	152	{}	2026-09-10 02:47:38.301245+00
SVR-AQ54-2627	vnpt111	network_or_host	component	103.138.89.142	103.138.89.142	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	vnpt111 | Cụm: VNPT1	TỔNG HỢP	153	{}	2026-09-10 02:47:38.301245+00
SVR-AQ54-2324	vnpt112	network_or_host	component	103.138.89.143	103.138.89.143	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	vnpt112 | Cụm: VNPT1	TỔNG HỢP	154	{}	2026-09-10 02:47:38.301245+00
SW-AQ53-32	nexus n3k-c3132q-40ge	switch	component	\N	switch	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2020-07-01	\N	\N	\N	\N	\N	\N	\N	\N	nexus n3k-c3132q-40ge | Cụm: VNPT1	TỔNG HỢP	155	{}	2026-09-10 02:47:38.301245+00
SW-AQ53-33	nexus n3k-c3132q-40ge	switch	component	\N	switch	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2020-07-01	\N	\N	\N	\N	\N	\N	\N	\N	nexus n3k-c3132q-40ge | Cụm: VNPT1	TỔNG HỢP	156	{}	2026-09-10 02:47:38.301245+00
SW-AQ53-35	nexus n3k-c3064pq-10gx	switch	component	\N	switch	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2020-07-01	\N	\N	\N	\N	\N	\N	\N	\N	nexus n3k-c3064pq-10gx | Cụm: VNPT1	TỔNG HỢP	157	{}	2026-09-10 02:47:38.301245+00
SW-AQ53-36	nexus n3k-c3064pq-10gx	switch	component	\N	switch	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2020-07-01	\N	\N	\N	\N	\N	\N	\N	\N	nexus n3k-c3064pq-10gx | Cụm: VNPT1	TỔNG HỢP	158	{}	2026-09-10 02:47:38.301245+00
SVR-BD51-1314	mbcadc1	server	server	\N	server	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	mbcadc1 | Cụm: MBIN & MBCA	TỔNG HỢP	159	{}	2026-09-10 02:47:38.301245+00
SVR-BD51-1617	mbcadc2	server	server	\N	server	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	mbcadc2 | Cụm: MBIN & MBCA	TỔNG HỢP	160	{}	2026-09-10 02:47:38.301245+00
SVR-BD51-1920	mbcadc3	server	server	\N	server	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	mbcadc3 | Cụm: MBIN & MBCA	TỔNG HỢP	161	{}	2026-09-10 02:47:38.301245+00
SVR-BD51-3940	mbcadc4	server	server	\N	server	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	mbcadc4 | Cụm: MBIN & MBCA	TỔNG HỢP	162	{}	2026-09-10 02:47:38.301245+00
SVR-BD51-3738	mbcadc5	server	server	\N	server	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	mbcadc5 | Cụm: MBIN & MBCA	TỔNG HỢP	163	{}	2026-09-10 02:47:38.301245+00
SVR-BD51-3536	mbcadc6	server	server	\N	server	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	mbcadc6 | Cụm: MBIN & MBCA	TỔNG HỢP	164	{}	2026-09-10 02:47:38.301245+00
NAS-BD51-3334	NASDC	server	server	\N	server	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2022-07-01	\N	\N	\N	\N	\N	\N	\N	\N	NASDC | Cụm: MBIN & MBCA	TỔNG HỢP	165	{}	2026-09-10 02:47:38.301245+00
FW-BD51-10	FortiGate FG-80F	firewall	component	\N	fỉewall	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2022-07-01	\N	\N	\N	\N	\N	\N	\N	\N	FortiGate FG-80F | Cụm: MBIN & MBCA	TỔNG HỢP	166	{"duplicate_source_rows:166,167"}	2026-09-10 02:47:38.301245+00
HSM-BD51-0405	Trident HSM	hsm	component	\N	HSM	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2022-07-01	\N	\N	\N	\N	\N	\N	\N	\N	Trident HSM | Cụm: MBIN & MBCA	TỔNG HỢP	168	{unmapped_ip_or_type}	2026-09-10 02:47:38.301245+00
HSM-BD51-0607	Trident HSM	hsm	component	\N	HSM	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2022-07-01	\N	\N	\N	\N	\N	\N	\N	\N	Trident HSM | Cụm: MBIN & MBCA	TỔNG HỢP	169	{unmapped_ip_or_type}	2026-09-10 02:47:38.301245+00
HSM-BD51-27	Securosys HSM	hsm	component	\N	HSM	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2022-07-01	\N	\N	\N	\N	\N	\N	\N	\N	Securosys HSM | Cụm: MBIN & MBCA	TỔNG HỢP	170	{unmapped_ip_or_type}	2026-09-10 02:47:38.301245+00
HSM-BD51-29	Securosys HSM	hsm	component	\N	HSM	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2022-07-01	\N	\N	\N	\N	\N	\N	\N	\N	Securosys HSM | Cụm: MBIN & MBCA	TỔNG HỢP	171	{unmapped_ip_or_type}	2026-09-10 02:47:38.301245+00
HSM-BD51-31	Securosys HSM	hsm	component	\N	HSM	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2022-07-01	\N	\N	\N	\N	\N	\N	\N	\N	Securosys HSM | Cụm: MBIN & MBCA	TỔNG HỢP	172	{unmapped_ip_or_type}	2026-09-10 02:47:38.301245+00
FW-BD51-08	FortiGate FG-100E	firewall	component	\N	fỉewall	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2021-07-01	\N	\N	\N	\N	\N	\N	\N	\N	FortiGate FG-100E | Cụm: MBIN & MBCA	TỔNG HỢP	173	{}	2026-09-10 02:47:38.301245+00
FW-BD51-09	FortiGate FG-100E	firewall	component	\N	fỉewall	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2021-07-01	\N	\N	\N	\N	\N	\N	\N	\N	FortiGate FG-100E | Cụm: MBIN & MBCA	TỔNG HỢP	174	{}	2026-09-10 02:47:38.301245+00
SW-BD51-11	Cisco C3750	switch	component	\N	switch	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-01-01	\N	\N	\N	\N	\N	\N	\N	\N	Cisco C3750 | Cụm: MBIN & MBCA	TỔNG HỢP	175	{}	2026-09-10 02:47:38.301245+00
SW-BD51-12	Cisco C3750	switch	component	\N	switch	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-01-01	\N	\N	\N	\N	\N	\N	\N	\N	Cisco C3750 | Cụm: MBIN & MBCA	TỔNG HỢP	176	{}	2026-09-10 02:47:38.301245+00
SW-BD51-22	Nexus C3064	switch	component	\N	switch	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2021-07-01	\N	\N	\N	\N	\N	\N	\N	\N	Nexus C3064 | Cụm: MBIN & MBCA	TỔNG HỢP	177	{}	2026-09-10 02:47:38.301245+00
SW-BD51-23	Nexus C3064	switch	component	\N	switch	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2021-07-01	\N	\N	\N	\N	\N	\N	\N	\N	Nexus C3064 | Cụm: MBIN & MBCA	TỔNG HỢP	178	{}	2026-09-10 02:47:38.301245+00
SVR-M08-3132	mbcadr1	server	server	\N	server	MBIN & MBCA	CMC Quận 9	CMC Quận 9	176	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	mbcadr1 | Cụm: MBIN & MBCA	TỔNG HỢP	179	{}	2026-09-10 02:47:38.301245+00
SVR-M08-2829	mbcadr2	server	server	\N	server	MBIN & MBCA	CMC Quận 9	CMC Quận 9	176	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	mbcadr2 | Cụm: MBIN & MBCA	TỔNG HỢP	180	{}	2026-09-10 02:47:38.301245+00
SVR-M08-2526	mbcadr3	server	server	\N	server	MBIN & MBCA	CMC Quận 9	CMC Quận 9	176	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	mbcadr3 | Cụm: MBIN & MBCA	TỔNG HỢP	181	{}	2026-09-10 02:47:38.301245+00
NAS-M08-3435	NASDR	server	server	\N	server	MBIN & MBCA	CMC Quận 9	CMC Quận 9	176	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2022-07-01	\N	\N	\N	\N	\N	\N	\N	\N	NASDR | Cụm: MBIN & MBCA	TỔNG HỢP	182	{}	2026-09-10 02:47:38.301245+00
FW-M08-42	FortiGate FG-80F	firewall	component	\N	fỉewall	MBIN & MBCA	CMC Quận 9	CMC Quận 9	176	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2022-07-01	\N	\N	\N	\N	\N	\N	\N	\N	FortiGate FG-80F | Cụm: MBIN & MBCA	TỔNG HỢP	183	{}	2026-09-10 02:47:38.301245+00
FW-M08-41	FortiGate FG-100E	firewall	component	\N	fỉewall	MBIN & MBCA	CMC Quận 9	CMC Quận 9	176	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2021-07-01	\N	\N	\N	\N	\N	\N	\N	\N	FortiGate FG-100E | Cụm: MBIN & MBCA	TỔNG HỢP	184	{}	2026-09-10 02:47:38.301245+00
SW-M08-38	Cisco C3750	switch	component	\N	switch	MBIN & MBCA	CMC Quận 9	CMC Quận 9	176	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-01-01	\N	\N	\N	\N	\N	\N	\N	\N	Cisco C3750 | Cụm: MBIN & MBCA	TỔNG HỢP	185	{}	2026-09-10 02:47:38.301245+00
HSM-M08-37	Securosys HSM	hsm	component	\N	HSM	MBIN & MBCA	CMC Quận 9	CMC Quận 9	176	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2022-07-01	\N	\N	\N	\N	\N	\N	\N	\N	Securosys HSM | Cụm: MBIN & MBCA	TỔNG HỢP	186	{unmapped_ip_or_type}	2026-09-10 02:47:38.301245+00
HSM-M08-2324	Trident HSM	hsm	component	\N	HSM	MBIN & MBCA	CMC Quận 9	CMC Quận 9	176	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2022-07-01	\N	\N	\N	\N	\N	\N	\N	\N	Trident HSM | Cụm: MBIN & MBCA	TỔNG HỢP	187	{unmapped_ip_or_type}	2026-09-10 02:47:38.301245+00
SVR-J3-1819	bk01	network_or_host	component	103.15.49.190	103.15.49.190	backup	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-01-01	\N	\N	\N	\N	\N	\N	\N	\N	bk01 | Cụm: backup	TỔNG HỢP	188	{}	2026-09-10 02:47:38.301245+00
SVR-J3-1617	bk02	network_or_host	component	103.15.49.191	103.15.49.191	backup	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-01-01	\N	\N	\N	\N	\N	\N	\N	\N	bk02 | Cụm: backup	TỔNG HỢP	189	{}	2026-09-10 02:47:38.301245+00
SVR-J3-1314	bk03	network_or_host	component	103.15.49.192	103.15.49.192	backup	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-01-01	\N	\N	\N	\N	\N	\N	\N	\N	bk03 | Cụm: backup	TỔNG HỢP	190	{}	2026-09-10 02:47:38.301245+00
SVR-J3-1112	bk04	network_or_host	component	103.15.49.193	103.15.49.193	backup	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-01-01	\N	\N	\N	\N	\N	\N	\N	\N	bk04 | Cụm: backup	TỔNG HỢP	191	{}	2026-09-10 02:47:38.301245+00
DAS-J3-0104	DASbk1	server	server	\N	server	backup	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-01-01	\N	\N	\N	\N	\N	\N	\N	\N	DASbk1 | Cụm: backup	TỔNG HỢP	192	{}	2026-09-10 02:47:38.301245+00
DAS-J3-0609	DASbk2	server	server	\N	server	backup	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2017-01-01	\N	\N	\N	\N	\N	\N	\N	\N	DASbk2 | Cụm: backup	TỔNG HỢP	193	{}	2026-09-10 02:47:38.301245+00
SVR-J2-4244	ops1	network_or_host	component	103.15.48.251	103.15.48.251	monitor	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	ops1 | Cụm: monitor	TỔNG HỢP	194	{}	2026-09-10 02:47:38.301245+00
SVR-J2-3941	ops2	network_or_host	component	103.15.48.252	103.15.48.252	monitor	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	ops2 | Cụm: monitor	TỔNG HỢP	195	{}	2026-09-10 02:47:38.301245+00
SVR-J2-3537	ops3	network_or_host	component	103.15.48.253	103.15.48.253	monitor	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	ops3 | Cụm: monitor	TỔNG HỢP	196	{}	2026-09-10 02:47:38.301245+00
SW-J2-46	nexus n3k-c3064pq-10gx	switch	component	\N	switch	monitor	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	nexus n3k-c3064pq-10gx | Cụm: monitor	TỔNG HỢP	197	{}	2026-09-10 02:47:38.301245+00
SW-J2-45	Cisco WS-C3750E-48PD	switch	component	\N	switch	monitor	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	Cisco WS-C3750E-48PD | Cụm: monitor	TỔNG HỢP	198	{}	2026-09-10 02:47:38.301245+00
SSD-SS-001	SSD Samsung 960GB Sata Enterprise PM893 - MZ7L3960HCJR	disk	component	\N	disk	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	mbcadc4	960GB	\N	in_use	Đang sử dụng	2024-06-08	\N	Đã bàn giao	\N	4730000	\N	CÔNG TY CỔ PHẦN GIẢI PHÁP MÁY CHỦ VIỆT	36	2027-08-03	SSD Samsung 960GB Sata Enterprise PM893 - MZ7L3960HCJR | SSD | Cụm: MBIN & MBCA	TỔNG HỢP	199	{parent_reference_unresolved,handover_date_missing}	2026-09-10 02:47:38.301245+00
SSD-SS-002	SSD Samsung 960GB Sata Enterprise PM893 - MZ7L3960HCJR	disk	component	\N	disk	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	mbcadc4	960GB	\N	in_use	Đang sử dụng	2024-06-08	\N	Đã bàn giao	\N	4730000	\N	CÔNG TY CỔ PHẦN GIẢI PHÁP MÁY CHỦ VIỆT	36	2027-08-03	SSD Samsung 960GB Sata Enterprise PM893 - MZ7L3960HCJR | SSD | Cụm: MBIN & MBCA	TỔNG HỢP	200	{parent_reference_unresolved,handover_date_missing}	2026-09-10 02:47:38.301245+00
SSD-SS-003	SSD Samsung 960GB Sata Enterprise PM893 - MZ7L3960HCJR	disk	component	\N	disk	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	mbcadc5	960GB	\N	in_use	Đang sử dụng	2024-06-08	\N	Đã bàn giao	\N	4730000	\N	CÔNG TY CỔ PHẦN GIẢI PHÁP MÁY CHỦ VIỆT	36	2027-08-03	SSD Samsung 960GB Sata Enterprise PM893 - MZ7L3960HCJR | SSD | Cụm: MBIN & MBCA	TỔNG HỢP	201	{parent_reference_unresolved,handover_date_missing}	2026-09-10 02:47:38.301245+00
SSD-SS-004	SSD Samsung 960GB Sata Enterprise PM893 - MZ7L3960HCJR	disk	component	\N	disk	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	mbcadc5	960GB	\N	in_use	Đang sử dụng	2024-06-08	\N	Đã bàn giao	\N	4730000	\N	CÔNG TY CỔ PHẦN GIẢI PHÁP MÁY CHỦ VIỆT	36	2027-08-03	SSD Samsung 960GB Sata Enterprise PM893 - MZ7L3960HCJR | SSD | Cụm: MBIN & MBCA	TỔNG HỢP	202	{parent_reference_unresolved,handover_date_missing}	2026-09-10 02:47:38.301245+00
SSD-SS-005	SSD Samsung 960GB Sata Enterprise PM893 - MZ7L3960HCJR	disk	component	\N	disk	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	mbcadc6	960GB	\N	in_use	Đang sử dụng	2024-06-08	\N	Đã bàn giao	\N	4730000	\N	CÔNG TY CỔ PHẦN GIẢI PHÁP MÁY CHỦ VIỆT	36	2027-08-03	SSD Samsung 960GB Sata Enterprise PM893 - MZ7L3960HCJR | SSD | Cụm: MBIN & MBCA	TỔNG HỢP	203	{parent_reference_unresolved,handover_date_missing}	2026-09-10 02:47:38.301245+00
SSD-SS-006	SSD Samsung 1.92TB Sata Enterprise PM893- MZ7L31T9HBLT	disk	component	\N	disk	Cluster9	ODS	ODS	1	\N	\N	\N	cluster914	1.92TB	\N	in_use	Đang sử dụng	2024-06-08	\N	Đã bàn giao	\N	7810000	\N	CÔNG TY CỔ PHẦN GIẢI PHÁP MÁY CHỦ VIỆT	60	2029-08-03	SSD Samsung 1.92TB Sata Enterprise PM893- MZ7L31T9HBLT | SSD | Cụm: Cluster9	TỔNG HỢP	204	{parent_reference_unresolved,handover_date_missing}	2026-09-10 02:47:38.301245+00
SSD-SS-007	SSD Samsung 1.92TB Sata Enterprise PM893- MZ7L31T9HBLT	disk	component	\N	disk	Cluster9	ODS	ODS	1	\N	\N	\N	cluster914	1.92TB	\N	in_use	Đang sử dụng	2024-06-08	\N	Đã bàn giao	\N	7810000	\N	CÔNG TY CỔ PHẦN GIẢI PHÁP MÁY CHỦ VIỆT	60	2029-08-03	SSD Samsung 1.92TB Sata Enterprise PM893- MZ7L31T9HBLT | SSD | Cụm: Cluster9	TỔNG HỢP	205	{parent_reference_unresolved,handover_date_missing}	2026-09-10 02:47:38.301245+00
SSD-SS-008	SSD Samsung 1.92TB Sata Enterprise PM893- MZ7L31T9HBLT	disk	component	\N	disk	Cluster9	ODS	ODS	1	\N	\N	\N	cluster914	1.92TB	\N	in_use	Đang sử dụng	2024-06-08	\N	Đã bàn giao	\N	7810000	\N	CÔNG TY CỔ PHẦN GIẢI PHÁP MÁY CHỦ VIỆT	60	2029-08-03	SSD Samsung 1.92TB Sata Enterprise PM893- MZ7L31T9HBLT | SSD | Cụm: Cluster9	TỔNG HỢP	206	{parent_reference_unresolved,handover_date_missing}	2026-09-10 02:47:38.301245+00
SSD-SS-009	SSD Samsung 1.92TB Sata Enterprise PM893- MZ7L31T9HBLT	disk	component	\N	disk	Cluster9	ODS	ODS	1	\N	\N	\N	cluster924	1.92TB	\N	in_use	Đang sử dụng	2024-06-08	\N	Đã bàn giao	\N	7810000	\N	CÔNG TY CỔ PHẦN GIẢI PHÁP MÁY CHỦ VIỆT	60	2029-08-03	SSD Samsung 1.92TB Sata Enterprise PM893- MZ7L31T9HBLT | SSD | Cụm: Cluster9	TỔNG HỢP	207	{parent_reference_unresolved,handover_date_missing}	2026-09-10 02:47:38.301245+00
SSD-SS-010	SSD Samsung 1.92TB Sata Enterprise PM893- MZ7L31T9HBLT	disk	component	\N	disk	Cluster9	ODS	ODS	1	\N	\N	\N	cluster924	1.92TB	\N	in_use	Đang sử dụng	2024-06-08	\N	Đã bàn giao	\N	7810000	\N	CÔNG TY CỔ PHẦN GIẢI PHÁP MÁY CHỦ VIỆT	60	2029-08-03	SSD Samsung 1.92TB Sata Enterprise PM893- MZ7L31T9HBLT | SSD | Cụm: Cluster9	TỔNG HỢP	208	{parent_reference_unresolved,handover_date_missing}	2026-09-10 02:47:38.301245+00
SSD-SS-011	SSD Samsung 1.92TB Sata Enterprise PM893- MZ7L31T9HBLT	disk	component	\N	disk	Cluster9	ODS	ODS	1	\N	\N	\N	cluster924	1.92TB	\N	in_use	Đang sử dụng	2024-06-08	\N	Đã bàn giao	\N	7810000	\N	CÔNG TY CỔ PHẦN GIẢI PHÁP MÁY CHỦ VIỆT	60	2029-08-03	SSD Samsung 1.92TB Sata Enterprise PM893- MZ7L31T9HBLT | SSD | Cụm: Cluster9	TỔNG HỢP	209	{parent_reference_unresolved,handover_date_missing}	2026-09-10 02:47:38.301245+00
SVR-KHO-001	SVR-KHO-001	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	210	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-002	SVR-KHO-002	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	211	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-003	SVR-KHO-003	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	212	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-004	SVR-KHO-004	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	213	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-005	SVR-KHO-005	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	214	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-006	SVR-KHO-006	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	215	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-007	SVR-KHO-007	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	216	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-008	SVR-KHO-008	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	217	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-009	SVR-KHO-009	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	218	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-010	SVR-KHO-010	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	219	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-011	SVR-KHO-011	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	220	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-012	SVR-KHO-012	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	221	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-013	SVR-KHO-013	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	222	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-014	SVR-KHO-014	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	223	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-015	SVR-KHO-015	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	224	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-016	SVR-KHO-016	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	225	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-017	SVR-KHO-017	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	226	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-018	SVR-KHO-018	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	227	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-019	SVR-KHO-019	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	228	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-020	SVR-KHO-020	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	229	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-021	SVR-KHO-021	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	230	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-022	SVR-KHO-022	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	231	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-023	SVR-KHO-023	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	232	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-024	SVR-KHO-024	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	233	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-025	SVR-KHO-025	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	234	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-026	SVR-KHO-026	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	235	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-027	SVR-KHO-027	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	236	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-028	SVR-KHO-028	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	237	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-029	SVR-KHO-029	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	238	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-033	SVR-KHO-033	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	242	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-034	SVR-KHO-034	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	243	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-040	SVR-KHO-040	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	249	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-041	SVR-KHO-041	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	250	{}	2026-09-10 02:47:38.301245+00
DAS-KHO-001	DAS-KHO-001	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	251	{}	2026-09-10 02:47:38.301245+00
DAS-KHO-002	DAS-KHO-002	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	252	{}	2026-09-10 02:47:38.301245+00
DAS-KHO-003	DAS-KHO-003	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	253	{}	2026-09-10 02:47:38.301245+00
DAS-KHO-004	DAS-KHO-004	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	254	{}	2026-09-10 02:47:38.301245+00
DAS-KHO-005	DAS-KHO-005	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	255	{}	2026-09-10 02:47:38.301245+00
DAS-KHO-006	DAS-KHO-006	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	256	{}	2026-09-10 02:47:38.301245+00
DAS-KHO-007	DAS-KHO-007	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	257	{}	2026-09-10 02:47:38.301245+00
DAS-KHO-008	DAS-KHO-008	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	258	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-030	SVR-KHO-030	server	server	\N	server	Openstack	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	239	{}	2026-09-10 04:43:10.079366+00
SW-KHO-01	nexus n3k-c3064pq-10gx	switch	component	\N	switch	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	nexus n3k-c3064pq-10gx	TỔNG HỢP	259	{}	2026-09-10 02:47:38.301245+00
SW-KHO-02	nexus n3k-c3064pq-10gx	switch	component	\N	switch	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	nexus n3k-c3064pq-10gx	TỔNG HỢP	260	{}	2026-09-10 02:47:38.301245+00
SW-KHO-03	SW-KHO-03	switch	component	\N	switch	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	broken	hư, chỉ làm lab	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	261	{}	2026-09-10 02:47:38.301245+00
SW-KHO-04	SW-KHO-04	switch	component	\N	switch	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	broken	hư, chỉ làm lab	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	262	{}	2026-09-10 02:47:38.301245+00
SW-KHO-05	SW-KHO-05	switch	component	\N	switch	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã thanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	263	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-042	SVR-KHO-042	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	264	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-043	SVR-KHO-043	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	265	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-044	SVR-KHO-044	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	266	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-045	SVR-KHO-045	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	267	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-046	SVR-KHO-046	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	268	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-047	SVR-KHO-047	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	retired	đã hanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	269	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-048	SVR-KHO-048	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	270	{}	2026-09-10 02:47:38.301245+00
SVR-J2-2324	SVR-J2-2324	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	271	{}	2026-09-10 02:47:38.301245+00
SVR-J2-2526	SVR-J2-2526	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	272	{}	2026-09-10 02:47:38.301245+00
SVR-J2-2728	SVR-J2-2728	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	pending_disposal	Cần thanh lý	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	273	{}	2026-09-10 02:47:38.301245+00
SVR-J2-2930	SVR-J2-2930	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	274	{}	2026-09-10 02:47:38.301245+00
SVR-J2-3132	SVR-J2-3132	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	275	{}	2026-09-10 02:47:38.301245+00
SVR-J2-3334	SVR-J2-3334	server	server	\N	server	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	276	{}	2026-09-10 02:47:38.301245+00
CAP-40-0015	cáp 40Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 40Gbps	TỔNG HỢP	277	{}	2026-09-10 02:47:38.301245+00
CAP-40-0016	cáp 40Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 40Gbps	TỔNG HỢP	278	{}	2026-09-10 02:47:38.301245+00
CAP-40-0017	cáp 40Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 40Gbps	TỔNG HỢP	279	{}	2026-09-10 02:47:38.301245+00
CAP-40-0018	cáp 40Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 40Gbps	TỔNG HỢP	280	{}	2026-09-10 02:47:38.301245+00
CAP-40-0019	cáp 40Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 40Gbps	TỔNG HỢP	281	{}	2026-09-10 02:47:38.301245+00
CAP-40-0020	cáp 40Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 40Gbps	TỔNG HỢP	282	{}	2026-09-10 02:47:38.301245+00
CAP-10-0015	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	283	{}	2026-09-10 02:47:38.301245+00
CAP-10-0016	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	284	{}	2026-09-10 02:47:38.301245+00
CAP-10-0017	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	285	{}	2026-09-10 02:47:38.301245+00
CAP-10-0018	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	286	{}	2026-09-10 02:47:38.301245+00
CAP-10-0019	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	287	{}	2026-09-10 02:47:38.301245+00
CAP-10-0020	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	288	{}	2026-09-10 02:47:38.301245+00
CAP-10-0021	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	289	{}	2026-09-10 02:47:38.301245+00
CAP-10-0022	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	290	{}	2026-09-10 02:47:38.301245+00
CAP-10-0023	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	291	{}	2026-09-10 02:47:38.301245+00
CAP-10-0024	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	292	{}	2026-09-10 02:47:38.301245+00
CAP-10-0025	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	293	{}	2026-09-10 02:47:38.301245+00
CAP-10-0026	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	294	{}	2026-09-10 02:47:38.301245+00
CAP-10-0027	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	295	{}	2026-09-10 02:47:38.301245+00
CAP-10-0028	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	296	{}	2026-09-10 02:47:38.301245+00
CAP-10-0029	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	297	{}	2026-09-10 02:47:38.301245+00
CAP-10-0030	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	298	{}	2026-09-10 02:47:38.301245+00
CAP-10-0031	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	299	{}	2026-09-10 02:47:38.301245+00
CAP-10-0032	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	300	{}	2026-09-10 02:47:38.301245+00
CAP-10-0033	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	301	{}	2026-09-10 02:47:38.301245+00
CAP-10-0034	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	302	{}	2026-09-10 02:47:38.301245+00
CAP-10-0035	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	303	{}	2026-09-10 02:47:38.301245+00
CAP-10-0036	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	304	{}	2026-09-10 02:47:38.301245+00
CAP-10-0037	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	305	{}	2026-09-10 02:47:38.301245+00
CAP-10-0038	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	306	{}	2026-09-10 02:47:38.301245+00
CAP-10-0039	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	307	{}	2026-09-10 02:47:38.301245+00
CAP-10-0040	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	308	{}	2026-09-10 02:47:38.301245+00
CAP-10-0041	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	309	{}	2026-09-10 02:47:38.301245+00
CAP-10-0042	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	310	{}	2026-09-10 02:47:38.301245+00
CAP-10-0043	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	311	{}	2026-09-10 02:47:38.301245+00
CAP-10-0044	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	312	{}	2026-09-10 02:47:38.301245+00
CAP-10-0045	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	313	{}	2026-09-10 02:47:38.301245+00
CAP-10-0046	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	314	{}	2026-09-10 02:47:38.301245+00
CAP-10-0047	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	315	{}	2026-09-10 02:47:38.301245+00
CAP-10-0048	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	316	{}	2026-09-10 02:47:38.301245+00
CAP-10-0049	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	317	{}	2026-09-10 02:47:38.301245+00
CAP-10-0050	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	318	{}	2026-09-10 02:47:38.301245+00
CAP-10-0051	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	319	{}	2026-09-10 02:47:38.301245+00
CAP-10-0052	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	320	{}	2026-09-10 02:47:38.301245+00
CAP-10-0053	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	321	{}	2026-09-10 02:47:38.301245+00
CAP-10-0054	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	322	{}	2026-09-10 02:47:38.301245+00
CAP-10-0055	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	323	{}	2026-09-10 02:47:38.301245+00
CAP-10-0056	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	324	{}	2026-09-10 02:47:38.301245+00
CAP-10-0057	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	325	{}	2026-09-10 02:47:38.301245+00
CAP-10-0058	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	326	{}	2026-09-10 02:47:38.301245+00
CAP-10-0059	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	327	{}	2026-09-10 02:47:38.301245+00
CAP-10-0060	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	328	{}	2026-09-10 02:47:38.301245+00
CAP-10-0061	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	329	{}	2026-09-10 02:47:38.301245+00
CAP-10-0062	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	330	{}	2026-09-10 02:47:38.301245+00
CAP-10-0063	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	331	{}	2026-09-10 02:47:38.301245+00
CAP-10-0064	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	332	{}	2026-09-10 02:47:38.301245+00
CAP-10-0065	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	333	{}	2026-09-10 02:47:38.301245+00
CAP-10-0066	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	334	{}	2026-09-10 02:47:38.301245+00
CAP-10-0067	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	335	{}	2026-09-10 02:47:38.301245+00
CAP-10-0068	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	336	{}	2026-09-10 02:47:38.301245+00
CAP-10-0069	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	337	{}	2026-09-10 02:47:38.301245+00
CAP-10-0070	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	338	{}	2026-09-10 02:47:38.301245+00
CAP-10-0071	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	339	{}	2026-09-10 02:47:38.301245+00
CAP-10-0072	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	340	{}	2026-09-10 02:47:38.301245+00
CAP-10-0073	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	341	{}	2026-09-10 02:47:38.301245+00
CAP-10-0074	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	342	{}	2026-09-10 02:47:38.301245+00
CAP-10-0075	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	343	{}	2026-09-10 02:47:38.301245+00
CAP-10-0076	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	344	{}	2026-09-10 02:47:38.301245+00
CAP-10-0077	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	345	{}	2026-09-10 02:47:38.301245+00
CAP-10-0078	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	346	{}	2026-09-10 02:47:38.301245+00
CAP-10-0079	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	347	{}	2026-09-10 02:47:38.301245+00
CAP-10-0080	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	348	{}	2026-09-10 02:47:38.301245+00
CAP-10-0081	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	349	{}	2026-09-10 02:47:38.301245+00
CAP-10-0082	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	350	{}	2026-09-10 02:47:38.301245+00
CAP-10-0083	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	351	{}	2026-09-10 02:47:38.301245+00
CAP-10-0084	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	352	{}	2026-09-10 02:47:38.301245+00
CAP-10-0085	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	353	{}	2026-09-10 02:47:38.301245+00
CAP-10-0086	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	354	{}	2026-09-10 02:47:38.301245+00
CAP-10-0087	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	355	{}	2026-09-10 02:47:38.301245+00
CAP-10-0088	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	356	{}	2026-09-10 02:47:38.301245+00
CAP-10-0089	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	357	{}	2026-09-10 02:47:38.301245+00
CAP-10-0090	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	358	{}	2026-09-10 02:47:38.301245+00
CAP-10-0091	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	359	{}	2026-09-10 02:47:38.301245+00
CAP-10-0092	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	360	{}	2026-09-10 02:47:38.301245+00
CAP-10-0093	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	361	{}	2026-09-10 02:47:38.301245+00
CAP-10-0094	cáp 10Gbps	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp 10Gbps	TỔNG HỢP	362	{}	2026-09-10 02:47:38.301245+00
CAP-DAS-001	cáp DAS	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp DAS	TỔNG HỢP	363	{}	2026-09-10 02:47:38.301245+00
CAP-DAS-002	cáp DAS	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp DAS	TỔNG HỢP	364	{}	2026-09-10 02:47:38.301245+00
CAP-DAS-003	cáp DAS	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp DAS	TỔNG HỢP	365	{}	2026-09-10 02:47:38.301245+00
CAP-DAS-004	cáp DAS	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp DAS	TỔNG HỢP	366	{}	2026-09-10 02:47:38.301245+00
CAP-DAS-005	cáp DAS	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp DAS	TỔNG HỢP	367	{}	2026-09-10 02:47:38.301245+00
CAP-DAS-006	cáp DAS	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp DAS	TỔNG HỢP	368	{}	2026-09-10 02:47:38.301245+00
CAP-DAS-007	cáp DAS	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp DAS	TỔNG HỢP	369	{}	2026-09-10 02:47:38.301245+00
CAP-DAS-008	cáp DAS	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp DAS	TỔNG HỢP	370	{}	2026-09-10 02:47:38.301245+00
CAP-DAS-009	cáp DAS	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp DAS	TỔNG HỢP	371	{}	2026-09-10 02:47:38.301245+00
CAP-DAS-010	cáp DAS	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp DAS	TỔNG HỢP	372	{}	2026-09-10 02:47:38.301245+00
CAP-DAS-011	cáp DAS	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp DAS	TỔNG HỢP	373	{}	2026-09-10 02:47:38.301245+00
CAP-DAS-012	cáp DAS	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp DAS	TỔNG HỢP	374	{}	2026-09-10 02:47:38.301245+00
CAP-10-0095	cáp quang 10Gbps 10m	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	Chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp quang 10Gbps 10m	TỔNG HỢP	375	{}	2026-09-10 02:47:38.301245+00
CAP-10-0096	cáp quang 10Gbps 10m	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	Chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp quang 10Gbps 10m	TỔNG HỢP	376	{}	2026-09-10 02:47:38.301245+00
DAS-ACC-001	đầu chuyển DAS	adapter	component	\N	đầu chuyển DAS	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	đầu chuyển DAS	TỔNG HỢP	377	{unmapped_ip_or_type}	2026-09-10 02:47:38.301245+00
DAS-ACC-002	đầu chuyển DAS	adapter	component	\N	đầu chuyển DAS	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	đầu chuyển DAS	TỔNG HỢP	378	{unmapped_ip_or_type}	2026-09-10 02:47:38.301245+00
DAS-ACC-003	đầu chuyển DAS	adapter	component	\N	đầu chuyển DAS	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	đầu chuyển DAS	TỔNG HỢP	379	{unmapped_ip_or_type}	2026-09-10 02:47:38.301245+00
DAS-ACC-004	đầu chuyển DAS	adapter	component	\N	đầu chuyển DAS	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	đầu chuyển DAS	TỔNG HỢP	380	{unmapped_ip_or_type}	2026-09-10 02:47:38.301245+00
DAS-ACC-005	đầu chuyển DAS	adapter	component	\N	đầu chuyển DAS	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	đầu chuyển DAS	TỔNG HỢP	381	{unmapped_ip_or_type}	2026-09-10 02:47:38.301245+00
CARD-1-2-001	card 1Gpbs 2port	nic	component	\N	card mạng	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	card 1Gpbs 2port	TỔNG HỢP	382	{}	2026-09-10 02:47:38.301245+00
CARD-1-2-002	card 1Gpbs 2port	nic	component	\N	card mạng	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	card 1Gpbs 2port	TỔNG HỢP	383	{}	2026-09-10 02:47:38.301245+00
CARD-1-2-003	card 1Gpbs 2port	nic	component	\N	card mạng	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	card 1Gpbs 2port	TỔNG HỢP	384	{}	2026-09-10 02:47:38.301245+00
CARD-10-2-001	card 10Gbps 2port	nic	component	\N	card mạng	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	card 10Gbps 2port	TỔNG HỢP	385	{}	2026-09-10 02:47:38.301245+00
CARD-10-2-002	card 10Gbps 2port	nic	component	\N	card mạng	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	card 10Gbps 2port	TỔNG HỢP	386	{}	2026-09-10 02:47:38.301245+00
CARD-10-2-003	card 10Gbps 2port	nic	component	\N	card mạng	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	card 10Gbps 2port	TỔNG HỢP	387	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0001	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	388	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0002	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	389	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0003	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	390	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0004	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	391	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0005	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	392	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0006	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	393	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0007	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	394	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0008	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	395	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0009	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	396	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0010	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	397	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0011	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	398	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0012	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	399	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0013	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	400	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0014	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	401	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0015	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	402	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0016	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	403	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0017	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	broken	Hỏng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	404	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0018	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	broken	Hỏng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	405	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0019	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	broken	Hỏng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	406	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0020	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	broken	Hỏng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	407	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0021	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	408	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0022	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	409	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0023	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	410	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0024	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	411	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0025	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	SVR-KHO-032	\N	4TB	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	412	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0026	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	SVR-KHO-035	\N	4TB	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	413	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0027	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	SVR-KHO-037	\N	4TB	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	414	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0028	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	415	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0029	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	416	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0031	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	broken	Hỏng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	418	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0032	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	broken	Hỏng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	419	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0033	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	broken	Hỏng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	420	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0035	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	422	{}	2026-09-10 02:47:38.301245+00
HDD-4TB-0036	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	423	{}	2026-09-10 02:47:38.301245+00
MODULE-10-001	module quang 10Gbps cisco	optical_module	component	\N	module	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	module quang 10Gbps cisco	TỔNG HỢP	424	{}	2026-09-10 02:47:38.301245+00
MODULE-10-002	module quang 10Gbps cisco	optical_module	component	\N	module	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	module quang 10Gbps cisco	TỔNG HỢP	425	{}	2026-09-10 02:47:38.301245+00
MODULE-10-003	module quang 10Gbps cisco	optical_module	component	\N	module	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	module quang 10Gbps cisco	TỔNG HỢP	426	{}	2026-09-10 02:47:38.301245+00
MODULE-10-004	module quang 10Gbps cisco	optical_module	component	\N	module	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	module quang 10Gbps cisco	TỔNG HỢP	427	{}	2026-09-10 02:47:38.301245+00
MODULE-10-005	module quang 10Gbps cisco	optical_module	component	\N	module	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	module quang 10Gbps cisco	TỔNG HỢP	428	{}	2026-09-10 02:47:38.301245+00
MODULE-10-006	module quang 10Gbps cisco	optical_module	component	\N	module	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	module quang 10Gbps cisco	TỔNG HỢP	429	{}	2026-09-10 02:47:38.301245+00
MODULE-10-007	module quang 10Gbps cisco	optical_module	component	\N	module	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	module quang 10Gbps cisco	TỔNG HỢP	430	{}	2026-09-10 02:47:38.301245+00
MODULE-10-008	module quang 10Gbps cisco	optical_module	component	\N	module	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	module quang 10Gbps cisco	TỔNG HỢP	431	{}	2026-09-10 02:47:38.301245+00
MODULE-10-009	module quang 10Gbps cisco	optical_module	component	\N	module	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	module quang 10Gbps cisco	TỔNG HỢP	432	{}	2026-09-10 02:47:38.301245+00
SSD-480-001	SSD SS 480G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 480G	TỔNG HỢP	433	{}	2026-09-10 02:47:38.301245+00
SSD-480-002	SSD SS 480G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 480G	TỔNG HỢP	434	{}	2026-09-10 02:47:38.301245+00
SSD-480-003	SSD SS 480G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 480G	TỔNG HỢP	435	{}	2026-09-10 02:47:38.301245+00
SSD-480-004	SSD SS 480G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 480G	TỔNG HỢP	436	{}	2026-09-10 02:47:38.301245+00
SSD-480-005	SSD SS 480G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 480G	TỔNG HỢP	437	{}	2026-09-10 02:47:38.301245+00
SSD-480-006	SSD SS 480G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 480G	TỔNG HỢP	438	{}	2026-09-10 02:47:38.301245+00
SSD-480-007	SSD SS 480G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 480G	TỔNG HỢP	439	{}	2026-09-10 02:47:38.301245+00
SSD-480-008	SSD SS 480G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 480G	TỔNG HỢP	440	{}	2026-09-10 02:47:38.301245+00
SSD-240-005	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	441	{}	2026-09-10 02:47:38.301245+00
SSD-240-006	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	442	{}	2026-09-10 02:47:38.301245+00
SSD-240-007	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	443	{}	2026-09-10 02:47:38.301245+00
SSD-240-008	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	444	{}	2026-09-10 02:47:38.301245+00
SSD-240-009	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	445	{}	2026-09-10 02:47:38.301245+00
SSD-240-010	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	446	{}	2026-09-10 02:47:38.301245+00
SSD-240-011	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	447	{}	2026-09-10 02:47:38.301245+00
SSD-240-012	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	448	{}	2026-09-10 02:47:38.301245+00
SSD-240-013	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	449	{}	2026-09-10 02:47:38.301245+00
SSD-240-014	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	450	{}	2026-09-10 02:47:38.301245+00
SSD-240-015	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	451	{}	2026-09-10 02:47:38.301245+00
SSD-240-016	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	452	{}	2026-09-10 02:47:38.301245+00
SSD-240-017	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	453	{}	2026-09-10 02:47:38.301245+00
SSD-240-018	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	454	{}	2026-09-10 02:47:38.301245+00
SSD-240-019	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	455	{}	2026-09-10 02:47:38.301245+00
SSD-240-020	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	456	{}	2026-09-10 02:47:38.301245+00
SSD-240-021	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	457	{}	2026-09-10 02:47:38.301245+00
SSD-240-022	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	458	{}	2026-09-10 02:47:38.301245+00
SSD-240-023	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	459	{}	2026-09-10 02:47:38.301245+00
SSD-240-024	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	460	{}	2026-09-10 02:47:38.301245+00
SSD-240-025	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	461	{}	2026-09-10 02:47:38.301245+00
SSD-240-026	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	462	{}	2026-09-10 02:47:38.301245+00
SSD-240-027	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	degraded	Không đảm bảo hiệu năng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	463	{}	2026-09-10 02:47:38.301245+00
SSD-240-028	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	degraded	Không đảm bảo hiệu năng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	464	{}	2026-09-10 02:47:38.301245+00
SSD-240-029	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	degraded	Không đảm bảo hiệu năng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	465	{}	2026-09-10 02:47:38.301245+00
SSD-240-030	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	degraded	Không đảm bảo hiệu năng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	466	{}	2026-09-10 02:47:38.301245+00
SSD-240-031	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	467	{}	2026-09-10 02:47:38.301245+00
SSD-240-032	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	broken	Hỏng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	468	{}	2026-09-10 02:47:38.301245+00
SSD-240-033	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	broken	Hỏng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	469	{}	2026-09-10 02:47:38.301245+00
SSD-240-034	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	broken	Hỏng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	470	{}	2026-09-10 02:47:38.301245+00
SSD-240-035	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	broken	Hỏng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	471	{}	2026-09-10 02:47:38.301245+00
SSD-240-036	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	broken	Hỏng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	472	{}	2026-09-10 02:47:38.301245+00
SSD-240-037	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	broken	Hỏng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	473	{}	2026-09-10 02:47:38.301245+00
SSD-240-038	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	broken	Hỏng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	474	{}	2026-09-10 02:47:38.301245+00
SSD-240-039	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	broken	Hỏng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	475	{}	2026-09-10 02:47:38.301245+00
SSD-240-040	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	SVR-KHO-032	\N	240G	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	476	{}	2026-09-10 02:47:38.301245+00
SSD-240-041	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	SVR-KHO-035	\N	240G	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	477	{}	2026-09-10 02:47:38.301245+00
SSD-240-042	SSD SS 240G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	SVR-KHO-037	\N	240G	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 240G	TỔNG HỢP	478	{}	2026-09-10 02:47:38.301245+00
SSD-960-007	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	479	{}	2026-09-10 02:47:38.301245+00
SSD-960-008	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	480	{}	2026-09-10 02:47:38.301245+00
SSD-960-009	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	481	{}	2026-09-10 02:47:38.301245+00
SSD-960-010	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	482	{}	2026-09-10 02:47:38.301245+00
SSD-960-011	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	483	{}	2026-09-10 02:47:38.301245+00
SSD-960-012	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	484	{}	2026-09-10 02:47:38.301245+00
SSD-960-013	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	485	{}	2026-09-10 02:47:38.301245+00
SSD-960-014	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	486	{}	2026-09-10 02:47:38.301245+00
SSD-960-015	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	487	{}	2026-09-10 02:47:38.301245+00
SSD-960-016	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	488	{}	2026-09-10 02:47:38.301245+00
SSD-960-017	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	489	{}	2026-09-10 02:47:38.301245+00
SSD-960-018	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	490	{}	2026-09-10 02:47:38.301245+00
SSD-960-019	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	491	{}	2026-09-10 02:47:38.301245+00
SSD-960-020	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	492	{}	2026-09-10 02:47:38.301245+00
SSD-960-021	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	493	{}	2026-09-10 02:47:38.301245+00
SSD-960-022	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	broken	Hỏng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	494	{}	2026-09-10 02:47:38.301245+00
SSD-960-023	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	495	{}	2026-09-10 02:47:38.301245+00
SSD-960-024	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	496	{}	2026-09-10 02:47:38.301245+00
SSD-960-025	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	497	{}	2026-09-10 02:47:38.301245+00
SSD-960-026	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	498	{}	2026-09-10 02:47:38.301245+00
SSD-960-027	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	499	{}	2026-09-10 02:47:38.301245+00
SSD-960-028	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	500	{}	2026-09-10 02:47:38.301245+00
SSD-960-029	SSD SS 960G	disk	component	\N	disk	MBIN & MBCA	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G | Cụm: MBIN & MBCA	TỔNG HỢP	501	{}	2026-09-10 02:47:38.301245+00
SSD-960-030	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	broken	Hỏng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	502	{}	2026-09-10 02:47:38.301245+00
SSD-960-031	SSD SS 960G	disk	component	\N	disk	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	broken	Hỏng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SSD SS 960G	TỔNG HỢP	503	{}	2026-09-10 02:47:38.301245+00
CARD-RAID-002	card RAID external	unknown	component	\N	card RAID external	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	card RAID external	TỔNG HỢP	504	{unmapped_ip_or_type}	2026-09-10 02:47:38.301245+00
CARD-RAID-001	card RAID	raid_card	component	\N	card RAID	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	cũ , chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	card RAID	TỔNG HỢP	505	{unmapped_ip_or_type}	2026-09-10 02:47:38.301245+00
CAP-10-0097	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	506	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0098	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	507	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0099	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	508	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0100	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	509	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0101	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	510	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0102	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	511	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0103	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	512	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0104	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	513	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0105	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	514	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0106	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	515	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0107	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	516	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0108	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	517	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0109	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	518	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0110	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	519	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0111	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	520	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0112	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	521	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0113	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	522	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0114	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	523	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0021	Cáp 40Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 40Gb | Cụm: Cluster8	TỔNG HỢP	524	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0022	Cáp 40Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 40Gb | Cụm: Cluster8	TỔNG HỢP	525	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0115	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	526	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0116	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	527	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0117	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	528	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0118	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	529	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0119	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	530	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0120	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	531	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0121	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	532	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0122	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	533	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0123	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	534	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0124	Cáp 10Gb	cable	component	\N	cáp	Cluster8	ODS	ODS	1	\N	\N	\N	Cluster8	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster8	TỔNG HỢP	535	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0125	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	not_in_use	Không sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	536	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0126	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	537	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0127	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	538	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0128	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	539	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0129	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	540	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0130	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	541	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0131	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	542	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0132	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	543	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0133	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	544	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0134	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	545	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0135	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	546	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0136	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	547	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0137	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	548	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0138	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	549	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0139	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	550	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0140	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	551	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0141	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	552	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0142	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	553	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0143	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	554	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0144	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	555	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0145	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	556	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0146	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	557	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0147	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	558	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0148	Cáp 10Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: Cluster9	TỔNG HỢP	559	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0023	Cáp 40Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 40Gb | Cụm: Cluster9	TỔNG HỢP	560	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0024	Cáp 40Gb	cable	component	\N	cáp	Cluster9	ODS	ODS	1	\N	\N	\N	Cluster9	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 40Gb | Cụm: Cluster9	TỔNG HỢP	561	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0149	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	not_in_use	Không sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	562	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0150	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	not_in_use	Không sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	563	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0151	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	564	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0152	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	565	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0153	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	566	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0154	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	567	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0155	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	568	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0156	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	569	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0157	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	570	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0158	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	571	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0159	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	572	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0160	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	573	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0161	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	574	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0162	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	575	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0163	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	576	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0164	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	577	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0165	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	578	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0166	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	579	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0167	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	580	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0168	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	581	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0169	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	582	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0170	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	583	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0171	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	584	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0172	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	585	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0173	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	586	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0174	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	587	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0175	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	588	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0176	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	589	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0177	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	590	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0178	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	591	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0179	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	592	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0180	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	593	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0181	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	594	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0182	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	595	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0183	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	596	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0184	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	597	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0185	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	598	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0186	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	599	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0187	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	600	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0188	Cáp 10Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: ClusterX1	TỔNG HỢP	601	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0189	cáp quang 10Gbps 10m	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp quang 10Gbps 10m | Cụm: ClusterX1	TỔNG HỢP	602	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0190	cáp quang 10Gbps 10m	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp quang 10Gbps 10m | Cụm: ClusterX1	TỔNG HỢP	603	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0191	cáp quang 10Gbps 10m	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp quang 10Gbps 10m | Cụm: ClusterX1	TỔNG HỢP	604	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0192	cáp quang 10Gbps 10m	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp quang 10Gbps 10m | Cụm: ClusterX1	TỔNG HỢP	605	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0193	cáp quang 10Gbps 10m	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp quang 10Gbps 10m | Cụm: ClusterX1	TỔNG HỢP	606	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0194	cáp quang 10Gbps 10m	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp quang 10Gbps 10m | Cụm: ClusterX1	TỔNG HỢP	607	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0195	cáp quang 10Gbps 10m	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp quang 10Gbps 10m | Cụm: ClusterX1	TỔNG HỢP	608	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0196	cáp quang 10Gbps 10m	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp quang 10Gbps 10m | Cụm: ClusterX1	TỔNG HỢP	609	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0025	Cáp 40Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 40Gb | Cụm: ClusterX1	TỔNG HỢP	610	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0026	Cáp 40Gb	cable	component	\N	cáp	ClusterX1	ODS	ODS	1	\N	\N	\N	ClusterX1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 40Gb | Cụm: ClusterX1	TỔNG HỢP	611	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0197	cáp quang 10Gbps 10m	cable	component	\N	cáp	monitor	ODS	ODS	1	\N	\N	\N	monitor	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp quang 10Gbps 10m | Cụm: monitor	TỔNG HỢP	612	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0198	cáp quang 10Gbps 10m	cable	component	\N	cáp	monitor	ODS	ODS	1	\N	\N	\N	monitor	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp quang 10Gbps 10m | Cụm: monitor	TỔNG HỢP	613	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0199	cáp quang 10Gbps 10m	cable	component	\N	cáp	monitor	ODS	ODS	1	\N	\N	\N	monitor	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp quang 10Gbps 10m | Cụm: monitor	TỔNG HỢP	614	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0200	cáp quang 10Gbps 10m	cable	component	\N	cáp	monitor	ODS	ODS	1	\N	\N	\N	monitor	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp quang 10Gbps 10m | Cụm: monitor	TỔNG HỢP	615	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0201	cáp quang 10Gbps 10m	cable	component	\N	cáp	monitor	ODS	ODS	1	\N	\N	\N	monitor	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp quang 10Gbps 10m | Cụm: monitor	TỔNG HỢP	616	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0202	cáp quang 10Gbps 10m	cable	component	\N	cáp	monitor	ODS	ODS	1	\N	\N	\N	monitor	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp quang 10Gbps 10m | Cụm: monitor	TỔNG HỢP	617	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0203	cáp quang 10Gbps 10m	cable	component	\N	cáp	monitor	ODS	ODS	1	\N	\N	\N	monitor	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp quang 10Gbps 10m | Cụm: monitor	TỔNG HỢP	618	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0204	cáp quang 10Gbps 10m	cable	component	\N	cáp	monitor	ODS	ODS	1	\N	\N	\N	monitor	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp quang 10Gbps 10m | Cụm: monitor	TỔNG HỢP	619	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0205	cáp quang 10Gbps 10m	cable	component	\N	cáp	\N	ODS	ODS	1	\N	\N	\N	monitor	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp quang 10Gbps 10m	TỔNG HỢP	620	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0206	cáp quang 10Gbps 10m	cable	component	\N	cáp	\N	ODS	ODS	1	\N	\N	\N	monitor	\N	\N	broken	hỏng	\N	\N	\N	\N	\N	\N	\N	\N	\N	cáp quang 10Gbps 10m	TỔNG HỢP	621	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0207	Cáp 10Gb	cable	component	\N	cáp	MBO	ODS	ODS	1	\N	\N	\N	MBO	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: MBO	TỔNG HỢP	622	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0208	Cáp 10Gb	cable	component	\N	cáp	MBO	ODS	ODS	1	\N	\N	\N	MBO	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: MBO	TỔNG HỢP	623	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0209	Cáp 10Gb	cable	component	\N	cáp	MBO	ODS	ODS	1	\N	\N	\N	MBO	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: MBO	TỔNG HỢP	624	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0210	Cáp 10Gb	cable	component	\N	cáp	MBO	ODS	ODS	1	\N	\N	\N	MBO	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: MBO	TỔNG HỢP	625	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0211	Cáp 10Gb	cable	component	\N	cáp	MBO	ODS	ODS	1	\N	\N	\N	MBO	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: MBO	TỔNG HỢP	626	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0212	Cáp 10Gb	cable	component	\N	cáp	MBO	ODS	ODS	1	\N	\N	\N	MBO	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: MBO	TỔNG HỢP	627	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0213	Cáp 10Gb	cable	component	\N	cáp	MBO	ODS	ODS	1	\N	\N	\N	MBO	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: MBO	TỔNG HỢP	628	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0214	Cáp 10Gb	cable	component	\N	cáp	MBO	ODS	ODS	1	\N	\N	\N	MBO	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: MBO	TỔNG HỢP	629	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0027	Cáp 40Gb	cable	component	\N	cáp	MBO	ODS	ODS	1	\N	\N	\N	MBO	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 40Gb | Cụm: MBO	TỔNG HỢP	630	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0028	Cáp 40Gb	cable	component	\N	cáp	MBO	ODS	ODS	1	\N	\N	\N	MBO	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 40Gb | Cụm: MBO	TỔNG HỢP	631	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0215	Cáp 10Gb	cable	component	\N	cáp	monitor	ODS	ODS	1	\N	\N	\N	monitor	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: monitor	TỔNG HỢP	632	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0216	Cáp 10Gb	cable	component	\N	cáp	monitor	ODS	ODS	1	\N	\N	\N	monitor	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: monitor	TỔNG HỢP	633	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0217	Cáp 10Gb	cable	component	\N	cáp	monitor	ODS	ODS	1	\N	\N	\N	monitor	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: monitor	TỔNG HỢP	634	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0218	Cáp 10Gb	cable	component	\N	cáp	monitor	ODS	ODS	1	\N	\N	\N	monitor	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: monitor	TỔNG HỢP	635	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0219	Cáp 10Gb	cable	component	\N	cáp	monitor	ODS	ODS	1	\N	\N	\N	monitor	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: monitor	TỔNG HỢP	636	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0220	Cáp 10Gb	cable	component	\N	cáp	monitor	ODS	ODS	1	\N	\N	\N	monitor	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: monitor	TỔNG HỢP	637	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0221	Cáp 10Gb	cable	component	\N	cáp	\N	ODS	ODS	1	\N	\N	\N	IPv6	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb	TỔNG HỢP	638	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0222	Cáp 10Gb	cable	component	\N	cáp	\N	ODS	ODS	1	\N	\N	\N	IPv6	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb	TỔNG HỢP	639	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0223	Cáp 10Gb	cable	component	\N	cáp	\N	ODS	ODS	1	\N	\N	\N	IPv6	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb	TỔNG HỢP	640	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0224	Cáp 10Gb	cable	component	\N	cáp	\N	ODS	ODS	1	\N	\N	\N	IPv6	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb	TỔNG HỢP	641	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0225	Cáp 10Gb	cable	component	\N	cáp	\N	ODS	ODS	1	\N	\N	\N	IPv6	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb	TỔNG HỢP	642	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0226	Cáp 10Gb	cable	component	\N	cáp	\N	ODS	ODS	1	\N	\N	\N	IPv6	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb	TỔNG HỢP	643	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0227	Cáp 10Gb	cable	component	\N	cáp	\N	ODS	ODS	1	\N	\N	\N	IPv6	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb	TỔNG HỢP	644	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0228	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	645	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0229	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	646	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0230	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	647	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0231	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	648	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0232	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	649	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0233	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	650	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0234	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	651	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0235	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	652	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0236	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	653	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0237	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	654	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0238	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	655	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0239	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	656	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0240	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	657	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0241	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	658	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0242	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	659	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0243	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	660	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0244	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	661	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0245	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	662	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0246	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	663	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0247	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	664	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0248	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	665	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0249	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	666	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0250	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	667	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0251	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	668	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0252	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	669	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0253	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	670	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0029	Cáp 40Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 40Gb | Cụm: VNPT1	TỔNG HỢP	671	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0030	Cáp 40Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 40Gb | Cụm: VNPT1	TỔNG HỢP	672	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0254	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	673	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0255	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	674	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0256	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	675	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0257	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	676	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0258	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	677	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0259	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	678	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SW-J4-46	Cisco WS-C3750E-48PD	switch	component	\N	switch	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	Cisco WS-C3750E-48PD | Cụm: ClusterX1	TỔNG HỢP	139	{}	2026-09-10 02:47:38.301245+00
CAP-10-0260	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	679	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0261	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	680	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0262	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	681	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0263	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	682	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0264	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	683	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0265	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	684	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0266	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	685	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0267	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	686	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0268	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	687	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0269	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	688	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0270	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	689	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0271	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	690	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0272	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	691	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0273	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	692	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0274	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	693	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0275	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	694	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0276	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	695	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0277	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	696	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0278	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	697	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0279	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	698	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0280	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	699	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0281	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	700	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0282	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	701	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0283	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	702	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0284	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	703	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0285	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	704	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0286	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	705	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0287	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	706	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SVR-J6-2829	cluster925	network_or_host	component	103.15.49.182	103.15.49.182	Cluster9	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use_needs_replacement	Đang sử dụng cần được thay thế	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	cluster925 | Cụm: Cluster9	TỔNG HỢP	102	{}	2026-09-10 02:47:38.301245+00
CAP-10-0288	Cáp 10Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: VNPT1	TỔNG HỢP	707	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0031	Cáp 40Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 40Gb | Cụm: VNPT1	TỔNG HỢP	708	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0032	Cáp 40Gb	cable	component	\N	cáp	VNPT1	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	VNPT1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 40Gb | Cụm: VNPT1	TỔNG HỢP	709	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0289	Cáp 10Gb	cable	component	\N	cáp	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	MBIN & MBCA	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: MBIN & MBCA	TỔNG HỢP	710	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0290	Cáp 10Gb	cable	component	\N	cáp	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	MBIN & MBCA	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: MBIN & MBCA	TỔNG HỢP	711	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0291	Cáp 10Gb	cable	component	\N	cáp	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	MBIN & MBCA	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: MBIN & MBCA	TỔNG HỢP	712	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0292	Cáp 10Gb	cable	component	\N	cáp	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	MBIN & MBCA	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: MBIN & MBCA	TỔNG HỢP	713	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0293	Cáp 10Gb	cable	component	\N	cáp	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	MBIN & MBCA	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: MBIN & MBCA	TỔNG HỢP	714	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0294	Cáp 10Gb	cable	component	\N	cáp	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	MBIN & MBCA	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: MBIN & MBCA	TỔNG HỢP	715	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0295	Cáp 10Gb	cable	component	\N	cáp	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	MBIN & MBCA	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: MBIN & MBCA	TỔNG HỢP	716	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0296	Cáp 10Gb	cable	component	\N	cáp	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	MBIN & MBCA	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: MBIN & MBCA	TỔNG HỢP	717	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0297	Cáp 10Gb	cable	component	\N	cáp	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	MBIN & MBCA	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: MBIN & MBCA	TỔNG HỢP	718	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0298	Cáp 10Gb	cable	component	\N	cáp	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	MBIN & MBCA	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: MBIN & MBCA	TỔNG HỢP	719	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0299	Cáp 10Gb	cable	component	\N	cáp	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	MBIN & MBCA	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: MBIN & MBCA	TỔNG HỢP	720	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0300	Cáp 10Gb	cable	component	\N	cáp	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	MBIN & MBCA	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: MBIN & MBCA	TỔNG HỢP	721	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0301	Cáp 10Gb	cable	component	\N	cáp	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	MBIN & MBCA	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: MBIN & MBCA	TỔNG HỢP	722	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-0302	Cáp 10Gb	cable	component	\N	cáp	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	MBIN & MBCA	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 10Gb | Cụm: MBIN & MBCA	TỔNG HỢP	723	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0033	Cáp 40Gb	cable	component	\N	cáp	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	MBIN & MBCA	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 40Gb | Cụm: MBIN & MBCA	TỔNG HỢP	724	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-40-0034	Cáp 40Gb	cable	component	\N	cáp	MBIN & MBCA	VNPT Tân Thuận	VNPT Tân Thuận	36	\N	\N	\N	MBIN & MBCA	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Cáp 40Gb | Cụm: MBIN & MBCA	TỔNG HỢP	725	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506115	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	726	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506116	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	727	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506117	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	728	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506118	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	729	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506119	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	730	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506121	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	731	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506122	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	732	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506124	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	733	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506125	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	734	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506126	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	735	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506127	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	736	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506128	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	737	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506130	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	738	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506131	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	739	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506132	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	740	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506133	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	741	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506134	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	742	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506135	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	743	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506136	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	744	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506137	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	745	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506138	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	746	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506139	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	747	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506140	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	748	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506141	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	749	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506142	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	750	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506143	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	751	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506144	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	752	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SVR-KHO-031	SVR-KHO-031	server	server	\N	server	Openstack	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	240	{}	2026-09-10 04:42:16.035135+00
HDD-4TB-0030	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	broken	Hỏng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	417	{}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506145	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	753	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506146	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	754	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506147	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	755	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506148	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	756	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506149	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	757	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506150	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	758	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506151	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	759	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6EPNC0Y506152	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA	disk	component	\N	disk	Sangfor tạm	ODS	ODS	1	\N	\N	\N	Sangfor tạm	\N	\N	in_use	Đang sử dụng	2025-06-25	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 7.68TB Sata Enterprise PM893- MZ7L37T6HBLA | SSD SS 8TB | Cụm: Sangfor tạm	TỔNG HỢP	760	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SP72527390	SAS9300-8i Card RAID LSI Broadcom SAS 9300-8i 8x 12Gb/s SATA+SAS PCI-Express 3.0	raid_card	component	\N	Card RAID	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SAS9300-8i Card RAID LSI Broadcom SAS 9300-8i 8x 12Gb/s SATA+SAS PCI-Express 3.0 | Card RAID | Cụm: CMC1	TỔNG HỢP	761	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SP72100218	SAS9300-8i Card RAID LSI Broadcom SAS 9300-8i 8x 12Gb/s SATA+SAS PCI-Express 3.0	raid_card	component	\N	Card RAID	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SAS9300-8i Card RAID LSI Broadcom SAS 9300-8i 8x 12Gb/s SATA+SAS PCI-Express 3.0 | Card RAID | Cụm: CMC1	TỔNG HỢP	762	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SP72501491	SAS9300-8i Card RAID LSI Broadcom SAS 9300-8i 8x 12Gb/s SATA+SAS PCI-Express 3.0	raid_card	component	\N	Card RAID	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SAS9300-8i Card RAID LSI Broadcom SAS 9300-8i 8x 12Gb/s SATA+SAS PCI-Express 3.0 | Card RAID | Cụm: CMC1	TỔNG HỢP	763	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SP62305138	SAS9300-8i Card RAID LSI Broadcom SAS 9300-8i 8x 12Gb/s SATA+SAS PCI-Express 3.0	raid_card	component	\N	Card RAID	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SAS9300-8i Card RAID LSI Broadcom SAS 9300-8i 8x 12Gb/s SATA+SAS PCI-Express 3.0 | Card RAID | Cụm: CMC1	TỔNG HỢP	764	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SP72402897	SAS9300-8i Card RAID LSI Broadcom SAS 9300-8i 8x 12Gb/s SATA+SAS PCI-Express 3.0	raid_card	component	\N	Card RAID	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SAS9300-8i Card RAID LSI Broadcom SAS 9300-8i 8x 12Gb/s SATA+SAS PCI-Express 3.0 | Card RAID | Cụm: CMC1	TỔNG HỢP	765	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SP72527871	SAS9300-8i Card RAID LSI Broadcom SAS 9300-8i 8x 12Gb/s SATA+SAS PCI-Express 3.0	raid_card	component	\N	Card RAID	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SAS9300-8i Card RAID LSI Broadcom SAS 9300-8i 8x 12Gb/s SATA+SAS PCI-Express 3.0 | Card RAID | Cụm: CMC1	TỔNG HỢP	766	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SP83828466	SAS9300-8i Card RAID LSI Broadcom SAS 9300-8i 8x 12Gb/s SATA+SAS PCI-Express 3.0	unknown	component	\N	\N	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	CMC1	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	SAS9300-8i Card RAID LSI Broadcom SAS 9300-8i 8x 12Gb/s SATA+SAS PCI-Express 3.0 | Card RAID | Cụm: CMC1	TỔNG HỢP	767	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S724NS0Y500169D	SSD Samsung 1.92TB 2.5inch Sata Enterprise PM 893- MZ7L31T900	disk	component	\N	disk	Sangfor cluster9	ODS	ODS	1	\N	\N	\N	Node 103.15.49.46	1,92TB	\N	in_use	Đang sử dụng	2025-02-10	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 1.92TB 2.5inch Sata Enterprise PM 893- MZ7L31T900 | SSD 1,92TB | Cụm: Sangfor cluster9	TỔNG HỢP	768	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S724NS0Y500165Y	SSD Samsung 1.92TB 2.5inch Sata Enterprise PM 893- MZ7L31T901	disk	component	\N	disk	Sangfor cluster9	ODS	ODS	1	\N	\N	\N	Node 103.15.49.39	1,92TB	\N	in_use	Đang sử dụng	2025-02-10	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 1.92TB 2.5inch Sata Enterprise PM 893- MZ7L31T901 | SSD 1,92TB | Cụm: Sangfor cluster9	TỔNG HỢP	769	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S724NS0Y500162W	SSD Samsung 1.92TB 2.5inch Sata Enterprise PM 893- MZ7L31T902	disk	component	\N	disk	Sangfor cluster9	ODS	ODS	1	\N	\N	\N	Node 103.15.49.46	1,92TB	\N	in_use	Đang sử dụng	2025-02-10	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 1.92TB 2.5inch Sata Enterprise PM 893- MZ7L31T902 | SSD 1,92TB | Cụm: Sangfor cluster9	TỔNG HỢP	770	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S724NS0Y500160A	SSD Samsung 1.92TB 2.5inch Sata Enterprise PM 893- MZ7L31T903	disk	component	\N	disk	Sangfor cluster9	ODS	ODS	1	\N	\N	\N	Node 103.15.49.40	1,92TB	\N	in_use	Đang sử dụng	2025-02-10	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 1.92TB 2.5inch Sata Enterprise PM 893- MZ7L31T903 | SSD 1,92TB | Cụm: Sangfor cluster9	TỔNG HỢP	771	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SVR-KHO-032	SVR-KHO-032	server	server	\N	server	Openstack	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	241	{}	2026-09-10 04:42:16.035135+00
SVR-J6-3031	cluster926	network_or_host	component	103.15.49.189	103.15.49.189	Cluster9	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use_needs_replacement	Đang sử dụng cần được thay thế	2017-10-01	\N	\N	\N	\N	\N	\N	\N	\N	cluster926 | Cụm: Cluster9	TỔNG HỢP	103	{}	2026-09-10 02:47:38.301245+00
S724NS0Y500164X	SSD Samsung 1.92TB 2.5inch Sata Enterprise PM 893- MZ7L31T904	disk	component	\N	disk	Sangfor cluster9	ODS	ODS	1	\N	\N	\N	Node 103.15.49.40	1,92TB	\N	in_use	Đang sử dụng	2025-02-10	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 1.92TB 2.5inch Sata Enterprise PM 893- MZ7L31T904 | SSD 1,92TB | Cụm: Sangfor cluster9	TỔNG HỢP	772	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S724NS0Y500167M	SSD Samsung 1.92TB 2.5inch Sata Enterprise PM 893- MZ7L31T905	disk	component	\N	disk	Sangfor cluster9	ODS	ODS	1	\N	\N	\N	Node 103.15.49.39	1,92TB	\N	in_use	Đang sử dụng	2025-02-10	\N	\N	\N	\N	\N	\N	\N	\N	SSD Samsung 1.92TB 2.5inch Sata Enterprise PM 893- MZ7L31T905 | SSD 1,92TB | Cụm: Sangfor cluster9	TỔNG HỢP	773	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-RAID-0001	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M	raid_cable	component	\N	Cáp RAID	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	Node 103.110.128.1	\N	\N	in_use	Đang sử dụng	2025-11-13	\N	\N	\N	\N	\N	\N	\N	\N	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M | Cáp RAID | Cụm: CMC1	TỔNG HỢP	774	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-RAID-0002	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M	raid_cable	component	\N	Cáp RAID	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	Node 103.110.128.1	\N	\N	in_use	Đang sử dụng	2025-11-13	\N	\N	\N	\N	\N	\N	\N	\N	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M | Cáp RAID | Cụm: CMC1	TỔNG HỢP	775	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-RAID-0003	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M	raid_cable	component	\N	Cáp RAID	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	Node 103.110.128.2	\N	\N	in_use	Đang sử dụng	2025-11-13	\N	\N	\N	\N	\N	\N	\N	\N	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M | Cáp RAID | Cụm: CMC1	TỔNG HỢP	776	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-RAID-0004	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M	raid_cable	component	\N	Cáp RAID	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	Node 103.110.128.2	\N	\N	in_use	Đang sử dụng	2025-11-13	\N	\N	\N	\N	\N	\N	\N	\N	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M | Cáp RAID | Cụm: CMC1	TỔNG HỢP	777	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-RAID-0005	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M	raid_cable	component	\N	Cáp RAID	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	Node 103.110.128.3	\N	\N	in_use	Đang sử dụng	2025-11-16	\N	\N	\N	\N	\N	\N	\N	\N	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M | Cáp RAID | Cụm: CMC1	TỔNG HỢP	778	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-RAID-0006	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M	raid_cable	component	\N	Cáp RAID	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	Node 103.110.128.3	\N	\N	in_use	Đang sử dụng	2025-11-16	\N	\N	\N	\N	\N	\N	\N	\N	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M | Cáp RAID | Cụm: CMC1	TỔNG HỢP	779	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-RAID-0007	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M	raid_cable	component	\N	Cáp RAID	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	Node 103.110.128.4	\N	\N	in_use	Đang sử dụng	2025-11-18	\N	\N	\N	\N	\N	\N	\N	\N	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M | Cáp RAID | Cụm: CMC1	TỔNG HỢP	780	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-RAID-0008	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M	raid_cable	component	\N	Cáp RAID	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	Node 103.110.128.4	\N	\N	in_use	Đang sử dụng	2025-11-18	\N	\N	\N	\N	\N	\N	\N	\N	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M | Cáp RAID | Cụm: CMC1	TỔNG HỢP	781	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-RAID-0009	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M	raid_cable	component	\N	Cáp RAID	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	Node 103.110.128.5	\N	\N	in_use	Đang sử dụng	2025-11-18	\N	\N	\N	\N	\N	\N	\N	\N	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M | Cáp RAID | Cụm: CMC1	TỔNG HỢP	782	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-RAID-0010	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M	raid_cable	component	\N	Cáp RAID	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	Node 103.110.128.5	\N	\N	in_use	Đang sử dụng	2025-11-18	\N	\N	\N	\N	\N	\N	\N	\N	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M | Cáp RAID | Cụm: CMC1	TỔNG HỢP	783	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-RAID-0011	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M	raid_cable	component	\N	Cáp RAID	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	Node 103.110.128.6	\N	\N	in_use	Đang sử dụng	2025-11-25	\N	\N	\N	\N	\N	\N	\N	\N	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M | Cáp RAID | Cụm: CMC1	TỔNG HỢP	784	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-RAID-0012	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M	raid_cable	component	\N	Cáp RAID	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	Node 103.110.128.6	\N	\N	in_use	Đang sử dụng	2025-11-25	\N	\N	\N	\N	\N	\N	\N	\N	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M | Cáp RAID | Cụm: CMC1	TỔNG HỢP	785	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-RAID-0013	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M	raid_cable	component	\N	Cáp RAID	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	Node 103.110.128.7	\N	\N	in_use	Đang sử dụng	2025-11-25	\N	\N	\N	\N	\N	\N	\N	\N	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M | Cáp RAID | Cụm: CMC1	TỔNG HỢP	786	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-RAID-0014	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M	raid_cable	component	\N	Cáp RAID	CMC1	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	Node 103.110.128.7	\N	\N	in_use	Đang sử dụng	2025-11-25	\N	\N	\N	\N	\N	\N	\N	\N	Dây cáp Slim SAS SFF-8654 4i 38Pin to SFF-8643 dài 1M | Cáp RAID | Cụm: CMC1	TỔNG HỢP	787	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-097	Module quang AOC SFP+ to SFP+ 10G dài 10M	cable	component	\N	cáp	POC Openstack	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	đang sử dụng	2026-10-03	\N	\N	\N	\N	\N	\N	\N	\N	Module quang AOC SFP+ to SFP+ 10G dài 10M | cáp quang 10Gbps 10m | Cụm: POC Openstack	TỔNG HỢP	788	{}	2026-09-10 02:47:38.301245+00
CAP-10-098	Module quang AOC SFP+ to SFP+ 10G dài 10M	cable	component	\N	cáp	POC Openstack	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	đang sử dụng	2026-10-03	\N	\N	\N	\N	\N	\N	\N	\N	Module quang AOC SFP+ to SFP+ 10G dài 10M | cáp quang 10Gbps 10m | Cụm: POC Openstack	TỔNG HỢP	789	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-035	SVR-KHO-035	server	server	\N	server	Openstack	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	244	{}	2026-09-10 04:42:16.035135+00
CAP-10-099	Module quang AOC SFP+ to SFP+ 10G dài 10M	cable	component	\N	cáp	POC Openstack	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	đang sử dụng	2026-10-03	\N	\N	\N	\N	\N	\N	\N	\N	Module quang AOC SFP+ to SFP+ 10G dài 10M | cáp quang 10Gbps 10m | Cụm: POC Openstack	TỔNG HỢP	790	{}	2026-09-10 02:47:38.301245+00
CAP-10-100	Module quang AOC SFP+ to SFP+ 10G dài 10M	cable	component	\N	cáp	POC Openstack	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	đang sử dụng	2026-10-03	\N	\N	\N	\N	\N	\N	\N	\N	Module quang AOC SFP+ to SFP+ 10G dài 10M | cáp quang 10Gbps 10m | Cụm: POC Openstack	TỔNG HỢP	791	{}	2026-09-10 02:47:38.301245+00
CAP-10-101	Module quang AOC SFP+ to SFP+ 10G dài 10M	cable	component	\N	cáp	POC Openstack	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	đang sử dụng	2026-10-03	\N	\N	\N	\N	\N	\N	\N	\N	Module quang AOC SFP+ to SFP+ 10G dài 10M | cáp quang 10Gbps 10m | Cụm: POC Openstack	TỔNG HỢP	792	{}	2026-09-10 02:47:38.301245+00
CAP-10-102	Module quang AOC SFP+ to SFP+ 10G dài 10M	cable	component	\N	cáp	POC Openstack	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	đang sử dụng	2026-10-03	\N	\N	\N	\N	\N	\N	\N	\N	Module quang AOC SFP+ to SFP+ 10G dài 10M | cáp quang 10Gbps 10m | Cụm: POC Openstack	TỔNG HỢP	793	{}	2026-09-10 02:47:38.301245+00
CAP-10-103	Module quang AOC SFP+ to SFP+ 10G dài 10M	cable	component	\N	cáp	POC Openstack	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	đang sử dụng	2026-10-03	\N	\N	\N	\N	\N	\N	\N	\N	Module quang AOC SFP+ to SFP+ 10G dài 10M | cáp quang 10Gbps 10m | Cụm: POC Openstack	TỔNG HỢP	794	{}	2026-09-10 02:47:38.301245+00
CAP-10-104	Module quang AOC SFP+ to SFP+ 10G dài 10M	cable	component	\N	cáp	POC Openstack	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	đang sử dụng	2026-10-03	\N	\N	\N	\N	\N	\N	\N	\N	Module quang AOC SFP+ to SFP+ 10G dài 10M | cáp quang 10Gbps 10m | Cụm: POC Openstack	TỔNG HỢP	795	{}	2026-09-10 02:47:38.301245+00
CAP-10-105	Module quang AOC SFP+ to SFP+ 10G dài 10M	cable	component	\N	cáp	POC Openstack	ODS	ODS	1	\N	\N	\N	SW storage J6 -> J3	\N	\N	in_use	đang sử dụng	2026-10-03	\N	\N	\N	\N	\N	\N	\N	\N	Module quang AOC SFP+ to SFP+ 10G dài 10M | cáp quang 10Gbps 10m | Cụm: POC Openstack	TỔNG HỢP	796	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-106	Module quang AOC SFP+ to SFP+ 10G dài 10M	cable	component	\N	cáp	POC Openstack	ODS	ODS	1	\N	\N	\N	SW storage J6 -> J5	\N	\N	in_use	đang sử dụng	2026-10-03	\N	\N	\N	\N	\N	\N	\N	\N	Module quang AOC SFP+ to SFP+ 10G dài 10M | cáp quang 10Gbps 10m | Cụm: POC Openstack	TỔNG HỢP	797	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
P605A1252A38042	Nguồn Supermicro PWS-605P-1H.	power_supply	component	\N	nguồn	ClusterX1	ODS	ODS	1	\N	\N	\N	Node 103.15.49.203	\N	\N	in_use	đang sử dụng	2026-03-24	\N	\N	\N	\N	\N	\N	\N	\N	Nguồn Supermicro PWS-605P-1H. | Nguồn 600W | Cụm: ClusterX1	TỔNG HỢP	798	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6ESNS0W303693	SSD Enterprise Samsung PM893 1.92TB MZ7L31T9HBLT	disk	component	\N	disk	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	1,92TB	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	SSD Enterprise Samsung PM893 1.92TB MZ7L31T9HBLT | SSD 1,92TB | Cụm: POC Openstack	TỔNG HỢP	799	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6ESNS0W304017	SSD Enterprise Samsung PM893 1.92TB MZ7L31T9HBLT	disk	component	\N	disk	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	1,92TB	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	SSD Enterprise Samsung PM893 1.92TB MZ7L31T9HBLT | SSD 1,92TB | Cụm: POC Openstack	TỔNG HỢP	800	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6ESNS0W306991	SSD Enterprise Samsung PM893 1.92TB MZ7L31T9HBLT	disk	component	\N	disk	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	1,92TB	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	SSD Enterprise Samsung PM893 1.92TB MZ7L31T9HBLT | SSD 1,92TB | Cụm: POC Openstack	TỔNG HỢP	801	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6ESNS0W307357	SSD Enterprise Samsung PM893 1.92TB MZ7L31T9HBLT	disk	component	\N	disk	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	1,92TB	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	SSD Enterprise Samsung PM893 1.92TB MZ7L31T9HBLT | SSD 1,92TB | Cụm: POC Openstack	TỔNG HỢP	802	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6ESNS0W306996	SSD Enterprise Samsung PM893 1.92TB MZ7L31T9HBLT	disk	component	\N	disk	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	1,92TB	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	SSD Enterprise Samsung PM893 1.92TB MZ7L31T9HBLT | SSD 1,92TB | Cụm: POC Openstack	TỔNG HỢP	803	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6ESNS0W303671	SSD Enterprise Samsung PM893 1.92TB MZ7L31T9HBLT	disk	component	\N	disk	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	1,92TB	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	SSD Enterprise Samsung PM893 1.92TB MZ7L31T9HBLT | SSD 1,92TB | Cụm: POC Openstack	TỔNG HỢP	804	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6ESNS0W304005	SSD Enterprise Samsung PM893 1.92TB MZ7L31T9HBLT	disk	component	\N	disk	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	1,92TB	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	SSD Enterprise Samsung PM893 1.92TB MZ7L31T9HBLT | SSD 1,92TB | Cụm: POC Openstack	TỔNG HỢP	805	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6ESNS0W303660	SSD Enterprise Samsung PM893 1.92TB MZ7L31T9HBLT	disk	component	\N	disk	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	1,92TB	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	SSD Enterprise Samsung PM893 1.92TB MZ7L31T9HBLT | SSD 1,92TB | Cụm: POC Openstack	TỔNG HỢP	806	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6ESNS0W304034	SSD Enterprise Samsung PM893 1.92TB MZ7L31T9HBLT	disk	component	\N	disk	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	1,92TB	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	SSD Enterprise Samsung PM893 1.92TB MZ7L31T9HBLT | SSD 1,92TB | Cụm: POC Openstack	TỔNG HỢP	807	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S6ESNS0W304014	SSD Enterprise Samsung PM893 1.92TB MZ7L31T9HBLT	disk	component	\N	disk	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	1,92TB	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	SSD Enterprise Samsung PM893 1.92TB MZ7L31T9HBLT | SSD 1,92TB | Cụm: POC Openstack	TỔNG HỢP	808	{parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
CAP-10-107	Module quang AOC SFP+ to SFP+ 10G dài 10M	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	mới, chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Module quang AOC SFP+ to SFP+ 10G dài 10M | cáp quang 10Gbps 10m	TỔNG HỢP	809	{}	2026-09-10 02:47:38.301245+00
CAP-10-108	Module quang AOC SFP+ to SFP+ 10G dài 10M	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	mới, chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Module quang AOC SFP+ to SFP+ 10G dài 10M | cáp quang 10Gbps 10m	TỔNG HỢP	810	{}	2026-09-10 02:47:38.301245+00
CAP-10-109	Module quang AOC SFP+ to SFP+ 10G dài 10M	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	mới, chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Module quang AOC SFP+ to SFP+ 10G dài 10M | cáp quang 10Gbps 10m	TỔNG HỢP	811	{}	2026-09-10 02:47:38.301245+00
CAP-10-110	Module quang AOC SFP+ to SFP+ 10G dài 10M	cable	component	\N	cáp	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	in_stock	mới, chưa sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	Module quang AOC SFP+ to SFP+ 10G dài 10M | cáp quang 10Gbps 10m	TỔNG HỢP	812	{}	2026-09-10 02:47:38.301245+00
S11D9E957	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	32G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON) | RAM 32G | Cụm: POC Openstack	TỔNG HỢP	813	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SW-J4-44	nexus n3k-c3064pq-10gx	switch	component	\N	switch	ClusterX1	ODS	ODS	1	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	2019-10-01	\N	\N	\N	\N	\N	\N	\N	\N	nexus n3k-c3064pq-10gx | Cụm: ClusterX1	TỔNG HỢP	138	{}	2026-09-10 02:47:38.301245+00
S13EE9E68	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	32G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON) | RAM 32G | Cụm: POC Openstack	TỔNG HỢP	814	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S13EE7DD2	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	32G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON) | RAM 32G | Cụm: POC Openstack	TỔNG HỢP	815	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S12309ED5	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	32G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON) | RAM 32G | Cụm: POC Openstack	TỔNG HỢP	816	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S11D9EA03	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	32G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON) | RAM 32G | Cụm: POC Openstack	TỔNG HỢP	817	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S11DC6554	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	32G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON) | RAM 32G | Cụm: POC Openstack	TỔNG HỢP	818	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S124B27AA	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	32G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON) | RAM 32G | Cụm: POC Openstack	TỔNG HỢP	819	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S11D9EA63	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	32G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON) | RAM 32G | Cụm: POC Openstack	TỔNG HỢP	820	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S12309F0A	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	32G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON) | RAM 32G | Cụm: POC Openstack	TỔNG HỢP	821	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S13DF5A4E	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	32G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON) | RAM 32G | Cụm: POC Openstack	TỔNG HỢP	822	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S11D9E9CF	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	32G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON) | RAM 32G | Cụm: POC Openstack	TỔNG HỢP	823	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S11DC6441	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	32G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON) | RAM 32G | Cụm: POC Openstack	TỔNG HỢP	824	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S11D9E94C	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	32G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON) | RAM 32G | Cụm: POC Openstack	TỔNG HỢP	825	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S11DC66B2	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	32G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON) | RAM 32G | Cụm: POC Openstack	TỔNG HỢP	826	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S11D9E951	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	32G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON) | RAM 32G | Cụm: POC Openstack	TỔNG HỢP	827	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S13EE9A66	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	32G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON) | RAM 32G | Cụm: POC Openstack	TỔNG HỢP	828	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S11D9EA78	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	32G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON) | RAM 32G | Cụm: POC Openstack	TỔNG HỢP	829	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S120113B6	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	32G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON) | RAM 32G | Cụm: POC Openstack	TỔNG HỢP	830	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S11D9E958	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	32G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON) | RAM 32G | Cụm: POC Openstack	TỔNG HỢP	831	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S11DC63FE	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	32G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON) | RAM 32G | Cụm: POC Openstack	TỔNG HỢP	832	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S11D9E94D	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	32G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON) | RAM 32G | Cụm: POC Openstack	TỔNG HỢP	833	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SSD-2TB-001	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07	disk	component	\N	disk	MBO	ODS	ODS	1	\N	\N	\N	\N	1.92TB	\N	in_use	Đang sử dụng	2023-10-04	2023-10-04	Đã bàn giao	1705	3400000	MB045564	Công Ty Cổ Phần Giải Pháp Máy Chủ Việt	36	2026-10-01	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07 | SSD | Cụm: MBO	TỔNG HỢP	3	{}	2026-09-10 02:47:38.301245+00
SSD-2TB-002	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07	disk	component	\N	disk	MBO	ODS	ODS	1	\N	\N	\N	\N	1.92TB	\N	in_use	Đang sử dụng	2023-10-04	2023-10-04	Đã bàn giao	1705	3400000	MB045564	Công Ty Cổ Phần Giải Pháp Máy Chủ Việt	36	2026-10-01	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07 | SSD | Cụm: MBO	TỔNG HỢP	4	{}	2026-09-10 02:47:38.301245+00
SSD-2TB-003	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07	disk	component	\N	disk	MBO	ODS	ODS	1	\N	\N	\N	\N	1.92TB	\N	in_use	Đang sử dụng	2023-10-04	2023-10-04	Đã bàn giao	1705	3400000	MB045564	Công Ty Cổ Phần Giải Pháp Máy Chủ Việt	36	2026-10-01	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07 | SSD | Cụm: MBO	TỔNG HỢP	5	{}	2026-09-10 02:47:38.301245+00
SSD-2TB-004	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07	disk	component	\N	disk	MBO	ODS	ODS	1	\N	\N	\N	\N	1.92TB	\N	in_use	Đang sử dụng	2023-10-04	2023-10-04	Đã bàn giao	1705	3400000	MB045564	Công Ty Cổ Phần Giải Pháp Máy Chủ Việt	36	2026-10-01	Ổ cứng SSD Samsung PM893 1.92TB MZ7L31T9HBLT-00A07 | SSD | Cụm: MBO	TỔNG HỢP	6	{}	2026-09-10 02:47:38.301245+00
SVR-KHO-036	SVR-KHO-036	server	server	\N	server	Openstack	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	245	{}	2026-09-10 04:44:53.064604+00
SVR-KHO-037	SVR-KHO-037	server	server	\N	server	Openstack	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	246	{}	2026-09-10 04:44:53.064604+00
SVR-KHO-038	SVR-KHO-038	server	server	\N	server	Openstack	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	247	{}	2026-09-10 04:44:53.064604+00
SVR-KHO-039	SVR-KHO-039	server	server	\N	server	Openstack	CMC Tân Thuận	CMC Tân Thuận	15	\N	\N	\N	\N	\N	\N	in_use	Đang sử dụng	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TỔNG HỢP	248	{}	2026-09-10 04:44:53.064604+00
HDD-4TB-0034	HDD SAS 4TB	disk	component	\N	hdd	\N	Kho	Kho	32	\N	\N	\N	\N	\N	\N	broken	Hỏng	\N	\N	\N	\N	\N	\N	\N	\N	\N	HDD SAS 4TB	TỔNG HỢP	421	{}	2026-09-10 02:47:38.301245+00
S13EF024C	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	32G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON) | RAM 32G | Cụm: POC Openstack	TỔNG HỢP	834	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S13EE9E64	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	32G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 32GB RAM ECC REG DDR4 BUS 2133 32G (MICRON) | RAM 32G | Cụm: POC Openstack	TỔNG HỢP	835	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S11E67451	RAM 16GB RAM ECC REG DDR4 BUS 2133 16G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	16G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 16GB RAM ECC REG DDR4 BUS 2133 16G (MICRON) | RAM 16G | Cụm: POC Openstack	TỔNG HỢP	836	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S11586B58	RAM 16GB RAM ECC REG DDR4 BUS 2133 16G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	16G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 16GB RAM ECC REG DDR4 BUS 2133 16G (MICRON) | RAM 16G | Cụm: POC Openstack	TỔNG HỢP	838	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S11586B4E	RAM 16GB RAM ECC REG DDR4 BUS 2133 16G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	16G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 16GB RAM ECC REG DDR4 BUS 2133 16G (MICRON) | RAM 16G | Cụm: POC Openstack	TỔNG HỢP	839	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S11E13E30	RAM 16GB RAM ECC REG DDR4 BUS 2133 16G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	16G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 16GB RAM ECC REG DDR4 BUS 2133 16G (MICRON) | RAM 16G | Cụm: POC Openstack	TỔNG HỢP	840	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SOF7C576F	RAM 16GB RAM ECC REG DDR4 BUS 2133 16G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	16G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 16GB RAM ECC REG DDR4 BUS 2133 16G (MICRON) | RAM 16G | Cụm: POC Openstack	TỔNG HỢP	841	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
SOF7C5770	RAM 16GB RAM ECC REG DDR4 BUS 2133 16G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	16G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 16GB RAM ECC REG DDR4 BUS 2133 16G (MICRON) | RAM 16G | Cụm: POC Openstack	TỔNG HỢP	842	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S0F7C6A87	RAM 16GB RAM ECC REG DDR4 BUS 2133 16G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	16G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 16GB RAM ECC REG DDR4 BUS 2133 16G (MICRON) | RAM 16G | Cụm: POC Openstack	TỔNG HỢP	843	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
S1181AAA0	RAM 16GB RAM ECC REG DDR4 BUS 2133 16G (MICRON)	ram	component	\N	RAM	POC Openstack	ODS	ODS	1	\N	\N	\N	POC Openstack	16G	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	RAM 16GB RAM ECC REG DDR4 BUS 2133 16G (MICRON) | RAM 16G | Cụm: POC Openstack	TỔNG HỢP	844	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
M6P24T1802257	CPU-E5-2699 v4 Intel® Xeon® Processor E5-2699 v4 55M Cache, 2.20 GHz	cpu	component	\N	CPU	POC Openstack	ODS	ODS	1	\N	\N	\N	node 103.15.49.143	\N	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	CPU-E5-2699 v4 Intel® Xeon® Processor E5-2699 v4 55M Cache, 2.20 GHz | CPU | Cụm: POC Openstack	TỔNG HỢP	845	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
M7VF915500185	CPU-E5-2699 v4 Intel® Xeon® Processor E5-2699 v4 55M Cache, 2.20 GHz	cpu	component	\N	CPU	POC Openstack	ODS	ODS	1	\N	\N	\N	node 103.15.49.143	\N	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	CPU-E5-2699 v4 Intel® Xeon® Processor E5-2699 v4 55M Cache, 2.20 GHz | CPU | Cụm: POC Openstack	TỔNG HỢP	846	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
M772XT5800807	CPU-E5-2699 v4 Intel® Xeon® Processor E5-2699 v4 55M Cache, 2.20 GHz	cpu	component	\N	CPU	POC Openstack	ODS	ODS	1	\N	\N	\N	node 103.15.49.144	\N	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	CPU-E5-2699 v4 Intel® Xeon® Processor E5-2699 v4 55M Cache, 2.20 GHz | CPU | Cụm: POC Openstack	TỔNG HỢP	847	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
M8RU258401900	CPU-E5-2699 v4 Intel® Xeon® Processor E5-2699 v4 55M Cache, 2.20 GHz	cpu	component	\N	CPU	POC Openstack	ODS	ODS	1	\N	\N	\N	node 103.15.49.144	\N	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	CPU-E5-2699 v4 Intel® Xeon® Processor E5-2699 v4 55M Cache, 2.20 GHz | CPU | Cụm: POC Openstack	TỔNG HỢP	848	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
M6L68C6300519	CPU-E5-2699 v4 Intel® Xeon® Processor E5-2699 v4 55M Cache, 2.20 GHz	cpu	component	\N	CPU	POC Openstack	ODS	ODS	1	\N	\N	\N	node 103.15.49.148	\N	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	CPU-E5-2699 v4 Intel® Xeon® Processor E5-2699 v4 55M Cache, 2.20 GHz | CPU | Cụm: POC Openstack	TỔNG HỢP	849	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
M7YY867501625	CPU-E5-2699 v4 Intel® Xeon® Processor E5-2699 v4 55M Cache, 2.20 GHz	cpu	component	\N	CPU	POC Openstack	ODS	ODS	1	\N	\N	\N	node 103.15.49.144	\N	\N	in_use	Đang sử dụng	2026-05-19	\N	\N	\N	\N	\N	\N	\N	\N	CPU-E5-2699 v4 Intel® Xeon® Processor E5-2699 v4 55M Cache, 2.20 GHz | CPU | Cụm: POC Openstack	TỔNG HỢP	850	{unmapped_ip_or_type,parent_reference_unresolved}	2026-09-10 02:47:38.301245+00
\.


--
-- Data for Name: asset_event; Type: TABLE DATA; Schema: public; Owner: atlas
--

COPY public.asset_event (id, asset_id, event_sequence, event_type, event_date, location, usage_object, notes, declared_transition_count, source_column, source_row, review_flags) FROM stdin;
1	SSD-2TB-001	0	handover_received	2023-10-04	\N	\N	\N	2	K	3	{handover_location_unknown}
2	SSD-2TB-001	1	usage_stage_1	2023-10-04	ODS	MBO	\N	2	S/T/U	3	{}
3	SSD-2TB-001	2	usage_stage_2	2024-06-13	\N	Cluster9	\N	2	V/W/X/Y	3	{history_tuple_incomplete,missing_event_location}
4	SSD-2TB-002	0	handover_received	2023-10-04	\N	\N	\N	2	K	4	{handover_location_unknown}
5	SSD-2TB-002	1	usage_stage_1	2023-10-04	ODS	MBO	\N	2	S/T/U	4	{}
6	SSD-2TB-002	2	usage_stage_2	2024-06-13	\N	Cluster9	\N	2	V/W/X/Y	4	{history_tuple_incomplete,missing_event_location}
7	SSD-2TB-003	0	handover_received	2023-10-04	\N	\N	\N	2	K	5	{handover_location_unknown}
8	SSD-2TB-003	1	usage_stage_1	2023-10-04	ODS	MBO	\N	2	S/T/U	5	{}
9	SSD-2TB-003	2	usage_stage_2	2024-06-13	\N	Cluster9	\N	2	V/W/X/Y	5	{history_tuple_incomplete,missing_event_location}
10	SSD-2TB-004	0	handover_received	2023-10-04	\N	\N	\N	2	K	6	{handover_location_unknown}
11	SSD-2TB-004	1	usage_stage_1	2023-10-04	ODS	MBO	\N	2	S/T/U	6	{}
12	SSD-2TB-004	2	usage_stage_2	2024-06-13	\N	Cluster9	\N	2	V/W/X/Y	6	{history_tuple_incomplete,missing_event_location}
13	SSD-2TB-005	0	handover_received	2023-10-04	\N	\N	\N	2	K	7	{handover_location_unknown}
14	SSD-2TB-005	1	usage_stage_1	2023-10-04	ODS	MBO	\N	2	S/T/U	7	{}
69	SSD-8TB-007	0	handover_received	2023-05-04	\N	\N	\N	\N	K	30	{handover_location_unknown}
15	SSD-2TB-005	2	usage_stage_2	2024-06-13	\N	Cluster9	\N	2	V/W/X/Y	7	{history_tuple_incomplete,missing_event_location}
16	SSD-2TB-006	0	handover_received	2023-10-04	\N	\N	\N	2	K	8	{handover_location_unknown}
17	SSD-2TB-006	1	usage_stage_1	2023-10-04	ODS	MBO	\N	2	S/T/U	8	{}
18	SSD-2TB-006	2	usage_stage_2	2024-06-13	\N	Cluster9	\N	2	V/W/X/Y	8	{history_tuple_incomplete,missing_event_location}
19	SSD-2TB-007	0	handover_received	2023-10-04	\N	\N	\N	1	K	9	{handover_location_unknown}
20	SSD-2TB-007	1	usage_stage_1	2023-10-04	ODS	MBO	\N	1	S/T/U	9	{}
21	SSD-2TB-007	2	usage_stage_2	2024-04-01	\N	ClusterX1	\N	1	V/W/X/Y	9	{history_tuple_incomplete,missing_event_location}
22	SSD-2TB-008	0	handover_received	2023-10-04	\N	\N	\N	1	K	10	{handover_location_unknown}
23	SSD-2TB-008	1	usage_stage_1	2023-10-04	ODS	MBO	\N	1	S/T/U	10	{}
24	SSD-2TB-008	2	usage_stage_2	2024-04-01	\N	ClusterX1	\N	1	V/W/X/Y	10	{history_tuple_incomplete,missing_event_location}
25	SSD-2TB-009	0	handover_received	2023-10-04	\N	\N	\N	1	K	11	{handover_location_unknown}
26	SSD-2TB-009	1	usage_stage_1	2023-10-04	ODS	MBO	\N	1	S/T/U	11	{}
27	SSD-2TB-009	2	usage_stage_2	2024-04-01	\N	ClusterX1	\N	1	V/W/X/Y	11	{history_tuple_incomplete,missing_event_location}
28	SSD-2TB-010	0	handover_received	2023-10-04	\N	\N	\N	1	K	12	{handover_location_unknown}
29	SSD-2TB-010	1	usage_stage_1	2023-10-04	ODS	MBO	\N	1	S/T/U	12	{}
30	SSD-2TB-010	2	usage_stage_2	2024-04-01	\N	ClusterX1	\N	1	V/W/X/Y	12	{history_tuple_incomplete,missing_event_location}
31	SSD-2TB-011	0	handover_received	2023-10-04	\N	\N	\N	1	K	13	{handover_location_unknown}
32	SSD-2TB-011	1	usage_stage_1	2023-10-04	ODS	MBO	\N	1	S/T/U	13	{}
33	SSD-2TB-011	2	usage_stage_2	2024-04-01	\N	ClusterX1	\N	1	V/W/X/Y	13	{history_tuple_incomplete,missing_event_location}
34	SSD-2TB-012	0	handover_received	2023-10-04	\N	\N	\N	1	K	14	{handover_location_unknown}
35	SSD-2TB-012	1	usage_stage_1	2023-10-04	ODS	MBO	\N	1	S/T/U	14	{}
36	SSD-2TB-012	2	usage_stage_2	2024-04-01	\N	ClusterX1	\N	1	V/W/X/Y	14	{history_tuple_incomplete,missing_event_location}
37	SW-J6-12	0	handover_received	2023-10-04	\N	\N	\N	1	K	15	{handover_location_unknown}
38	SW-J6-12	1	usage_stage_1	2023-10-04	ODS	MBO	\N	1	S/T/U	15	{}
39	SW-J6-12	2	usage_stage_2	2025-12-17	Kho	\N	\N	1	V/W/X/Y	15	{history_tuple_incomplete,missing_usage_object}
40	SW-J6-13	0	handover_received	2023-10-04	\N	\N	\N	1	K	16	{handover_location_unknown}
41	SW-J6-13	1	usage_stage_1	2023-10-04	ODS	MBO	\N	1	S/T/U	16	{}
42	SW-J6-13	2	usage_stage_2	2025-12-17	Kho	\N	\N	1	V/W/X/Y	16	{history_tuple_incomplete,missing_usage_object}
43	SVR-P7-3839	0	handover_received	2023-05-04	\N	\N	\N	\N	K	17	{handover_location_unknown}
44	SVR-P7-3839	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	17	{}
45	SVR-P7-3637	0	handover_received	2023-05-04	\N	\N	\N	\N	K	18	{handover_location_unknown}
46	SVR-P7-3637	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	18	{}
47	SVR-P7-3334	0	handover_received	2023-05-04	\N	\N	\N	\N	K	19	{handover_location_unknown}
48	SVR-P7-3334	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	19	{}
49	SVR-P7-3132	0	handover_received	2023-05-04	\N	\N	\N	\N	K	20	{handover_location_unknown}
50	SVR-P7-3132	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	20	{}
51	SVR-P7-2829	0	handover_received	2023-05-04	\N	\N	\N	\N	K	21	{handover_location_unknown}
52	SVR-P7-2829	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	21	{}
53	SVR-P7-2627	0	handover_received	2023-05-04	\N	\N	\N	\N	K	22	{handover_location_unknown}
54	SVR-P7-2627	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	22	{}
55	SVR-P7-2324	0	handover_received	2023-05-04	\N	\N	\N	\N	K	23	{handover_location_unknown}
56	SVR-P7-2324	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	23	{}
57	SSD-8TB-001	0	handover_received	2023-05-04	\N	\N	\N	\N	K	24	{handover_location_unknown}
58	SSD-8TB-001	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	24	{}
59	SSD-8TB-002	0	handover_received	2023-05-04	\N	\N	\N	\N	K	25	{handover_location_unknown}
60	SSD-8TB-002	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	25	{}
61	SSD-8TB-003	0	handover_received	2023-05-04	\N	\N	\N	\N	K	26	{handover_location_unknown}
62	SSD-8TB-003	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	26	{}
63	SSD-8TB-004	0	handover_received	2023-05-04	\N	\N	\N	\N	K	27	{handover_location_unknown}
64	SSD-8TB-004	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	27	{}
65	SSD-8TB-005	0	handover_received	2023-05-04	\N	\N	\N	\N	K	28	{handover_location_unknown}
66	SSD-8TB-005	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	28	{}
67	SSD-8TB-006	0	handover_received	2023-05-04	\N	\N	\N	\N	K	29	{handover_location_unknown}
68	SSD-8TB-006	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	29	{}
70	SSD-8TB-007	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	30	{}
71	SSD-8TB-008	0	handover_received	2023-05-04	\N	\N	\N	\N	K	31	{handover_location_unknown}
72	SSD-8TB-008	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	31	{}
73	SSD-8TB-009	0	handover_received	2023-05-04	\N	\N	\N	\N	K	32	{handover_location_unknown}
74	SSD-8TB-009	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	32	{}
75	SSD-8TB-010	0	handover_received	2023-05-04	\N	\N	\N	\N	K	33	{handover_location_unknown}
76	SSD-8TB-010	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	33	{}
77	SSD-240-001	0	handover_received	2023-05-04	Kho	\N	\N	\N	K	34	{}
78	SSD-240-002	0	handover_received	2023-05-04	Kho	\N	\N	\N	K	35	{}
79	SSD-240-003	0	handover_received	2023-05-04	Kho	\N	\N	\N	K	36	{}
80	SSD-240-004	0	handover_received	2023-05-04	Kho	\N	\N	\N	K	37	{}
81	SSD-960-001	0	handover_received	2023-05-04	\N	\N	\N	\N	K	38	{handover_location_unknown}
82	SSD-960-001	1	usage_stage_1	2024-05-04	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	38	{}
83	SSD-960-002	0	handover_received	2023-05-04	\N	\N	\N	\N	K	39	{handover_location_unknown}
84	SSD-960-002	1	usage_stage_1	2024-05-04	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	39	{}
85	SSD-960-003	0	handover_received	2023-05-04	\N	\N	\N	\N	K	40	{handover_location_unknown}
86	SSD-960-003	1	usage_stage_1	2024-05-04	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	40	{}
87	SSD-960-004	0	handover_received	2023-05-04	\N	\N	\N	\N	K	41	{handover_location_unknown}
88	SSD-960-004	1	usage_stage_1	2024-05-04	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	41	{}
89	SSD-960-005	0	handover_received	2023-05-04	\N	\N	\N	\N	K	42	{handover_location_unknown}
90	SSD-960-005	1	usage_stage_1	2024-05-04	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	42	{}
91	SSD-960-006	0	handover_received	2023-05-04	\N	\N	\N	\N	K	43	{handover_location_unknown}
92	SSD-960-006	1	usage_stage_1	2024-05-04	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	43	{}
93	CAP-40-0001	0	handover_received	2023-05-04	\N	\N	\N	\N	K	44	{handover_location_unknown}
94	CAP-40-0001	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	44	{}
95	CAP-40-0002	0	handover_received	2023-05-04	\N	\N	\N	\N	K	45	{handover_location_unknown}
96	CAP-40-0002	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	45	{}
97	CAP-40-0003	0	handover_received	2023-05-04	\N	\N	\N	\N	K	46	{handover_location_unknown}
98	CAP-40-0003	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	46	{}
99	CAP-40-0004	0	handover_received	2023-05-04	\N	\N	\N	\N	K	47	{handover_location_unknown}
100	CAP-40-0004	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	47	{}
101	CAP-40-0005	0	handover_received	2023-05-04	\N	\N	\N	\N	K	48	{handover_location_unknown}
102	CAP-40-0005	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	48	{}
103	CAP-40-0006	0	handover_received	2023-05-04	\N	\N	\N	\N	K	49	{handover_location_unknown}
104	CAP-40-0006	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	49	{}
105	CAP-40-0007	0	handover_received	2023-05-04	\N	\N	\N	\N	K	50	{handover_location_unknown}
106	CAP-40-0007	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	50	{}
107	CAP-40-0008	0	handover_received	2023-05-04	\N	\N	\N	\N	K	51	{handover_location_unknown}
108	CAP-40-0008	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	51	{}
109	CAP-40-0009	0	handover_received	2023-05-04	\N	\N	\N	\N	K	52	{handover_location_unknown}
110	CAP-40-0009	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	52	{}
111	CAP-40-0010	0	handover_received	2023-05-04	\N	\N	\N	\N	K	53	{handover_location_unknown}
112	CAP-40-0010	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	53	{}
113	CAP-40-0011	0	handover_received	2023-05-04	\N	\N	\N	\N	K	54	{handover_location_unknown}
114	CAP-40-0011	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	54	{}
115	CAP-40-0012	0	handover_received	2023-05-04	\N	\N	\N	\N	K	55	{handover_location_unknown}
116	CAP-40-0012	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	55	{}
117	CAP-40-0013	0	handover_received	2023-05-04	\N	\N	\N	\N	K	56	{handover_location_unknown}
118	CAP-40-0013	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	56	{}
119	CAP-40-0014	0	handover_received	2023-05-04	\N	\N	\N	\N	K	57	{handover_location_unknown}
120	CAP-40-0014	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	57	{}
121	CAP-10-0001	0	handover_received	2023-05-04	\N	\N	\N	\N	K	58	{handover_location_unknown}
122	CAP-10-0001	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	58	{}
123	CAP-10-0002	0	handover_received	2023-05-04	\N	\N	\N	\N	K	59	{handover_location_unknown}
124	CAP-10-0002	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	59	{}
125	CAP-10-0003	0	handover_received	2023-05-04	\N	\N	\N	\N	K	60	{handover_location_unknown}
126	CAP-10-0003	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	60	{}
127	CAP-10-0004	0	handover_received	2023-05-04	\N	\N	\N	\N	K	61	{handover_location_unknown}
128	CAP-10-0004	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	61	{}
129	CAP-10-0005	0	handover_received	2023-05-04	\N	\N	\N	\N	K	62	{handover_location_unknown}
130	CAP-10-0005	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	62	{}
131	CAP-10-0006	0	handover_received	2023-05-04	\N	\N	\N	\N	K	63	{handover_location_unknown}
132	CAP-10-0006	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	63	{}
133	CAP-10-0007	0	handover_received	2023-05-04	\N	\N	\N	\N	K	64	{handover_location_unknown}
134	CAP-10-0007	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	64	{}
135	CAP-10-0008	0	handover_received	2023-05-04	\N	\N	\N	\N	K	65	{handover_location_unknown}
136	CAP-10-0008	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	65	{}
137	CAP-10-0009	0	handover_received	2023-05-04	\N	\N	\N	\N	K	66	{handover_location_unknown}
138	CAP-10-0009	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	66	{}
139	CAP-10-0010	0	handover_received	2023-05-04	\N	\N	\N	\N	K	67	{handover_location_unknown}
140	CAP-10-0010	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	67	{}
141	CAP-10-0011	0	handover_received	2023-05-04	\N	\N	\N	\N	K	68	{handover_location_unknown}
142	CAP-10-0011	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	68	{}
143	CAP-10-0012	0	handover_received	2023-05-04	\N	\N	\N	\N	K	69	{handover_location_unknown}
144	CAP-10-0012	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	69	{}
145	CAP-10-0013	0	handover_received	2023-05-04	\N	\N	\N	\N	K	70	{handover_location_unknown}
146	CAP-10-0013	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	70	{}
147	CAP-10-0014	0	handover_received	2023-05-04	\N	\N	\N	\N	K	71	{handover_location_unknown}
148	CAP-10-0014	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	71	{}
149	SW-P7-44	0	handover_received	2023-05-04	\N	\N	\N	\N	K	72	{handover_location_unknown}
150	SW-P7-44	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	72	{}
151	SW-P7-45	0	handover_received	2023-05-04	\N	\N	\N	\N	K	73	{handover_location_unknown}
152	SW-P7-45	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	73	{}
153	SW-P7-47	0	handover_received	2023-05-04	\N	\N	\N	\N	K	74	{handover_location_unknown}
154	SW-P7-47	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	74	{}
155	SW-P7-48	0	handover_received	2023-05-04	\N	\N	\N	\N	K	75	{handover_location_unknown}
156	SW-P7-48	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	75	{}
157	CAP-STACK-001	0	handover_received	2023-05-04	\N	\N	\N	\N	K	76	{handover_location_unknown}
158	CAP-STACK-001	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	76	{}
159	CAP-STACK-002	0	handover_received	2023-05-04	\N	\N	\N	\N	K	77	{handover_location_unknown}
160	CAP-STACK-002	1	usage_stage_1	2024-05-04	CMC Tân Thuận	Email	\N	\N	S/T/U	77	{}
161	NGUON-600-001	0	handover_received	2024-04-23	Kho	\N	\N	\N	K	78	{}
162	NGUON-600-001	1	usage_stage_1	2024-04-23	Kho	\N	\N	\N	S/T/U	78	{}
163	SVR-J5-0607	0	usage_stage_1	2019-05-01	ODS	Email	\N	\N	S/T/U	79	{}
164	SVR-J5-0910	0	usage_stage_1	2019-05-01	ODS	Email	\N	\N	S/T/U	80	{}
165	SVR-J5-1112	0	usage_stage_1	2019-05-01	ODS	Email	\N	\N	S/T/U	81	{}
166	SVR-J5-1415	0	usage_stage_1	2019-05-01	ODS	Email	\N	\N	S/T/U	82	{}
167	SVR-J5-1617	0	usage_stage_1	2019-05-01	ODS	Email	\N	\N	S/T/U	83	{}
168	SVR-J5-1920	0	usage_stage_1	2019-05-01	ODS	Email	\N	\N	S/T/U	84	{}
169	SVR-J5-2122	0	usage_stage_1	2019-05-01	ODS	Email	\N	\N	S/T/U	85	{}
170	SVR-J5-2425	0	usage_stage_1	2019-05-01	ODS	Email	\N	\N	S/T/U	86	{}
171	SVR-J5-2627	0	usage_stage_1	2019-05-01	ODS	Email	\N	\N	S/T/U	87	{}
172	SVR-J5-2930	0	usage_stage_1	2019-05-01	ODS	Email	\N	\N	S/T/U	88	{}
173	SVR-J5-3132	0	usage_stage_1	2019-05-01	ODS	Email	\N	\N	S/T/U	89	{}
174	SVR-J5-3435	0	usage_stage_1	2019-05-01	ODS	Email	\N	\N	S/T/U	90	{}
175	SVR-J5-3637	0	usage_stage_1	2019-05-01	ODS	Email	\N	\N	S/T/U	91	{}
176	SW-J5-39	0	usage_stage_1	2019-05-01	ODS	Email	\N	\N	S/T/U	92	{}
177	SW-J5-40	0	usage_stage_1	2019-05-01	ODS	Email	\N	\N	S/T/U	93	{}
178	SW-J5-43	0	usage_stage_1	2019-05-01	ODS	Email	\N	\N	S/T/U	94	{}
179	SW-J5-45	0	usage_stage_1	2019-05-01	ODS	Hosting, CloudServer, Email	\N	\N	S/T/U	95	{}
180	SW-J5-46	0	usage_stage_1	2019-05-01	ODS	Hosting, CloudServer, Email	\N	\N	S/T/U	96	{}
181	SVR-J6-1516	0	usage_stage_1	2017-10-01	ODS	Hosting, CloudServer	\N	\N	S/T/U	97	{}
182	SVR-J6-1516	1	usage_stage_2	2025-12-15	Kho	Lưu trữ	\N	\N	V/W/X/Y	97	{}
183	SVR-J6-1819	0	usage_stage_1	2017-10-01	ODS	Hosting	\N	\N	S/T/U	98	{}
184	SVR-J6-2021	0	usage_stage_1	2017-10-01	ODS	Hosting	\N	\N	S/T/U	99	{}
185	SVR-J6-2324	0	usage_stage_1	2017-10-01	ODS	Hosting	\N	\N	S/T/U	100	{}
186	SVR-J6-2526	0	usage_stage_1	2017-10-01	ODS	Hosting	\N	\N	S/T/U	101	{}
187	SVR-J6-2829	0	usage_stage_1	2017-10-01	ODS	Hosting	\N	\N	S/T/U	102	{}
188	SVR-J6-3031	0	usage_stage_1	2017-10-01	ODS	Hosting	\N	\N	S/T/U	103	{}
189	SVR-J6-4041	0	usage_stage_1	2017-10-01	ODS	Hosting	\N	\N	S/T/U	104	{}
190	SVR-J6-3839	0	usage_stage_1	2017-10-01	ODS	Hosting	\N	\N	S/T/U	105	{}
191	SVR-J6-3536	0	usage_stage_1	2017-10-01	ODS	Hosting	\N	\N	S/T/U	106	{}
192	SVR-J6-3334	0	usage_stage_1	2017-10-01	ODS	Hosting	\N	\N	S/T/U	107	{}
193	SW-J6-43	0	usage_stage_1	2017-10-01	ODS	Hosting	\N	\N	S/T/U	108	{}
194	SW-J6-44	0	usage_stage_1	2017-10-01	ODS	Hosting	\N	\N	S/T/U	109	{}
195	SW-J6-46	0	usage_stage_1	2017-10-01	ODS	Hosting	\N	\N	S/T/U	110	{}
196	SVR-J3-2425	0	usage_stage_1	2017-10-01	ODS	CloudServer	\N	\N	S/T/U	111	{}
197	SVR-J3-2425	1	usage_stage_2	2025-12-15	Kho	Lưu trữ	\N	\N	V/W/X/Y	111	{}
198	SVR-J3-2627	0	usage_stage_1	2017-10-01	ODS	CloudServer	\N	\N	S/T/U	112	{}
199	SVR-J3-2627	1	usage_stage_2	2025-12-15	Kho	Lưu trữ	\N	\N	V/W/X/Y	112	{}
200	SVR-J3-2931	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	113	{}
201	SVR-J3-3234	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	114	{}
202	SVR-J3-3637	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	115	{}
203	SVR-J3-3839	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	116	{}
204	SVR-J3-4142	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	117	{}
205	SVR-J3-4344	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	118	{}
206	SW-J3-45	0	usage_stage_1	2019-10-01	ODS	MBO,Email,Hosting,CloudServer,MBIN&MBCA	\N	\N	S/T/U	119	{}
207	SW-J3-45	1	usage_stage_2	2026-08-09	CMC	\N	\N	\N	V/W/X/Y	119	{invalid_transition_count,history_tuple_incomplete,missing_usage_object}
208	SW-J3-46	0	usage_stage_1	2019-10-01	ODS	MBO,Email,Hosting,CloudServer,MBIN&MBCA	\N	\N	S/T/U	120	{}
209	SVR-J4-0304	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	121	{}
210	SVR-J4-0506	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	122	{}
211	SVR-J4-0809	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	123	{}
212	SVR-J4-1011	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	124	{}
213	SVR-J4-1314	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	125	{}
214	SVR-J4-1516	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	126	{}
215	SVR-J4-1819	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	127	{}
216	SVR-J4-2021	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	128	{}
217	SVR-J4-2324	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	129	{}
218	SVR-J4-2526	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	130	{}
219	SVR-J4-2829	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	131	{}
220	SVR-J4-3031	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	132	{}
221	SVR-J4-4041	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	133	{}
222	SVR-J4-3839	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	134	{}
223	SVR-J4-3536	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	135	{}
224	SVR-J4-3334	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	136	{}
225	SW-J4-43	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	137	{}
226	SW-J4-44	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	138	{}
227	SW-J4-46	0	usage_stage_1	2019-10-01	ODS	CloudServer	\N	\N	S/T/U	139	{}
228	SVR-J6-0910	0	usage_stage_1	2017-10-01	ODS	MBO	\N	2	S/T/U	140	{}
229	SVR-J6-0910	1	usage_stage_2	2024-10-28	\N	Sangfor tạm	\N	2	V/W/X/Y	140	{history_tuple_incomplete,missing_event_location}
230	SVR-J6-0910	2	usage_stage_3	2025-12-15	\N	Cluster 9	\N	2	V/W/X/Y	140	{history_tuple_incomplete,missing_event_location}
231	SVR-J6-0708	0	usage_stage_1	2017-10-01	ODS	MBO	\N	2	S/T/U	141	{}
232	SVR-J6-0708	1	usage_stage_2	2024-10-28	\N	Sangfor tạm	\N	2	V/W/X/Y	141	{history_tuple_incomplete,missing_event_location}
233	SVR-J6-0708	2	usage_stage_3	2025-12-15	\N	Cluster 9	\N	2	V/W/X/Y	141	{history_tuple_incomplete,missing_event_location}
234	SVR-J6-0405	0	usage_stage_1	2017-10-01	ODS	MBO	\N	2	S/T/U	142	{}
235	SVR-J6-0405	1	usage_stage_2	2024-10-28	\N	Sangfor tạm	\N	2	V/W/X/Y	142	{history_tuple_incomplete,missing_event_location}
236	SVR-J6-0405	2	usage_stage_3	2025-12-15	\N	Cluster 9	\N	2	V/W/X/Y	142	{history_tuple_incomplete,missing_event_location}
237	SVR-AQ53-3031	0	usage_stage_1	2020-07-01	VNPT Tân Thuận	Hosting	\N	\N	S/T/U	143	{}
238	SVR-AQ53-1718	0	usage_stage_1	2020-07-01	VNPT Tân Thuận	Hosting	\N	\N	S/T/U	144	{}
239	SVR-AQ53-2627	0	usage_stage_1	2020-07-01	VNPT Tân Thuận	Hosting	\N	\N	S/T/U	145	{}
240	SVR-AQ53-2425	0	usage_stage_1	2020-07-01	VNPT Tân Thuận	Hosting	\N	\N	S/T/U	146	{}
241	SVR-AQ53-2223	0	usage_stage_1	2020-07-01	VNPT Tân Thuận	Hosting	\N	\N	S/T/U	147	{}
242	SVR-AQ53-2021	0	usage_stage_1	2020-07-01	VNPT Tân Thuận	Hosting	\N	\N	S/T/U	148	{}
243	SVR-AQ54-3637	0	usage_stage_1	2020-07-01	VNPT Tân Thuận	Hosting	\N	\N	S/T/U	149	{}
244	SVR-AQ54-3435	0	usage_stage_1	2020-07-01	VNPT Tân Thuận	Hosting	\N	\N	S/T/U	150	{}
245	SVR-AQ54-3233	0	usage_stage_1	2020-07-01	VNPT Tân Thuận	Hosting	\N	\N	S/T/U	151	{}
246	SVR-AQ54-2930	0	usage_stage_1	2017-10-01	VNPT Tân Thuận	Hosting	\N	\N	S/T/U	152	{}
247	SVR-AQ54-2627	0	usage_stage_1	2017-10-01	VNPT Tân Thuận	Hosting	\N	2	S/T/U	153	{}
248	SVR-AQ54-2627	1	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	2	V/W/X/Y	153	{}
249	SVR-AQ54-2627	2	usage_stage_3	2025-12-17	VNPT	VNPT1	\N	2	V/W/X/Y	153	{}
250	SVR-AQ54-2324	0	usage_stage_1	2017-10-01	VNPT Tân Thuận	Hosting	\N	\N	S/T/U	154	{}
251	SW-AQ53-32	0	usage_stage_1	2020-07-01	VNPT Tân Thuận	Hosting	\N	\N	S/T/U	155	{}
252	SW-AQ53-33	0	usage_stage_1	2020-07-01	VNPT Tân Thuận	Hosting	\N	\N	S/T/U	156	{}
253	SW-AQ53-35	0	usage_stage_1	2020-07-01	VNPT Tân Thuận	Hosting	\N	\N	S/T/U	157	{}
254	SW-AQ53-36	0	usage_stage_1	2020-07-01	VNPT Tân Thuận	Hosting	\N	\N	S/T/U	158	{}
255	SVR-BD51-1314	0	usage_stage_1	2017-10-01	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	159	{}
256	SVR-BD51-1617	0	usage_stage_1	2017-10-01	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	160	{}
257	SVR-BD51-1920	0	usage_stage_1	2017-10-01	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	161	{}
258	SVR-BD51-3940	0	usage_stage_1	2017-10-01	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	162	{}
259	SVR-BD51-3738	0	usage_stage_1	2017-10-01	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	163	{}
260	SVR-BD51-3536	0	usage_stage_1	2017-10-01	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	164	{}
261	NAS-BD51-3334	0	usage_stage_1	2022-07-01	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	165	{}
262	FW-BD51-10	0	usage_stage_1	2022-07-01	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	166	{}
263	HSM-BD51-0405	0	usage_stage_1	2022-07-01	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	168	{}
264	HSM-BD51-0607	0	usage_stage_1	2022-07-01	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	169	{}
265	HSM-BD51-27	0	usage_stage_1	2022-07-01	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	170	{}
266	HSM-BD51-29	0	usage_stage_1	2022-07-01	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	171	{}
267	HSM-BD51-31	0	usage_stage_1	2022-07-01	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	172	{}
268	FW-BD51-08	0	usage_stage_1	2021-07-01	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	173	{}
269	FW-BD51-09	0	usage_stage_1	2021-07-01	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	174	{}
270	SW-BD51-11	0	usage_stage_1	2017-01-01	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	175	{}
271	SW-BD51-12	0	usage_stage_1	2017-01-01	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	176	{}
272	SW-BD51-22	0	usage_stage_1	2021-07-01	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	177	{}
273	SW-BD51-23	0	usage_stage_1	2021-07-01	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	178	{}
274	SVR-M08-3132	0	usage_stage_1	2017-10-01	CMC Quận 9	MBIN & MBCA	\N	\N	S/T/U	179	{}
275	SVR-M08-2829	0	usage_stage_1	2017-10-01	CMC Quận 9	MBIN & MBCA	\N	\N	S/T/U	180	{}
276	SVR-M08-2526	0	usage_stage_1	2017-10-01	CMC Quận 9	MBIN & MBCA	\N	\N	S/T/U	181	{}
277	NAS-M08-3435	0	usage_stage_1	2022-07-01	CMC Quận 9	MBIN & MBCA	\N	\N	S/T/U	182	{}
278	FW-M08-42	0	usage_stage_1	2022-07-01	CMC Quận 9	MBIN & MBCA	\N	\N	S/T/U	183	{}
279	FW-M08-41	0	usage_stage_1	2021-07-01	CMC Quận 9	MBIN & MBCA	\N	\N	S/T/U	184	{}
280	SW-M08-38	0	usage_stage_1	2017-01-01	CMC Quận 9	MBIN & MBCA	\N	\N	S/T/U	185	{}
281	HSM-M08-37	0	usage_stage_1	2022-07-01	CMC Quận 9	MBIN & MBCA	\N	\N	S/T/U	186	{}
282	HSM-M08-2324	0	usage_stage_1	2022-07-01	CMC Quận 9	MBIN & MBCA	\N	\N	S/T/U	187	{}
283	SVR-J3-1819	0	usage_stage_1	2017-01-01	ODS	Hosting, CloudServer	\N	\N	S/T/U	188	{}
284	SVR-J3-1617	0	usage_stage_1	2017-01-01	ODS	Hosting, CloudServer	\N	\N	S/T/U	189	{}
285	SVR-J3-1314	0	usage_stage_1	2017-01-01	ODS	Hosting, CloudServer	\N	\N	S/T/U	190	{}
286	SVR-J3-1112	0	usage_stage_1	2017-01-01	ODS	Hosting, CloudServer	\N	\N	S/T/U	191	{}
287	DAS-J3-0104	0	usage_stage_1	2017-01-01	ODS	Hosting, CloudServer	\N	\N	S/T/U	192	{}
288	DAS-J3-0609	0	usage_stage_1	2017-01-01	ODS	Hosting, CloudServer	\N	\N	S/T/U	193	{}
289	SVR-J2-4244	0	usage_stage_1	2019-10-01	ODS	MBO,Email,Hosting,CloudServer,MBIN&MBCA	\N	\N	S/T/U	194	{}
290	SVR-J2-3941	0	usage_stage_1	2019-10-01	ODS	MBO,Email,Hosting,CloudServer,MBIN&MBCA	\N	\N	S/T/U	195	{}
291	SVR-J2-3537	0	usage_stage_1	2019-10-01	ODS	MBO,Email,Hosting,CloudServer,MBIN&MBCA	\N	\N	S/T/U	196	{}
292	SW-J2-46	0	usage_stage_1	2019-10-01	ODS	MBO,Email,Hosting,CloudServer,MBIN&MBCA	\N	\N	S/T/U	197	{}
293	SW-J2-45	0	usage_stage_1	2019-10-01	ODS	MBO,Email,Hosting,CloudServer,MBIN&MBCA	\N	\N	S/T/U	198	{}
294	SSD-SS-001	0	usage_stage_1	2024-06-08	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	199	{}
295	SSD-SS-002	0	usage_stage_1	2024-06-08	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	200	{}
296	SSD-SS-003	0	usage_stage_1	2024-06-08	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	201	{}
297	SSD-SS-004	0	usage_stage_1	2024-06-08	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	202	{}
298	SSD-SS-005	0	usage_stage_1	2024-06-08	VNPT Tân Thuận	MBIN & MBCA	\N	\N	S/T/U	203	{}
299	SSD-SS-006	0	usage_stage_1	2024-06-08	ODS	Cluster9	\N	\N	S/T/U	204	{}
300	SSD-SS-007	0	usage_stage_1	2024-06-08	ODS	Cluster9	\N	\N	S/T/U	205	{}
301	SSD-SS-008	0	usage_stage_1	2024-06-08	ODS	Cluster9	\N	\N	S/T/U	206	{}
302	SSD-SS-009	0	usage_stage_1	2024-06-08	ODS	Cluster9	\N	\N	S/T/U	207	{}
303	SSD-SS-010	0	usage_stage_1	2024-06-08	ODS	Cluster9	\N	\N	S/T/U	208	{}
304	SSD-SS-011	0	usage_stage_1	2024-06-08	ODS	Cluster9	\N	\N	S/T/U	209	{}
305	SVR-KHO-030	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	4	V/W/X/Y	239	{}
306	SVR-KHO-030	1	usage_stage_3	2025-12-17	Kho	Kho	\N	4	V/W/X/Y	239	{}
307	SVR-KHO-030	2	usage_stage_4	2026-10-03	ODS	Lab (OPS)	\N	4	V/W/X/Y	239	{}
308	SVR-KHO-030	3	usage_stage_5	2026-09-08	CMC	OPS Production	\N	4	V/W/X/Y	239	{}
309	SVR-KHO-031	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	4	V/W/X/Y	240	{}
310	SVR-KHO-031	1	usage_stage_3	2025-12-17	Kho	Kho	\N	4	V/W/X/Y	240	{}
311	SVR-KHO-031	2	usage_stage_4	2025-12-23	ODS	Lab (OPS)	\N	4	V/W/X/Y	240	{}
312	SVR-KHO-031	3	usage_stage_5	2026-09-08	CMC	OPS Production	\N	4	V/W/X/Y	240	{}
313	SVR-KHO-032	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	4	V/W/X/Y	241	{}
314	SVR-KHO-032	1	usage_stage_3	2025-12-17	Kho	Kho	\N	4	V/W/X/Y	241	{}
315	SVR-KHO-032	2	usage_stage_4	2026-10-03	ODS	Lab (OPS)	\N	4	V/W/X/Y	241	{}
316	SVR-KHO-032	3	usage_stage_5	2026-09-08	CMC	OPS Production	\N	4	V/W/X/Y	241	{}
317	SVR-KHO-035	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	4	V/W/X/Y	244	{}
318	SVR-KHO-035	1	usage_stage_3	2025-12-17	Kho	Kho	\N	4	V/W/X/Y	244	{}
319	SVR-KHO-035	2	usage_stage_4	2026-10-03	ODS	Lab (OPS)	\N	4	V/W/X/Y	244	{}
320	SVR-KHO-035	3	usage_stage_5	2026-09-08	CMC	OPS Production	\N	4	V/W/X/Y	244	{}
321	SVR-KHO-036	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	4	V/W/X/Y	245	{}
322	SVR-KHO-036	1	usage_stage_3	2025-12-17	Kho	Kho	\N	4	V/W/X/Y	245	{}
323	SVR-KHO-036	2	usage_stage_4	2026-10-03	ODS	Lab (OPS)	\N	4	V/W/X/Y	245	{}
324	SVR-KHO-036	3	usage_stage_5	2026-09-08	CMC	OPS Production	\N	4	V/W/X/Y	245	{}
325	SVR-KHO-037	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	4	V/W/X/Y	246	{}
326	SVR-KHO-037	1	usage_stage_3	2025-12-17	Kho	Kho	\N	4	V/W/X/Y	246	{}
327	SVR-KHO-037	2	usage_stage_4	2025-12-23	ODS	Lab (OPS)	\N	4	V/W/X/Y	246	{}
328	SVR-KHO-037	3	usage_stage_5	2026-09-08	CMC	OPS Production	\N	4	V/W/X/Y	246	{}
329	SVR-KHO-038	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	4	V/W/X/Y	247	{}
330	SVR-KHO-038	1	usage_stage_3	2025-12-17	Kho	Kho	\N	4	V/W/X/Y	247	{}
331	SVR-KHO-038	2	usage_stage_4	2025-12-23	ODS	Lab (OPS)	\N	4	V/W/X/Y	247	{}
332	SVR-KHO-038	3	usage_stage_5	2026-09-08	CMC	OPS Production	\N	4	V/W/X/Y	247	{}
333	SVR-KHO-039	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	4	V/W/X/Y	248	{}
334	SVR-KHO-039	1	usage_stage_3	2025-12-17	Kho	Kho	\N	4	V/W/X/Y	248	{}
335	SVR-KHO-039	2	usage_stage_4	2026-10-03	ODS	Lab (OPS)	\N	4	V/W/X/Y	248	{}
336	SVR-KHO-039	3	usage_stage_5	2026-09-08	CMC	OPS Production	\N	4	V/W/X/Y	248	{}
337	SW-KHO-01	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	3	V/W/X/Y	259	{}
338	SW-KHO-01	1	usage_stage_3	2025-12-17	Kho	Kho	\N	3	V/W/X/Y	259	{}
339	SW-KHO-01	2	usage_stage_4	2026-09-08	CMC	POC Openstack	\N	3	V/W/X/Y	259	{}
340	SW-KHO-02	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	3	V/W/X/Y	260	{}
341	SW-KHO-02	1	usage_stage_3	2025-12-17	Kho	Kho	\N	3	V/W/X/Y	260	{}
342	SW-KHO-02	2	usage_stage_4	2026-09-08	CMC	POC Openstack	\N	3	V/W/X/Y	260	{}
343	SVR-J2-2526	0	usage_stage_2	2025-08-01	ODS	Sangfor tạm	\N	2	V/W/X/Y	272	{}
344	SVR-J2-2526	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	272	{}
345	SVR-J2-2930	0	usage_stage_2	2025-08-01	ODS	Sangfor tạm	\N	2	V/W/X/Y	274	{}
346	SVR-J2-2930	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	274	{}
347	SVR-J2-3132	0	usage_stage_2	2025-08-01	ODS	Sangfor tạm	\N	2	V/W/X/Y	275	{}
348	SVR-J2-3132	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	275	{}
349	CAP-40-0015	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	3	V/W/X/Y	277	{}
350	CAP-40-0015	1	usage_stage_3	2025-12-17	Kho	Kho	\N	3	V/W/X/Y	277	{}
351	CAP-40-0015	2	usage_stage_4	2026-09-08	CMC	POC Openstack	\N	3	V/W/X/Y	277	{}
352	CAP-40-0016	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	3	V/W/X/Y	278	{}
353	CAP-40-0016	1	usage_stage_3	2025-12-17	Kho	Kho	\N	3	V/W/X/Y	278	{}
354	CAP-40-0016	2	usage_stage_4	2026-09-08	CMC	POC Openstack	\N	3	V/W/X/Y	278	{}
355	CAP-10-0015	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	3	V/W/X/Y	283	{}
356	CAP-10-0015	1	usage_stage_3	2025-12-17	Kho	Kho	\N	3	V/W/X/Y	283	{}
357	CAP-10-0015	2	usage_stage_4	2025-12-23	ODS	Sangfor tạm	\N	3	V/W/X/Y	283	{}
358	CAP-10-0016	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	3	V/W/X/Y	284	{}
359	CAP-10-0016	1	usage_stage_3	2025-12-17	Kho	Kho	\N	3	V/W/X/Y	284	{}
360	CAP-10-0016	2	usage_stage_4	2025-12-23	ODS	Sangfor tạm	\N	3	V/W/X/Y	284	{}
361	CAP-10-0017	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	3	V/W/X/Y	285	{}
362	CAP-10-0017	1	usage_stage_3	2025-12-17	Kho	Kho	\N	3	V/W/X/Y	285	{}
363	CAP-10-0017	2	usage_stage_4	2025-12-23	ODS	Sangfor tạm	\N	3	V/W/X/Y	285	{}
364	CAP-10-0018	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	3	V/W/X/Y	286	{}
365	CAP-10-0018	1	usage_stage_3	2025-12-17	Kho	Kho	\N	3	V/W/X/Y	286	{}
366	CAP-10-0018	2	usage_stage_4	2025-12-23	ODS	Sangfor tạm	\N	3	V/W/X/Y	286	{}
367	CAP-10-0019	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	3	V/W/X/Y	287	{}
368	CAP-10-0019	1	usage_stage_3	2025-12-17	Kho	Kho	\N	3	V/W/X/Y	287	{}
369	CAP-10-0019	2	usage_stage_4	2025-12-23	ODS	Sangfor tạm	\N	3	V/W/X/Y	287	{}
370	CAP-10-0020	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	3	V/W/X/Y	288	{}
371	CAP-10-0020	1	usage_stage_3	2025-12-17	Kho	Kho	\N	3	V/W/X/Y	288	{}
372	CAP-10-0020	2	usage_stage_4	2025-12-23	ODS	Sangfor tạm	\N	3	V/W/X/Y	288	{}
373	CAP-10-0021	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	2	V/W/X/Y	289	{}
374	CAP-10-0021	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	289	{}
375	CAP-10-0022	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	2	V/W/X/Y	290	{}
376	CAP-10-0022	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	290	{}
377	CAP-10-0023	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	2	V/W/X/Y	291	{}
378	CAP-10-0023	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	291	{}
379	CAP-10-0024	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	2	V/W/X/Y	292	{}
380	CAP-10-0024	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	292	{}
381	CAP-10-0025	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	2	V/W/X/Y	293	{}
382	CAP-10-0025	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	293	{}
383	CAP-10-0026	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	2	V/W/X/Y	294	{}
384	CAP-10-0026	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	294	{}
385	CAP-10-0027	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	2	V/W/X/Y	295	{}
386	CAP-10-0027	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	295	{}
387	CAP-10-0028	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	2	V/W/X/Y	296	{}
388	CAP-10-0028	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	296	{}
389	CAP-10-0029	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	2	V/W/X/Y	297	{}
390	CAP-10-0029	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	297	{}
391	CAP-10-0030	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	2	V/W/X/Y	298	{}
392	CAP-10-0030	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	298	{}
393	CAP-10-0031	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	2	V/W/X/Y	299	{}
394	CAP-10-0031	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	299	{}
395	CAP-10-0032	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	2	V/W/X/Y	300	{}
396	CAP-10-0032	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	300	{}
397	CAP-10-0033	0	usage_stage_2	2025-08-01	ODS	Sangfor tạm	\N	2	V/W/X/Y	301	{}
398	CAP-10-0033	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	301	{}
399	CAP-10-0034	0	usage_stage_2	2025-08-01	ODS	Sangfor tạm	\N	2	V/W/X/Y	302	{}
400	CAP-10-0034	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	302	{}
401	CAP-10-0035	0	usage_stage_2	2025-08-01	ODS	Sangfor tạm	\N	2	V/W/X/Y	303	{}
402	CAP-10-0035	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	303	{}
403	CAP-10-0036	0	usage_stage_2	2025-08-01	ODS	Sangfor tạm	\N	2	V/W/X/Y	304	{}
404	CAP-10-0036	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	304	{}
405	CAP-10-0037	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	3	V/W/X/Y	305	{}
406	CAP-10-0037	1	usage_stage_3	2025-12-17	Kho	Kho	\N	3	V/W/X/Y	305	{}
407	CAP-10-0037	2	usage_stage_4	2026-09-08	CMC	POC Openstack	\N	3	V/W/X/Y	305	{}
408	CAP-10-0038	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	3	V/W/X/Y	306	{}
409	CAP-10-0038	1	usage_stage_3	2025-12-17	Kho	Kho	\N	3	V/W/X/Y	306	{}
410	CAP-10-0038	2	usage_stage_4	2026-09-08	CMC	POC Openstack	\N	3	V/W/X/Y	306	{}
411	CAP-10-0039	0	usage_stage_2	2026-08-09	CMC	OPC Openstack	\N	1	V/W/X/Y	307	{}
412	CAP-10-0040	0	usage_stage_2	2026-08-09	CMC	OPC Openstack	\N	1	V/W/X/Y	308	{}
413	CAP-10-0041	0	usage_stage_2	2026-08-09	CMC	OPC Openstack	\N	1	V/W/X/Y	309	{}
414	CAP-10-0042	0	usage_stage_2	2026-08-09	CMC	OPC Openstack	\N	1	V/W/X/Y	310	{}
415	CAP-10-0043	0	usage_stage_2	2026-08-09	CMC	OPC Openstack	\N	1	V/W/X/Y	311	{}
416	CAP-10-0044	0	usage_stage_2	2026-08-09	CMC	OPC Openstack	\N	1	V/W/X/Y	312	{}
417	CAP-10-0045	0	usage_stage_2	2026-08-09	CMC	OPC Openstack	\N	1	V/W/X/Y	313	{}
418	CAP-10-0046	0	usage_stage_2	2026-08-09	CMC	OPC Openstack	\N	1	V/W/X/Y	314	{}
419	HDD-4TB-0001	0	usage_stage_2	2026-05-19	ODS	POC Openstack	\N	1	V/W/X/Y	388	{}
420	HDD-4TB-0002	0	usage_stage_2	2026-05-19	ODS	POC Openstack	\N	1	V/W/X/Y	389	{}
421	HDD-4TB-0003	0	usage_stage_2	2026-05-19	ODS	POC Openstack	\N	1	V/W/X/Y	390	{}
422	HDD-4TB-0004	0	usage_stage_2	2026-05-19	ODS	POC Openstack	\N	1	V/W/X/Y	391	{}
423	HDD-4TB-0005	0	usage_stage_2	2026-05-19	ODS	POC Openstack	\N	1	V/W/X/Y	392	{}
424	HDD-4TB-0006	0	usage_stage_2	2026-05-19	ODS	POC Openstack	\N	1	V/W/X/Y	393	{}
425	HDD-4TB-0007	0	usage_stage_2	2026-05-19	ODS	POC Openstack	\N	1	V/W/X/Y	394	{}
426	HDD-4TB-0008	0	usage_stage_2	2026-05-19	ODS	POC Openstack	\N	1	V/W/X/Y	395	{}
427	HDD-4TB-0009	0	usage_stage_2	2026-05-19	ODS	POC Openstack	\N	1	V/W/X/Y	396	{}
428	HDD-4TB-0010	0	usage_stage_2	2026-05-19	ODS	POC Openstack	\N	1	V/W/X/Y	397	{}
429	HDD-4TB-0011	0	usage_stage_2	2026-05-19	ODS	POC Openstack	\N	1	V/W/X/Y	398	{}
430	HDD-4TB-0012	0	usage_stage_2	2026-05-19	ODS	POC Openstack	\N	1	V/W/X/Y	399	{}
431	HDD-4TB-0013	0	usage_stage_2	2026-05-19	ODS	POC Openstack	\N	1	V/W/X/Y	400	{}
432	HDD-4TB-0014	0	usage_stage_2	2026-05-19	ODS	POC Openstack	\N	1	V/W/X/Y	401	{}
433	HDD-4TB-0015	0	usage_stage_2	2026-05-19	ODS	POC Openstack	\N	1	V/W/X/Y	402	{}
434	HDD-4TB-0016	0	usage_stage_2	2026-06-15	ODS	Backup01	\N	1	V/W/X/Y	403	{}
435	HDD-4TB-0022	0	usage_stage_2	2025-09-12	ODS	103.15.49.66	\N	1	V/W/X/Y	409	{}
436	HDD-4TB-0023	0	usage_stage_2	2025-09-12	ODS	103.15.49.66	\N	1	V/W/X/Y	410	{}
437	HDD-4TB-0024	0	usage_stage_2	2025-11-25	ODS	103.15.49.169	\N	1	V/W/X/Y	411	{}
438	HDD-4TB-0025	0	usage_stage_2	2025-07-28	ODS	DASbk2	\N	1	V/W/X/Y	412	{}
439	HDD-4TB-0026	0	usage_stage_2	2025-07-28	ODS	X114	\N	1	V/W/X/Y	413	{}
440	HDD-4TB-0027	0	usage_stage_2	2025-07-28	ODS	X114	\N	1	V/W/X/Y	414	{}
441	HDD-4TB-0028	0	usage_stage_2	2025-07-28	ODS	X114	\N	1	V/W/X/Y	415	{}
442	HDD-4TB-0029	0	usage_stage_2	2025-06-08	ODS	DASbk2	\N	1	V/W/X/Y	416	{}
443	HDD-4TB-0032	0	usage_stage_2	2025-10-29	ODS	DASbk2	\N	\N	V/W/X/Y	419	{}
444	HDD-4TB-0035	0	usage_stage_2	2025-10-01	ODS	DASbk1	\N	1	V/W/X/Y	422	{}
445	SSD-480-001	0	usage_stage_2	2025-10-22	ODS	Node 103.15.49.184	\N	1	V/W/X/Y	433	{}
446	SSD-480-002	0	usage_stage_2	2025-11-25	ODS	103.15.49.169	\N	1	V/W/X/Y	434	{}
447	SSD-240-005	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	2	V/W/X/Y	441	{}
448	SSD-240-005	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	441	{}
449	SSD-240-006	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	2	V/W/X/Y	442	{}
450	SSD-240-006	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	442	{}
451	SSD-240-007	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	2	V/W/X/Y	443	{}
452	SSD-240-007	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	443	{}
453	SSD-240-008	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	2	V/W/X/Y	444	{}
454	SSD-240-008	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	444	{}
455	SSD-240-009	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	2	V/W/X/Y	445	{}
456	SSD-240-009	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	445	{}
457	SSD-240-010	0	usage_stage_2	2025-08-01	ODS	Sangfor tạm	\N	2	V/W/X/Y	446	{}
458	SSD-240-010	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	446	{}
459	SSD-240-011	0	usage_stage_2	2025-08-01	ODS	Sangfor tạm	\N	2	V/W/X/Y	447	{}
460	SSD-240-011	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	447	{}
461	SSD-240-012	0	usage_stage_2	2025-08-01	ODS	Sangfor tạm	\N	2	V/W/X/Y	448	{}
462	SSD-240-012	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	448	{}
463	SSD-240-013	0	usage_stage_2	2026-07-30	ODS	Cluster9 - 103.15.49.220 (49.181 cũ)	\N	1	V/W/X/Y	449	{}
464	SSD-240-031	0	usage_stage_2	2026-04-28	ODS	Openstack POC	\N	1	V/W/X/Y	467	{}
465	SSD-240-040	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	2	V/W/X/Y	476	{}
466	SSD-240-040	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	476	{}
467	SSD-240-041	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	2	V/W/X/Y	477	{}
468	SSD-240-041	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	477	{}
469	SSD-240-042	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	2	V/W/X/Y	478	{}
470	SSD-240-042	1	usage_stage_3	2025-12-17	Kho	Kho	\N	2	V/W/X/Y	478	{}
471	SSD-960-007	0	usage_stage_2	2025-12-23	ODS	POC OpenStack	\N	2	V/W/X/Y	479	{history_tuple_incomplete}
472	SSD-960-007	1	usage_stage_3	2026-05-19	\N	Kho	\N	2	V/W/X/Y	479	{history_tuple_incomplete,missing_event_location}
473	SSD-960-008	0	usage_stage_2	2025-12-23	ODS	POC OpenStack	\N	2	V/W/X/Y	480	{history_tuple_incomplete}
474	SSD-960-008	1	usage_stage_3	2026-05-19	\N	Kho	\N	2	V/W/X/Y	480	{history_tuple_incomplete,missing_event_location}
475	SSD-960-009	0	usage_stage_2	2025-12-23	ODS	POC OpenStack	\N	2	V/W/X/Y	481	{history_tuple_incomplete}
476	SSD-960-009	1	usage_stage_3	2026-05-19	\N	Kho	\N	2	V/W/X/Y	481	{history_tuple_incomplete,missing_event_location}
477	SSD-960-010	0	usage_stage_2	2025-12-23	ODS	POC OpenStack	\N	2	V/W/X/Y	482	{history_tuple_incomplete}
478	SSD-960-010	1	usage_stage_3	2026-05-19	\N	Kho	\N	2	V/W/X/Y	482	{history_tuple_incomplete,missing_event_location}
479	SSD-960-011	0	usage_stage_2	2025-12-23	ODS	POC OpenStack	\N	2	V/W/X/Y	483	{history_tuple_incomplete}
480	SSD-960-011	1	usage_stage_3	2026-05-19	\N	Kho	\N	2	V/W/X/Y	483	{history_tuple_incomplete,missing_event_location}
481	SSD-960-012	0	usage_stage_2	2025-12-23	ODS	POC OpenStack	\N	2	V/W/X/Y	484	{history_tuple_incomplete}
482	SSD-960-012	1	usage_stage_3	2026-05-19	\N	Kho	\N	2	V/W/X/Y	484	{history_tuple_incomplete,missing_event_location}
483	SSD-960-013	0	usage_stage_2	2025-12-23	ODS	POC OpenStack	\N	3	V/W/X/Y	485	{history_tuple_incomplete}
484	SSD-960-013	1	usage_stage_3	2026-05-19	\N	Kho	\N	3	V/W/X/Y	485	{history_tuple_incomplete,missing_event_location}
485	SSD-960-013	2	usage_stage_4	2025-06-15	\N	Backup 03	\N	3	V/W/X/Y	485	{history_tuple_incomplete,missing_event_location}
486	SSD-960-014	0	usage_stage_2	2025-12-23	ODS	POC OpenStack	\N	1	V/W/X/Y	486	{}
487	SSD-960-015	0	usage_stage_2	2025-12-23	ODS	POC OpenStack	\N	1	V/W/X/Y	487	{}
488	SSD-960-016	0	usage_stage_2	2025-06-08	ODS	Sangfor Cloudserver	\N	1	V/W/X/Y	488	{}
489	SSD-960-017	0	usage_stage_2	2025-06-08	ODS	Sangfor Cloudserver	\N	1	V/W/X/Y	489	{}
490	SSD-960-018	0	usage_stage_2	2025-06-08	ODS	Sangfor Cloudserver	\N	1	V/W/X/Y	490	{}
491	SSD-960-019	0	usage_stage_2	2025-12-23	ODS	POC OpenStack	\N	1	V/W/X/Y	491	{}
492	SSD-960-020	0	usage_stage_2	2025-12-23	ODS	POC OpenStack	\N	1	V/W/X/Y	492	{}
493	SSD-960-021	0	usage_stage_2	2025-12-23	ODS	POC OpenStack	\N	1	V/W/X/Y	493	{}
494	SSD-960-024	0	usage_stage_2	2025-10-05	MBCA	mbca05	\N	1	V/W/X/Y	496	{}
495	SSD-960-025	0	usage_stage_2	2025-04-29	ODS	cluster930	\N	1	V/W/X/Y	497	{}
496	SSD-960-026	0	usage_stage_2	2025-04-29	ODS	cluster930	\N	1	V/W/X/Y	498	{}
497	SSD-960-027	0	usage_stage_2	2025-04-29	ODS	cluster930	\N	1	V/W/X/Y	499	{}
498	SSD-960-028	0	usage_stage_2	2025-04-29	ODS	cluster930	\N	1	V/W/X/Y	500	{}
499	SSD-960-029	0	usage_stage_2	2025-03-20	MBCA	mbca06	\N	1	V/W/X/Y	501	{}
500	SSD-960-030	0	usage_stage_2	2025-10-01	ODS	cluster930	\N	1	V/W/X/Y	502	{}
501	SSD-960-031	0	usage_stage_2	2025-10-01	ODS	cluster930	\N	1	V/W/X/Y	503	{}
502	CAP-10-0125	0	usage_stage_2	2025-12-15	Kho	Lưu trữ	\N	\N	V/W/X/Y	536	{}
503	CAP-10-0149	0	usage_stage_2	2025-12-15	Kho	Lưu trữ	\N	\N	V/W/X/Y	562	{}
504	CAP-10-0150	0	usage_stage_2	2025-12-15	Kho	Lưu trữ	\N	\N	V/W/X/Y	563	{}
505	CAP-10-0207	0	usage_stage_2	2024-10-28	\N	Sangfor tạm	\N	2	V/W/X/Y	622	{history_tuple_incomplete,missing_event_location}
506	CAP-10-0207	1	usage_stage_3	2025-12-15	\N	Cluster 9	\N	2	V/W/X/Y	622	{history_tuple_incomplete,missing_event_location}
507	CAP-10-0208	0	usage_stage_2	2024-10-28	\N	Sangfor tạm	\N	2	V/W/X/Y	623	{history_tuple_incomplete,missing_event_location}
508	CAP-10-0208	1	usage_stage_3	2025-12-15	\N	Cluster 9	\N	2	V/W/X/Y	623	{history_tuple_incomplete,missing_event_location}
509	CAP-10-0209	0	usage_stage_2	2024-10-28	\N	Sangfor tạm	\N	2	V/W/X/Y	624	{history_tuple_incomplete,missing_event_location}
510	CAP-10-0209	1	usage_stage_3	2025-12-15	\N	Cluster 9	\N	2	V/W/X/Y	624	{history_tuple_incomplete,missing_event_location}
511	CAP-10-0210	0	usage_stage_2	2024-10-28	\N	Sangfor tạm	\N	2	V/W/X/Y	625	{history_tuple_incomplete,missing_event_location}
512	CAP-10-0210	1	usage_stage_3	2025-12-15	\N	Cluster 9	\N	2	V/W/X/Y	625	{history_tuple_incomplete,missing_event_location}
513	CAP-10-0211	0	usage_stage_2	2024-10-28	\N	Sangfor tạm	\N	2	V/W/X/Y	626	{history_tuple_incomplete,missing_event_location}
514	CAP-10-0211	1	usage_stage_3	2025-12-15	\N	Cluster 9	\N	2	V/W/X/Y	626	{history_tuple_incomplete,missing_event_location}
515	CAP-10-0212	0	usage_stage_2	2024-10-28	\N	Sangfor tạm	\N	2	V/W/X/Y	627	{history_tuple_incomplete,missing_event_location}
516	CAP-10-0212	1	usage_stage_3	2025-12-15	\N	Cluster 9	\N	2	V/W/X/Y	627	{history_tuple_incomplete,missing_event_location}
517	CAP-10-0228	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	2	V/W/X/Y	645	{}
518	CAP-10-0228	1	usage_stage_3	2025-12-17	VNPT	VNPT1	\N	2	V/W/X/Y	645	{}
519	CAP-10-0229	0	usage_stage_2	2025-06-25	ODS	Sangfor tạm	\N	2	V/W/X/Y	646	{}
520	CAP-10-0229	1	usage_stage_3	2025-12-17	VNPT	VNPT1	\N	2	V/W/X/Y	646	{}
521	CAP-40-0029	0	usage_stage_2	2025-06-25	Kho	Kho	\N	2	V/W/X/Y	671	{}
522	CAP-40-0029	1	usage_stage_3	2025-12-17	VNPT	VNPT	\N	2	V/W/X/Y	671	{}
523	CAP-40-0030	0	usage_stage_2	2025-06-25	Kho	Kho	\N	2	V/W/X/Y	672	{}
524	CAP-40-0030	1	usage_stage_3	2025-12-17	VNPT	VNPT	\N	2	V/W/X/Y	672	{}
525	S6EPNC0Y506115	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	726	{}
526	S6EPNC0Y506115	1	usage_stage_2	2025-03-12	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	726	{}
527	S6EPNC0Y506116	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	727	{}
528	S6EPNC0Y506116	1	usage_stage_2	2025-03-12	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	727	{}
529	S6EPNC0Y506117	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	728	{}
530	S6EPNC0Y506117	1	usage_stage_2	2025-03-12	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	728	{}
531	S6EPNC0Y506118	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	729	{}
532	S6EPNC0Y506118	1	usage_stage_2	2025-03-12	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	729	{}
533	S6EPNC0Y506119	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	730	{}
534	S6EPNC0Y506119	1	usage_stage_2	2025-03-12	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	730	{}
535	S6EPNC0Y506121	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	731	{}
536	S6EPNC0Y506121	1	usage_stage_2	2025-03-12	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	731	{}
537	S6EPNC0Y506122	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	732	{}
538	S6EPNC0Y506122	1	usage_stage_2	2025-03-12	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	732	{}
539	S6EPNC0Y506124	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	733	{}
540	S6EPNC0Y506124	1	usage_stage_2	2025-09-12	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	733	{}
541	S6EPNC0Y506125	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	734	{}
542	S6EPNC0Y506125	1	usage_stage_2	2025-09-12	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	734	{}
543	S6EPNC0Y506126	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	735	{}
544	S6EPNC0Y506126	1	usage_stage_2	2025-09-12	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	735	{}
545	S6EPNC0Y506127	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	736	{}
546	S6EPNC0Y506127	1	usage_stage_2	2025-09-12	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	736	{}
547	S6EPNC0Y506128	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	737	{}
548	S6EPNC0Y506128	1	usage_stage_2	2025-09-12	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	737	{}
549	S6EPNC0Y506130	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	738	{}
550	S6EPNC0Y506130	1	usage_stage_2	2025-09-12	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	738	{}
551	S6EPNC0Y506131	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	739	{}
552	S6EPNC0Y506131	1	usage_stage_2	2025-09-12	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	739	{}
553	S6EPNC0Y506132	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	740	{}
554	S6EPNC0Y506132	1	usage_stage_2	2025-09-12	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	740	{}
555	S6EPNC0Y506133	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	741	{}
556	S6EPNC0Y506133	1	usage_stage_2	2025-09-12	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	741	{}
557	S6EPNC0Y506134	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	742	{}
558	S6EPNC0Y506134	1	usage_stage_2	2025-09-12	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	742	{}
559	S6EPNC0Y506135	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	743	{}
560	S6EPNC0Y506135	1	usage_stage_2	2025-09-12	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	743	{}
561	S6EPNC0Y506136	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	744	{}
562	S6EPNC0Y506136	1	usage_stage_2	2025-09-12	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	744	{}
563	S6EPNC0Y506137	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	745	{}
564	S6EPNC0Y506137	1	usage_stage_2	2025-09-12	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	745	{}
565	S6EPNC0Y506138	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	746	{}
566	S6EPNC0Y506138	1	usage_stage_2	2025-12-15	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	746	{}
567	S6EPNC0Y506139	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	747	{}
568	S6EPNC0Y506139	1	usage_stage_2	2025-12-15	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	747	{}
569	S6EPNC0Y506140	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	748	{}
570	S6EPNC0Y506140	1	usage_stage_2	2025-12-15	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	748	{}
571	S6EPNC0Y506141	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	749	{}
572	S6EPNC0Y506141	1	usage_stage_2	2025-12-15	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	749	{}
573	S6EPNC0Y506142	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	750	{}
574	S6EPNC0Y506142	1	usage_stage_2	2025-12-15	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	750	{}
575	S6EPNC0Y506143	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	751	{}
576	S6EPNC0Y506143	1	usage_stage_2	2025-12-15	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	751	{}
577	S6EPNC0Y506144	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	752	{}
578	S6EPNC0Y506144	1	usage_stage_2	2025-12-15	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	752	{}
579	S6EPNC0Y506145	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	753	{}
580	S6EPNC0Y506145	1	usage_stage_2	2025-12-15	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	753	{}
581	S6EPNC0Y506146	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	754	{}
582	S6EPNC0Y506146	1	usage_stage_2	2025-12-15	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	754	{}
583	S6EPNC0Y506147	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	755	{}
584	S6EPNC0Y506147	1	usage_stage_2	2025-12-15	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	755	{}
585	S6EPNC0Y506148	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	756	{}
586	S6EPNC0Y506148	1	usage_stage_2	2025-12-15	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	756	{}
587	S6EPNC0Y506149	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	757	{}
588	S6EPNC0Y506149	1	usage_stage_2	2025-12-15	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	757	{}
589	S6EPNC0Y506150	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	758	{}
590	S6EPNC0Y506150	1	usage_stage_2	2025-12-15	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	758	{}
591	S6EPNC0Y506151	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	759	{}
592	S6EPNC0Y506151	1	usage_stage_2	2025-12-15	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	759	{}
593	S6EPNC0Y506152	0	usage_stage_1	2025-06-25	ODS	Sangfor tạm	\N	1	S/T/U	760	{}
594	S6EPNC0Y506152	1	usage_stage_2	2025-12-15	CMC Tân Thuận	Cụm CMC	\N	1	V/W/X/Y	760	{}
595	S724NS0Y500169D	0	usage_stage_1	2025-02-10	ODS	Hosting	\N	\N	S/T/U	768	{}
596	S724NS0Y500165Y	0	usage_stage_1	2025-02-10	ODS	Hosting	\N	\N	S/T/U	769	{}
597	S724NS0Y500162W	0	usage_stage_1	2025-02-10	ODS	Hosting	\N	\N	S/T/U	770	{}
598	S724NS0Y500160A	0	usage_stage_1	2025-02-10	ODS	Hosting	\N	\N	S/T/U	771	{}
599	S724NS0Y500164X	0	usage_stage_1	2025-02-10	ODS	Hosting	\N	\N	S/T/U	772	{}
600	S724NS0Y500167M	0	usage_stage_1	2025-02-10	ODS	Hosting	\N	\N	S/T/U	773	{}
601	CAP-RAID-0001	0	usage_stage_1	2025-11-13	CMC Tân Thuận	Email	\N	\N	S/T/U	774	{}
602	CAP-RAID-0002	0	usage_stage_1	2025-11-13	CMC Tân Thuận	Email	\N	\N	S/T/U	775	{}
603	CAP-RAID-0003	0	usage_stage_1	2025-11-13	CMC Tân Thuận	Email	\N	\N	S/T/U	776	{}
604	CAP-RAID-0004	0	usage_stage_1	2025-11-13	CMC Tân Thuận	Email	\N	\N	S/T/U	777	{}
605	CAP-RAID-0005	0	usage_stage_1	2025-11-16	CMC Tân Thuận	Email	\N	\N	S/T/U	778	{}
606	CAP-RAID-0006	0	usage_stage_1	2025-11-16	CMC Tân Thuận	Email	\N	\N	S/T/U	779	{}
607	CAP-RAID-0007	0	usage_stage_1	2025-11-18	CMC Tân Thuận	Email	\N	\N	S/T/U	780	{}
608	CAP-RAID-0008	0	usage_stage_1	2025-11-18	CMC Tân Thuận	Email	\N	\N	S/T/U	781	{}
609	CAP-RAID-0009	0	usage_stage_1	2025-11-18	CMC Tân Thuận	Email	\N	\N	S/T/U	782	{}
610	CAP-RAID-0010	0	usage_stage_1	2025-11-18	CMC Tân Thuận	Email	\N	\N	S/T/U	783	{}
611	CAP-RAID-0011	0	usage_stage_1	2025-11-25	CMC Tân Thuận	Email	\N	\N	S/T/U	784	{}
612	CAP-RAID-0012	0	usage_stage_1	2025-11-25	CMC Tân Thuận	Email	\N	\N	S/T/U	785	{}
613	CAP-RAID-0013	0	usage_stage_1	2025-11-25	CMC Tân Thuận	Email	\N	\N	S/T/U	786	{}
614	CAP-RAID-0014	0	usage_stage_1	2025-11-25	CMC Tân Thuận	Email	\N	\N	S/T/U	787	{}
615	CAP-10-097	0	usage_stage_1	2026-10-03	ODS	POC Openstack	\N	1	S/T/U	788	{}
616	CAP-10-097	1	usage_stage_2	2026-08-09	Kho	\N	\N	1	V/W/X/Y	788	{history_tuple_incomplete,missing_usage_object}
617	CAP-10-098	0	usage_stage_1	2026-10-03	ODS	POC Openstack	\N	1	S/T/U	789	{}
618	CAP-10-098	1	usage_stage_2	2026-08-09	Kho	\N	\N	1	V/W/X/Y	789	{history_tuple_incomplete,missing_usage_object}
619	CAP-10-099	0	usage_stage_1	2026-10-03	ODS	POC Openstack	\N	1	S/T/U	790	{}
620	CAP-10-099	1	usage_stage_2	2026-08-09	Kho	\N	\N	1	V/W/X/Y	790	{history_tuple_incomplete,missing_usage_object}
621	CAP-10-100	0	usage_stage_1	2026-10-03	ODS	POC Openstack	\N	1	S/T/U	791	{}
622	CAP-10-100	1	usage_stage_2	2026-08-09	Kho	\N	\N	1	V/W/X/Y	791	{history_tuple_incomplete,missing_usage_object}
623	CAP-10-101	0	usage_stage_1	2026-10-03	ODS	POC Openstack	\N	1	S/T/U	792	{}
624	CAP-10-101	1	usage_stage_2	2026-08-09	Kho	\N	\N	1	V/W/X/Y	792	{history_tuple_incomplete,missing_usage_object}
625	CAP-10-102	0	usage_stage_1	2026-10-03	ODS	POC Openstack	\N	1	S/T/U	793	{}
626	CAP-10-102	1	usage_stage_2	2026-08-09	Kho	\N	\N	1	V/W/X/Y	793	{history_tuple_incomplete,missing_usage_object}
627	CAP-10-103	0	usage_stage_1	2026-10-03	ODS	POC Openstack	\N	1	S/T/U	794	{}
628	CAP-10-103	1	usage_stage_2	2026-08-09	Kho	\N	\N	1	V/W/X/Y	794	{history_tuple_incomplete,missing_usage_object}
629	CAP-10-104	0	usage_stage_1	2026-10-03	ODS	POC Openstack	\N	1	S/T/U	795	{}
630	CAP-10-104	1	usage_stage_2	2026-08-09	Kho	\N	\N	1	V/W/X/Y	795	{history_tuple_incomplete,missing_usage_object}
631	CAP-10-105	0	usage_stage_1	2026-10-03	ODS	POC Openstack	\N	\N	S/T/U	796	{}
632	CAP-10-106	0	usage_stage_1	2026-10-03	ODS	POC Openstack	\N	\N	S/T/U	797	{}
633	P605A1252A38042	0	usage_stage_1	2026-03-24	ODS	Cloudserver	\N	\N	S/T/U	798	{}
634	S6ESNS0W303693	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	799	{}
635	S6ESNS0W303693	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	799	{history_tuple_incomplete,missing_usage_object}
636	S6ESNS0W304017	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	800	{}
637	S6ESNS0W304017	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	800	{history_tuple_incomplete,missing_usage_object}
638	S6ESNS0W306991	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	801	{}
639	S6ESNS0W306991	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	801	{history_tuple_incomplete,missing_usage_object}
640	S6ESNS0W307357	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	802	{}
641	S6ESNS0W307357	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	802	{history_tuple_incomplete,missing_usage_object}
642	S6ESNS0W306996	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	803	{}
643	S6ESNS0W306996	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	803	{history_tuple_incomplete,missing_usage_object}
644	S6ESNS0W303671	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	804	{}
645	S6ESNS0W303671	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	804	{history_tuple_incomplete,missing_usage_object}
646	S6ESNS0W304005	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	805	{}
647	S6ESNS0W304005	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	805	{history_tuple_incomplete,missing_usage_object}
648	S6ESNS0W303660	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	806	{}
649	S6ESNS0W303660	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	806	{history_tuple_incomplete,missing_usage_object}
650	S6ESNS0W304034	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	807	{}
651	S6ESNS0W304034	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	807	{history_tuple_incomplete,missing_usage_object}
652	S6ESNS0W304014	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	808	{}
653	S6ESNS0W304014	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	808	{history_tuple_incomplete,missing_usage_object}
654	S11D9E957	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	813	{}
655	S11D9E957	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	813	{history_tuple_incomplete,missing_usage_object}
656	S13EE9E68	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	814	{}
657	S13EE9E68	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	814	{history_tuple_incomplete,missing_usage_object}
658	S13EE7DD2	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	815	{}
659	S13EE7DD2	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	815	{history_tuple_incomplete,missing_usage_object}
660	S12309ED5	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	816	{}
661	S12309ED5	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	816	{history_tuple_incomplete,missing_usage_object}
662	S11D9EA03	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	817	{}
663	S11D9EA03	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	817	{history_tuple_incomplete,missing_usage_object}
664	S11DC6554	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	818	{}
665	S11DC6554	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	818	{history_tuple_incomplete,missing_usage_object}
666	S124B27AA	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	819	{}
667	S124B27AA	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	819	{history_tuple_incomplete,missing_usage_object}
668	S11D9EA63	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	820	{}
669	S11D9EA63	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	820	{history_tuple_incomplete,missing_usage_object}
670	S12309F0A	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	821	{}
671	S12309F0A	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	821	{history_tuple_incomplete,missing_usage_object}
672	S13DF5A4E	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	822	{}
673	S13DF5A4E	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	822	{history_tuple_incomplete,missing_usage_object}
674	S11D9E9CF	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	823	{}
675	S11D9E9CF	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	823	{history_tuple_incomplete,missing_usage_object}
676	S11DC6441	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	824	{}
677	S11DC6441	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	824	{history_tuple_incomplete,missing_usage_object}
678	S11D9E94C	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	825	{}
679	S11D9E94C	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	825	{history_tuple_incomplete,missing_usage_object}
680	S11DC66B2	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	826	{}
681	S11DC66B2	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	826	{history_tuple_incomplete,missing_usage_object}
682	S11D9E951	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	827	{}
683	S11D9E951	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	827	{history_tuple_incomplete,missing_usage_object}
684	S13EE9A66	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	828	{}
685	S13EE9A66	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	828	{history_tuple_incomplete,missing_usage_object}
686	S11D9EA78	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	829	{}
687	S11D9EA78	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	829	{history_tuple_incomplete,missing_usage_object}
688	S120113B6	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	830	{}
689	S120113B6	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	830	{history_tuple_incomplete,missing_usage_object}
690	S11D9E958	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	831	{}
691	S11D9E958	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	831	{history_tuple_incomplete,missing_usage_object}
692	S11DC63FE	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	832	{}
693	S11DC63FE	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	832	{history_tuple_incomplete,missing_usage_object}
694	S11D9E94D	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	833	{}
695	S11D9E94D	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	833	{history_tuple_incomplete,missing_usage_object}
696	S13EF024C	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	834	{}
697	S13EF024C	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	834	{history_tuple_incomplete,missing_usage_object}
698	S13EE9E64	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	835	{}
699	S13EE9E64	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	835	{history_tuple_incomplete,missing_usage_object}
700	S11E67451	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	836	{}
701	S11E67451	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	836	{history_tuple_incomplete,missing_usage_object}
702	SOFDBC13A	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	837	{}
703	SOFDBC13A	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	837	{history_tuple_incomplete,missing_usage_object}
704	S11586B58	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	838	{}
705	S11586B58	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	838	{history_tuple_incomplete,missing_usage_object}
706	S11586B4E	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	839	{}
707	S11586B4E	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	839	{history_tuple_incomplete,missing_usage_object}
708	S11E13E30	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	840	{}
709	S11E13E30	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	840	{history_tuple_incomplete,missing_usage_object}
710	SOF7C576F	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	841	{}
711	SOF7C576F	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	841	{history_tuple_incomplete,missing_usage_object}
712	SOF7C5770	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	842	{}
713	SOF7C5770	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	842	{history_tuple_incomplete,missing_usage_object}
714	S0F7C6A87	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	843	{}
715	S0F7C6A87	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	843	{history_tuple_incomplete,missing_usage_object}
716	S1181AAA0	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	844	{}
717	S1181AAA0	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	844	{history_tuple_incomplete,missing_usage_object}
718	M6P24T1802257	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	845	{}
719	M6P24T1802257	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	845	{history_tuple_incomplete,missing_usage_object}
720	M7VF915500185	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	846	{}
721	M7VF915500185	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	846	{history_tuple_incomplete,missing_usage_object}
722	M772XT5800807	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	847	{}
723	M772XT5800807	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	847	{history_tuple_incomplete,missing_usage_object}
724	M8RU258401900	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	848	{}
725	M8RU258401900	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	848	{history_tuple_incomplete,missing_usage_object}
726	M6L68C6300519	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	849	{}
727	M6L68C6300519	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	849	{history_tuple_incomplete,missing_usage_object}
728	M7YY867501625	0	usage_stage_1	2026-05-19	ODS	POC Openstack	\N	1	S/T/U	850	{}
729	M7YY867501625	1	usage_stage_2	2026-08-09	CMC	\N	\N	1	V/W/X/Y	850	{history_tuple_incomplete,missing_usage_object}
\.


--
-- Data for Name: placement; Type: TABLE DATA; Schema: public; Owner: atlas
--

COPY public.placement (id, asset_id, rack_id, start_u, size_u, from_date, to_date) FROM stdin;
\.


--
-- Data for Name: rack; Type: TABLE DATA; Schema: public; Owner: atlas
--

COPY public.rack (id, room_id, code, height_u) FROM stdin;
\.


--
-- Data for Name: room; Type: TABLE DATA; Schema: public; Owner: atlas
--

COPY public.room (id, site_id, code, name) FROM stdin;
\.


--
-- Data for Name: site; Type: TABLE DATA; Schema: public; Owner: atlas
--

COPY public.site (id, name, kind) FROM stdin;
1	ODS	datacenter
15	CMC Tân Thuận	datacenter
32	Kho	warehouse
36	VNPT Tân Thuận	datacenter
176	CMC Quận 9	datacenter
\.


--
-- Data for Name: status_catalog; Type: TABLE DATA; Schema: public; Owner: atlas
--

COPY public.status_catalog (code, label, tag_style, attention, sort_order) FROM stdin;
in_use	Đang vận hành	live	f	1
in_use_needs_replacement	Đang dùng · cần thay	warn	t	2
in_stock	Trong kho	stock	f	3
not_in_use	Không sử dụng	idle	f	4
degraded	Suy giảm hiệu năng	repair	t	5
broken	Hỏng	repair	t	6
pending_disposal	Chờ thanh lý	warn	t	7
retired	Đã thanh lý	retired	f	8
\.


--
-- Data for Name: supplier; Type: TABLE DATA; Schema: public; Owner: atlas
--

COPY public.supplier (code, name) FROM stdin;
MB045564	Công Ty Cổ Phần Giải Pháp Máy Chủ Việt
MB2766984	CÔNG TY TNHH THƯƠNG MẠI DỊCH VỤ CÔNG NGHỆ MCSG
MB007275	Công Ty TNHH Kỹ Thuật Hạ Tầng IT
MB2197020	CÔNG TY CỔ PHẦN TƯ VẤN VÀ ĐÀO TẠO CÔNG NGHỆ THÔNG TIN VNE
MB2194010	Công Ty TNHH Kỹ Thuật Hạ Tầng IT
\.


--
-- Data for Name: user_session; Type: TABLE DATA; Schema: public; Owner: atlas
--

COPY public.user_session (token, user_id, created_at, expires_at) FROM stdin;
iuTKSymUq1AkwcwoSD8tP6tABMMO0kGf8t-jP94KeSI	2	2026-09-14 02:22:27.278362+00	2026-09-14 10:22:27.384908+00
\.


--
-- Name: app_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: atlas
--

SELECT pg_catalog.setval('public.app_user_id_seq', 3, true);


--
-- Name: asset_event_id_seq; Type: SEQUENCE SET; Schema: public; Owner: atlas
--

SELECT pg_catalog.setval('public.asset_event_id_seq', 1458, true);


--
-- Name: placement_id_seq; Type: SEQUENCE SET; Schema: public; Owner: atlas
--

SELECT pg_catalog.setval('public.placement_id_seq', 1, false);


--
-- Name: rack_id_seq; Type: SEQUENCE SET; Schema: public; Owner: atlas
--

SELECT pg_catalog.setval('public.rack_id_seq', 1, false);


--
-- Name: room_id_seq; Type: SEQUENCE SET; Schema: public; Owner: atlas
--

SELECT pg_catalog.setval('public.room_id_seq', 1, false);


--
-- Name: site_id_seq; Type: SEQUENCE SET; Schema: public; Owner: atlas
--

SELECT pg_catalog.setval('public.site_id_seq', 1697, true);


--
-- Name: app_user app_user_pkey; Type: CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_pkey PRIMARY KEY (id);


--
-- Name: app_user app_user_username_key; Type: CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_username_key UNIQUE (username);


--
-- Name: asset_event asset_event_asset_id_event_sequence_key; Type: CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.asset_event
    ADD CONSTRAINT asset_event_asset_id_event_sequence_key UNIQUE (asset_id, event_sequence);


--
-- Name: asset_event asset_event_pkey; Type: CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.asset_event
    ADD CONSTRAINT asset_event_pkey PRIMARY KEY (id);


--
-- Name: asset asset_pkey; Type: CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.asset
    ADD CONSTRAINT asset_pkey PRIMARY KEY (asset_id);


--
-- Name: placement placement_pkey; Type: CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.placement
    ADD CONSTRAINT placement_pkey PRIMARY KEY (id);


--
-- Name: rack rack_pkey; Type: CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.rack
    ADD CONSTRAINT rack_pkey PRIMARY KEY (id);


--
-- Name: rack rack_room_id_code_key; Type: CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.rack
    ADD CONSTRAINT rack_room_id_code_key UNIQUE (room_id, code);


--
-- Name: room room_pkey; Type: CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.room
    ADD CONSTRAINT room_pkey PRIMARY KEY (id);


--
-- Name: room room_site_id_code_key; Type: CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.room
    ADD CONSTRAINT room_site_id_code_key UNIQUE (site_id, code);


--
-- Name: site site_name_key; Type: CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.site
    ADD CONSTRAINT site_name_key UNIQUE (name);


--
-- Name: site site_pkey; Type: CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.site
    ADD CONSTRAINT site_pkey PRIMARY KEY (id);


--
-- Name: status_catalog status_catalog_pkey; Type: CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.status_catalog
    ADD CONSTRAINT status_catalog_pkey PRIMARY KEY (code);


--
-- Name: supplier supplier_pkey; Type: CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.supplier
    ADD CONSTRAINT supplier_pkey PRIMARY KEY (code);


--
-- Name: user_session user_session_pkey; Type: CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.user_session
    ADD CONSTRAINT user_session_pkey PRIMARY KEY (token);


--
-- Name: idx_asset_cluster; Type: INDEX; Schema: public; Owner: atlas
--

CREATE INDEX idx_asset_cluster ON public.asset USING btree (cluster);


--
-- Name: idx_asset_datacenter; Type: INDEX; Schema: public; Owner: atlas
--

CREATE INDEX idx_asset_datacenter ON public.asset USING btree (datacenter);


--
-- Name: idx_asset_flags; Type: INDEX; Schema: public; Owner: atlas
--

CREATE INDEX idx_asset_flags ON public.asset USING gin (review_flags);


--
-- Name: idx_asset_status; Type: INDEX; Schema: public; Owner: atlas
--

CREATE INDEX idx_asset_status ON public.asset USING btree (usage_status);


--
-- Name: idx_event_asset; Type: INDEX; Schema: public; Owner: atlas
--

CREATE INDEX idx_event_asset ON public.asset_event USING btree (asset_id, event_sequence);


--
-- Name: idx_session_expires; Type: INDEX; Schema: public; Owner: atlas
--

CREATE INDEX idx_session_expires ON public.user_session USING btree (expires_at);


--
-- Name: asset_event asset_event_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.asset_event
    ADD CONSTRAINT asset_event_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES public.asset(asset_id) ON DELETE CASCADE;


--
-- Name: asset asset_parent_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.asset
    ADD CONSTRAINT asset_parent_asset_id_fkey FOREIGN KEY (parent_asset_id) REFERENCES public.asset(asset_id) ON DELETE SET NULL;


--
-- Name: asset asset_rack_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.asset
    ADD CONSTRAINT asset_rack_id_fkey FOREIGN KEY (rack_id) REFERENCES public.rack(id) ON DELETE SET NULL;


--
-- Name: asset asset_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.asset
    ADD CONSTRAINT asset_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.room(id) ON DELETE SET NULL;


--
-- Name: asset asset_site_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.asset
    ADD CONSTRAINT asset_site_id_fkey FOREIGN KEY (site_id) REFERENCES public.site(id) ON DELETE SET NULL;


--
-- Name: asset asset_usage_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.asset
    ADD CONSTRAINT asset_usage_status_fkey FOREIGN KEY (usage_status) REFERENCES public.status_catalog(code);


--
-- Name: placement placement_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.placement
    ADD CONSTRAINT placement_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES public.asset(asset_id) ON DELETE CASCADE;


--
-- Name: placement placement_rack_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.placement
    ADD CONSTRAINT placement_rack_id_fkey FOREIGN KEY (rack_id) REFERENCES public.rack(id) ON DELETE CASCADE;


--
-- Name: rack rack_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.rack
    ADD CONSTRAINT rack_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.room(id) ON DELETE CASCADE;


--
-- Name: room room_site_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.room
    ADD CONSTRAINT room_site_id_fkey FOREIGN KEY (site_id) REFERENCES public.site(id) ON DELETE CASCADE;


--
-- Name: user_session user_session_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: atlas
--

ALTER TABLE ONLY public.user_session
    ADD CONSTRAINT user_session_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict 4TFuQsagra5G3S6fPc9qJokWMRjJMKTObA1ILuDKn981O91cOuqzWp1le3lT5en

