--
-- PostgreSQL database dump
--

-- Dumped from database version 14.22 (Ubuntu 14.22-0ubuntu0.22.04.1)
-- Dumped by pg_dump version 16.3

-- Started on 2026-03-12 17:59:48

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 10 (class 2615 OID 29908)
-- Name: analytics; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA analytics;


ALTER SCHEMA analytics OWNER TO postgres;

--
-- TOC entry 4745 (class 0 OID 0)
-- Dependencies: 10
-- Name: SCHEMA analytics; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA analytics IS 'Immutable event/fact history. Append-only. Denormalized snapshots. Powers analytics without touching clean.';


--
-- TOC entry 8 (class 2615 OID 29906)
-- Name: clean; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA clean;


ALTER SCHEMA clean OWNER TO postgres;

--
-- TOC entry 4746 (class 0 OID 0)
-- Dependencies: 8
-- Name: SCHEMA clean; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA clean IS 'Typed, FK-enforced single source of truth. Current state only.';


--
-- TOC entry 5 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

--
-- TOC entry 7 (class 2615 OID 29905)
-- Name: raw; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA raw;


ALTER SCHEMA raw OWNER TO postgres;

--
-- TOC entry 4748 (class 0 OID 0)
-- Dependencies: 7
-- Name: SCHEMA raw; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA raw IS 'Ingestion layer. Append-only JSONB blobs. No transforms. idempotency_key on every table.';


--
-- TOC entry 9 (class 2615 OID 29907)
-- Name: serve; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA serve;


ALTER SCHEMA serve OWNER TO postgres;

--
-- TOC entry 4749 (class 0 OID 0)
-- Dependencies: 9
-- Name: SCHEMA serve; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA serve IS 'Flat aggregated payloads. One row per entity. Drives Reverse-ETL to mobile app and dashboards.';


--
-- TOC entry 2 (class 3079 OID 29176)
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- TOC entry 4750 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- TOC entry 1096 (class 1247 OID 30234)
-- Name: achievement_type; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.achievement_type AS ENUM (
    'milestone',
    'badge',
    'streak',
    'level_up',
    'perfect_game'
);


ALTER TYPE clean.achievement_type OWNER TO postgres;

--
-- TOC entry 1312 (class 1247 OID 31710)
-- Name: campaign_channel; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.campaign_channel AS ENUM (
    'whatsapp',
    'email',
    'paid_social'
);


ALTER TYPE clean.campaign_channel OWNER TO postgres;

--
-- TOC entry 1309 (class 1247 OID 31700)
-- Name: campaign_type; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.campaign_type AS ENUM (
    'acquisition',
    'retention',
    'upsell',
    're_engagement'
);


ALTER TYPE clean.campaign_type OWNER TO postgres;

--
-- TOC entry 1018 (class 1247 OID 29920)
-- Name: cefr_level; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.cefr_level AS ENUM (
    'A1',
    'A2',
    'B1',
    'B2',
    'C1',
    'C2'
);


ALTER TYPE clean.cefr_level OWNER TO postgres;

--
-- TOC entry 1054 (class 1247 OID 30060)
-- Name: child_relationship; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.child_relationship AS ENUM (
    'son',
    'daughter',
    'stepson',
    'stepdaughter',
    'nephew',
    'niece',
    'grandson',
    'granddaughter',
    'other'
);


ALTER TYPE clean.child_relationship OWNER TO postgres;

--
-- TOC entry 1045 (class 1247 OID 30016)
-- Name: class_event_type; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.class_event_type AS ENUM (
    'created',
    'confirmed',
    'started',
    'recording_received',
    'ai_processing_started',
    'ai_processing_completed',
    'verification_submitted',
    'cancelled',
    'no_show',
    'retry_triggered',
    'error_occurred'
);


ALTER TYPE clean.class_event_type OWNER TO postgres;

--
-- TOC entry 1042 (class 1247 OID 29998)
-- Name: class_status; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.class_status AS ENUM (
    'draft',
    'confirmed',
    'in_progress',
    'completed_raw',
    'completed_ai',
    'verified',
    'cancelled',
    'no_show'
);


ALTER TYPE clean.class_status OWNER TO postgres;

--
-- TOC entry 1027 (class 1247 OID 29956)
-- Name: family_status; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.family_status AS ENUM (
    'active',
    'paused',
    'cancelled'
);


ALTER TYPE clean.family_status OWNER TO postgres;

--
-- TOC entry 1081 (class 1247 OID 30174)
-- Name: fraud_type; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.fraud_type AS ENUM (
    'duplicate_email',
    'duplicate_phone',
    'duplicate_card',
    'suspicious_pattern',
    'self_referral'
);


ALTER TYPE clean.fraud_type OWNER TO postgres;

--
-- TOC entry 1303 (class 1247 OID 31674)
-- Name: funnel_stage; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.funnel_stage AS ENUM (
    'new',
    'contacted',
    'demo_scheduled',
    'demo_done',
    'converted',
    'lost'
);


ALTER TYPE clean.funnel_stage OWNER TO postgres;

--
-- TOC entry 1093 (class 1247 OID 30222)
-- Name: game_type; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.game_type AS ENUM (
    'vocabulary',
    'grammar',
    'listening',
    'speaking',
    'reading'
);


ALTER TYPE clean.game_type OWNER TO postgres;

--
-- TOC entry 1090 (class 1247 OID 30210)
-- Name: intervention_outcome; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.intervention_outcome AS ENUM (
    'no_response',
    'engaged',
    'converted',
    'churned',
    'pending'
);


ALTER TYPE clean.intervention_outcome OWNER TO postgres;

--
-- TOC entry 1087 (class 1247 OID 30196)
-- Name: intervention_type; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.intervention_type AS ENUM (
    'whatsapp',
    'sales_call',
    'email',
    'discount_offer',
    'free_class',
    'push_notification'
);


ALTER TYPE clean.intervention_type OWNER TO postgres;

--
-- TOC entry 1306 (class 1247 OID 31688)
-- Name: lead_source; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.lead_source AS ENUM (
    'whatsapp_campaign',
    'google_ad',
    'referral',
    'organic',
    'agent_manual'
);


ALTER TYPE clean.lead_source OWNER TO postgres;

--
-- TOC entry 1063 (class 1247 OID 30106)
-- Name: learning_goal; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.learning_goal AS ENUM (
    'Business',
    'Travel',
    'Academic',
    'Casual',
    'CareerChange'
);


ALTER TYPE clean.learning_goal OWNER TO postgres;

--
-- TOC entry 1066 (class 1247 OID 30118)
-- Name: learning_style; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.learning_style AS ENUM (
    'Interactive',
    'SelfPaced',
    'Visual',
    'Auditory'
);


ALTER TYPE clean.learning_style OWNER TO postgres;

--
-- TOC entry 1261 (class 1247 OID 31341)
-- Name: llm_status; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.llm_status AS ENUM (
    'queued',
    'processing',
    'completed',
    'failed',
    'dedup_skipped'
);


ALTER TYPE clean.llm_status OWNER TO postgres;

--
-- TOC entry 1039 (class 1247 OID 29992)
-- Name: member_role; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.member_role AS ENUM (
    'owner',
    'child'
);


ALTER TYPE clean.member_role OWNER TO postgres;

--
-- TOC entry 1057 (class 1247 OID 30080)
-- Name: mod_reason; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.mod_reason AS ENUM (
    'parent_request',
    'payment_failure',
    'upgrade',
    'downgrade',
    'custom_pricing',
    'other'
);


ALTER TYPE clean.mod_reason OWNER TO postgres;

--
-- TOC entry 1060 (class 1247 OID 30094)
-- Name: mod_status; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.mod_status AS ENUM (
    'pending',
    'approved',
    'rejected',
    'completed',
    'failed'
);


ALTER TYPE clean.mod_status OWNER TO postgres;

--
-- TOC entry 1099 (class 1247 OID 30246)
-- Name: notification_channel; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.notification_channel AS ENUM (
    'whatsapp',
    'push',
    'email',
    'sms'
);


ALTER TYPE clean.notification_channel OWNER TO postgres;

--
-- TOC entry 1021 (class 1247 OID 29934)
-- Name: onboarding_step; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.onboarding_step AS ENUM (
    'registered',
    'questionnaire_done',
    'teacher_assigned',
    'first_class_done',
    'active'
);


ALTER TYPE clean.onboarding_step OWNER TO postgres;

--
-- TOC entry 1072 (class 1247 OID 30140)
-- Name: payout_status; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.payout_status AS ENUM (
    'pending',
    'processing',
    'completed',
    'failed'
);


ALTER TYPE clean.payout_status OWNER TO postgres;

--
-- TOC entry 1069 (class 1247 OID 30128)
-- Name: payslip_status; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.payslip_status AS ENUM (
    'draft',
    'approved',
    'paid',
    'disputed',
    'cancelled'
);


ALTER TYPE clean.payslip_status OWNER TO postgres;

--
-- TOC entry 1033 (class 1247 OID 29976)
-- Name: plan_type; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.plan_type AS ENUM (
    'solo',
    'family'
);


ALTER TYPE clean.plan_type OWNER TO postgres;

--
-- TOC entry 1075 (class 1247 OID 30150)
-- Name: referral_status; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.referral_status AS ENUM (
    'pending',
    'clicked',
    'converted',
    'expired',
    'rejected'
);


ALTER TYPE clean.referral_status OWNER TO postgres;

--
-- TOC entry 1078 (class 1247 OID 30162)
-- Name: reward_status; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.reward_status AS ENUM (
    'pending',
    'applied',
    'paid',
    'expired',
    'cancelled'
);


ALTER TYPE clean.reward_status OWNER TO postgres;

--
-- TOC entry 1084 (class 1247 OID 30186)
-- Name: risk_level; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.risk_level AS ENUM (
    'low',
    'medium',
    'high',
    'critical'
);


ALTER TYPE clean.risk_level OWNER TO postgres;

--
-- TOC entry 1036 (class 1247 OID 29982)
-- Name: sub_frequency; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.sub_frequency AS ENUM (
    'monthly',
    'quarterly',
    'yearly',
    'custom'
);


ALTER TYPE clean.sub_frequency OWNER TO postgres;

--
-- TOC entry 1030 (class 1247 OID 29964)
-- Name: subscription_status; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.subscription_status AS ENUM (
    'pending',
    'active',
    'paused',
    'expired',
    'cancelled'
);


ALTER TYPE clean.subscription_status OWNER TO postgres;

--
-- TOC entry 1024 (class 1247 OID 29946)
-- Name: teacher_status; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.teacher_status AS ENUM (
    'pending_review',
    'active',
    'suspended',
    'inactive'
);


ALTER TYPE clean.teacher_status OWNER TO postgres;

--
-- TOC entry 1300 (class 1247 OID 31663)
-- Name: touchpoint_type; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.touchpoint_type AS ENUM (
    'post_class_feedback',
    'milestone',
    'communication_sent',
    'issue_reported',
    'teacher_observation'
);


ALTER TYPE clean.touchpoint_type OWNER TO postgres;

--
-- TOC entry 1051 (class 1247 OID 30054)
-- Name: txn_context; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.txn_context AS ENUM (
    'solo',
    'family'
);


ALTER TYPE clean.txn_context OWNER TO postgres;

--
-- TOC entry 1048 (class 1247 OID 30040)
-- Name: txn_status; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.txn_status AS ENUM (
    'initiated',
    'pending',
    'success',
    'failed',
    'refunded',
    'disputed'
);


ALTER TYPE clean.txn_status OWNER TO postgres;

--
-- TOC entry 1015 (class 1247 OID 29910)
-- Name: user_status; Type: TYPE; Schema: clean; Owner: postgres
--

CREATE TYPE clean.user_status AS ENUM (
    'pending',
    'active',
    'inactive',
    'suspended'
);


ALTER TYPE clean.user_status OWNER TO postgres;

--
-- TOC entry 405 (class 1255 OID 98275)
-- Name: fn_intake_dedup(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_intake_dedup() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_existing_id   BIGINT;
    v_existing_req  CHAR(36);
BEGIN
    -- 1. Dedup by idempotency_key (skip if NULL/blank)
    IF NEW.idempotency_key IS NOT NULL AND trim(NEW.idempotency_key) != '' THEN
        SELECT id, request_id
          INTO v_existing_id, v_existing_req
          FROM llm_intake_queue
         WHERE idempotency_key = NEW.idempotency_key
           AND status NOT IN ('REPEAT', 'CANCELLED', 'DISABLED', 'FAILED')
         ORDER BY created_at DESC
         LIMIT 1;

        IF FOUND THEN
            NEW.status     := 'REPEAT';
            NEW.request_id := v_existing_req;
            NEW.error      := format('duplicate idempotency_key (original intake id=%s)', v_existing_id);
            RETURN NEW;
        END IF;
    END IF;

    -- 2. Dedup by audio_url — catches re-submissions with no/different idempotency_key
    SELECT id, request_id
      INTO v_existing_id, v_existing_req
      FROM llm_intake_queue
     WHERE audio_url = NEW.audio_url
       AND status NOT IN ('REPEAT', 'CANCELLED', 'DISABLED', 'FAILED')
     ORDER BY created_at DESC
     LIMIT 1;

    IF FOUND THEN
        NEW.status     := 'REPEAT';
        NEW.request_id := v_existing_req;
        NEW.error      := format('duplicate audio_url (original intake id=%s)', v_existing_id);
        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_intake_dedup() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 339 (class 1259 OID 31760)
-- Name: campaigns; Type: TABLE; Schema: analytics; Owner: postgres
--

CREATE TABLE analytics.campaigns (
    campaign_id integer NOT NULL,
    name text NOT NULL,
    channel clean.campaign_channel NOT NULL,
    campaign_type clean.campaign_type NOT NULL,
    launched_at timestamp with time zone,
    target_segment jsonb,
    messages_sent integer DEFAULT 0 NOT NULL,
    replies_received integer DEFAULT 0 NOT NULL,
    conversions integer DEFAULT 0 NOT NULL,
    cost_ils numeric(10,2) DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE analytics.campaigns OWNER TO postgres;

--
-- TOC entry 4751 (class 0 OID 0)
-- Dependencies: 339
-- Name: TABLE campaigns; Type: COMMENT; Schema: analytics; Owner: postgres
--

COMMENT ON TABLE analytics.campaigns IS 'EVT-15 | Marketing attribution. target_segment JSONB records who was targeted and why. JOIN → leads → students → subscriptions for full campaign ROI.';


--
-- TOC entry 338 (class 1259 OID 31759)
-- Name: campaigns_campaign_id_seq; Type: SEQUENCE; Schema: analytics; Owner: postgres
--

CREATE SEQUENCE analytics.campaigns_campaign_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE analytics.campaigns_campaign_id_seq OWNER TO postgres;

--
-- TOC entry 4752 (class 0 OID 0)
-- Dependencies: 338
-- Name: campaigns_campaign_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: postgres
--

ALTER SEQUENCE analytics.campaigns_campaign_id_seq OWNED BY analytics.campaigns.campaign_id;


--
-- TOC entry 293 (class 1259 OID 31228)
-- Name: class_facts; Type: TABLE; Schema: analytics; Owner: postgres
--

CREATE TABLE analytics.class_facts (
    event_id bigint NOT NULL,
    event_type text DEFAULT 'class_completed'::text NOT NULL,
    class_id integer NOT NULL,
    student_id integer NOT NULL,
    student_email text NOT NULL,
    teacher_id integer NOT NULL,
    teacher_name text NOT NULL,
    meeting_start timestamp with time zone NOT NULL,
    duration_mins integer,
    cefr_level_before clean.cefr_level,
    cefr_level_after clean.cefr_level,
    fluency_score numeric(5,2),
    vocabulary_score numeric(5,2),
    grammar_score numeric(5,2),
    topics_verified integer,
    points_awarded integer,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE analytics.class_facts OWNER TO postgres;

--
-- TOC entry 4753 (class 0 OID 0)
-- Dependencies: 293
-- Name: TABLE class_facts; Type: COMMENT; Schema: analytics; Owner: postgres
--

COMMENT ON TABLE analytics.class_facts IS 'EVT-02 | Immutable. One row per completed+verified class. Denormalized snapshot. Analytics never need joins.';


--
-- TOC entry 292 (class 1259 OID 31227)
-- Name: class_facts_event_id_seq; Type: SEQUENCE; Schema: analytics; Owner: postgres
--

CREATE SEQUENCE analytics.class_facts_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE analytics.class_facts_event_id_seq OWNER TO postgres;

--
-- TOC entry 4754 (class 0 OID 0)
-- Dependencies: 292
-- Name: class_facts_event_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: postgres
--

ALTER SEQUENCE analytics.class_facts_event_id_seq OWNED BY analytics.class_facts.event_id;


--
-- TOC entry 299 (class 1259 OID 31266)
-- Name: gamification_facts; Type: TABLE; Schema: analytics; Owner: postgres
--

CREATE TABLE analytics.gamification_facts (
    event_id bigint NOT NULL,
    event_type text NOT NULL,
    student_id integer NOT NULL,
    student_email text NOT NULL,
    points integer,
    source_type text,
    achievement_title text,
    streak_day integer,
    league text,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE analytics.gamification_facts OWNER TO postgres;

--
-- TOC entry 4755 (class 0 OID 0)
-- Dependencies: 299
-- Name: TABLE gamification_facts; Type: COMMENT; Schema: analytics; Owner: postgres
--

COMMENT ON TABLE analytics.gamification_facts IS 'EVT-05 | Immutable. Every gamification event. Powers engagement funnel dashboards.';


--
-- TOC entry 298 (class 1259 OID 31265)
-- Name: gamification_facts_event_id_seq; Type: SEQUENCE; Schema: analytics; Owner: postgres
--

CREATE SEQUENCE analytics.gamification_facts_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE analytics.gamification_facts_event_id_seq OWNER TO postgres;

--
-- TOC entry 4756 (class 0 OID 0)
-- Dependencies: 298
-- Name: gamification_facts_event_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: postgres
--

ALTER SEQUENCE analytics.gamification_facts_event_id_seq OWNED BY analytics.gamification_facts.event_id;


--
-- TOC entry 309 (class 1259 OID 31327)
-- Name: intervention_facts; Type: TABLE; Schema: analytics; Owner: postgres
--

CREATE TABLE analytics.intervention_facts (
    event_id bigint NOT NULL,
    event_type text NOT NULL,
    intervention_id integer NOT NULL,
    student_id integer NOT NULL,
    student_email text NOT NULL,
    intervention_type clean.intervention_type NOT NULL,
    risk_score_at_time numeric(4,3),
    outcome clean.intervention_outcome,
    days_to_outcome integer,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE analytics.intervention_facts OWNER TO postgres;

--
-- TOC entry 4757 (class 0 OID 0)
-- Dependencies: 309
-- Name: TABLE intervention_facts; Type: COMMENT; Schema: analytics; Owner: postgres
--

COMMENT ON TABLE analytics.intervention_facts IS 'EVT-10 | Immutable. Measures whether interventions work. Compare risk_score_at_time vs final outcome.';


--
-- TOC entry 308 (class 1259 OID 31326)
-- Name: intervention_facts_event_id_seq; Type: SEQUENCE; Schema: analytics; Owner: postgres
--

CREATE SEQUENCE analytics.intervention_facts_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE analytics.intervention_facts_event_id_seq OWNER TO postgres;

--
-- TOC entry 4758 (class 0 OID 0)
-- Dependencies: 308
-- Name: intervention_facts_event_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: postgres
--

ALTER SEQUENCE analytics.intervention_facts_event_id_seq OWNED BY analytics.intervention_facts.event_id;


--
-- TOC entry 341 (class 1259 OID 31777)
-- Name: leads; Type: TABLE; Schema: analytics; Owner: postgres
--

CREATE TABLE analytics.leads (
    lead_id bigint NOT NULL,
    phone text,
    email text,
    name text NOT NULL,
    source clean.lead_source NOT NULL,
    campaign_id integer,
    assigned_agent_id integer,
    funnel_stage clean.funnel_stage DEFAULT 'new'::clean.funnel_stage NOT NULL,
    converted_student_id integer,
    lost_reason text,
    first_contact_at timestamp with time zone,
    converted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE analytics.leads OWNER TO postgres;

--
-- TOC entry 4759 (class 0 OID 0)
-- Dependencies: 341
-- Name: TABLE leads; Type: COMMENT; Schema: analytics; Owner: postgres
--

COMMENT ON TABLE analytics.leads IS 'EVT-14 | Sales funnel. Group by assigned_agent_id for leaderboard. Group by funnel_stage for drop-off. JOIN → clean.students → subscriptions → payment_transactions for CAC vs LTV.';


--
-- TOC entry 340 (class 1259 OID 31776)
-- Name: leads_lead_id_seq; Type: SEQUENCE; Schema: analytics; Owner: postgres
--

CREATE SEQUENCE analytics.leads_lead_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE analytics.leads_lead_id_seq OWNER TO postgres;

--
-- TOC entry 4760 (class 0 OID 0)
-- Dependencies: 340
-- Name: leads_lead_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: postgres
--

ALTER SEQUENCE analytics.leads_lead_id_seq OWNED BY analytics.leads.lead_id;


--
-- TOC entry 331 (class 1259 OID 31525)
-- Name: llm_facts; Type: TABLE; Schema: analytics; Owner: postgres
--

CREATE TABLE analytics.llm_facts (
    event_id bigint NOT NULL,
    event_type text DEFAULT 'ai_evaluation_completed'::text NOT NULL,
    class_id integer NOT NULL,
    student_id integer NOT NULL,
    student_email text NOT NULL,
    teacher_id integer NOT NULL,
    zoom_meeting_id text NOT NULL,
    model_used text,
    cefr_level text,
    vocabulary_score numeric(5,2),
    grammar_score numeric(5,2),
    fluency_score numeric(5,2),
    engagement_level text,
    weakest_skill text,
    tokens_used integer,
    cost_usd numeric(10,6),
    latency_ms integer,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE analytics.llm_facts OWNER TO postgres;

--
-- TOC entry 4761 (class 0 OID 0)
-- Dependencies: 331
-- Name: TABLE llm_facts; Type: COMMENT; Schema: analytics; Owner: postgres
--

COMMENT ON TABLE analytics.llm_facts IS 'EVT-11 | Immutable. One row per AI evaluation. Denormalized snapshot. Enables cohort language progress charts and cost-per-lesson analytics without joins.';


--
-- TOC entry 330 (class 1259 OID 31524)
-- Name: llm_facts_event_id_seq; Type: SEQUENCE; Schema: analytics; Owner: postgres
--

CREATE SEQUENCE analytics.llm_facts_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE analytics.llm_facts_event_id_seq OWNER TO postgres;

--
-- TOC entry 4762 (class 0 OID 0)
-- Dependencies: 330
-- Name: llm_facts_event_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: postgres
--

ALTER SEQUENCE analytics.llm_facts_event_id_seq OWNED BY analytics.llm_facts.event_id;


--
-- TOC entry 295 (class 1259 OID 31241)
-- Name: payment_facts; Type: TABLE; Schema: analytics; Owner: postgres
--

CREATE TABLE analytics.payment_facts (
    event_id bigint NOT NULL,
    event_type text NOT NULL,
    txn_id integer NOT NULL,
    student_id integer NOT NULL,
    student_email text NOT NULL,
    transaction_context text NOT NULL,
    family_id integer,
    amount_ils numeric(10,2) NOT NULL,
    currency character varying(5) NOT NULL,
    is_recurring boolean NOT NULL,
    plan_name text,
    mrr_impact numeric(10,2),
    occurred_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE analytics.payment_facts OWNER TO postgres;

--
-- TOC entry 4763 (class 0 OID 0)
-- Dependencies: 295
-- Name: TABLE payment_facts; Type: COMMENT; Schema: analytics; Owner: postgres
--

COMMENT ON TABLE analytics.payment_facts IS 'EVT-03 | Immutable. Every payment event with mrr_impact for revenue time-series.';


--
-- TOC entry 294 (class 1259 OID 31240)
-- Name: payment_facts_event_id_seq; Type: SEQUENCE; Schema: analytics; Owner: postgres
--

CREATE SEQUENCE analytics.payment_facts_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE analytics.payment_facts_event_id_seq OWNER TO postgres;

--
-- TOC entry 4764 (class 0 OID 0)
-- Dependencies: 294
-- Name: payment_facts_event_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: postgres
--

ALTER SEQUENCE analytics.payment_facts_event_id_seq OWNED BY analytics.payment_facts.event_id;


--
-- TOC entry 303 (class 1259 OID 31290)
-- Name: referral_facts; Type: TABLE; Schema: analytics; Owner: postgres
--

CREATE TABLE analytics.referral_facts (
    event_id bigint NOT NULL,
    event_type text NOT NULL,
    referral_id integer NOT NULL,
    referrer_id integer NOT NULL,
    referrer_email text NOT NULL,
    referee_id integer,
    referee_email text,
    reward_amount numeric(10,2),
    channel text,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE analytics.referral_facts OWNER TO postgres;

--
-- TOC entry 4765 (class 0 OID 0)
-- Dependencies: 303
-- Name: TABLE referral_facts; Type: COMMENT; Schema: analytics; Owner: postgres
--

COMMENT ON TABLE analytics.referral_facts IS 'EVT-07 | Immutable. Full referral funnel from share to conversion to reward.';


--
-- TOC entry 302 (class 1259 OID 31289)
-- Name: referral_facts_event_id_seq; Type: SEQUENCE; Schema: analytics; Owner: postgres
--

CREATE SEQUENCE analytics.referral_facts_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE analytics.referral_facts_event_id_seq OWNER TO postgres;

--
-- TOC entry 4766 (class 0 OID 0)
-- Dependencies: 302
-- Name: referral_facts_event_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: postgres
--

ALTER SEQUENCE analytics.referral_facts_event_id_seq OWNED BY analytics.referral_facts.event_id;


--
-- TOC entry 307 (class 1259 OID 31314)
-- Name: risk_facts; Type: TABLE; Schema: analytics; Owner: postgres
--

CREATE TABLE analytics.risk_facts (
    event_id bigint NOT NULL,
    event_type text DEFAULT 'risk_assessed'::text NOT NULL,
    student_id integer NOT NULL,
    student_email text NOT NULL,
    risk_score numeric(4,3) NOT NULL,
    risk_level clean.risk_level NOT NULL,
    contributing_factors jsonb,
    days_inactive integer,
    classes_missed integer,
    model_version text,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE analytics.risk_facts OWNER TO postgres;

--
-- TOC entry 4767 (class 0 OID 0)
-- Dependencies: 307
-- Name: TABLE risk_facts; Type: COMMENT; Schema: analytics; Owner: postgres
--

COMMENT ON TABLE analytics.risk_facts IS 'EVT-09 | Immutable. Append-only risk score history. Enables week-over-week churn trend charts.';


--
-- TOC entry 306 (class 1259 OID 31313)
-- Name: risk_facts_event_id_seq; Type: SEQUENCE; Schema: analytics; Owner: postgres
--

CREATE SEQUENCE analytics.risk_facts_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE analytics.risk_facts_event_id_seq OWNER TO postgres;

--
-- TOC entry 4768 (class 0 OID 0)
-- Dependencies: 306
-- Name: risk_facts_event_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: postgres
--

ALTER SEQUENCE analytics.risk_facts_event_id_seq OWNED BY analytics.risk_facts.event_id;


--
-- TOC entry 291 (class 1259 OID 31216)
-- Name: student_lifecycle; Type: TABLE; Schema: analytics; Owner: postgres
--

CREATE TABLE analytics.student_lifecycle (
    event_id bigint NOT NULL,
    event_type text NOT NULL,
    student_id integer NOT NULL,
    student_email text NOT NULL,
    from_state text,
    to_state text,
    cefr_level_at_event clean.cefr_level,
    metadata jsonb,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE analytics.student_lifecycle OWNER TO postgres;

--
-- TOC entry 4769 (class 0 OID 0)
-- Dependencies: 291
-- Name: TABLE student_lifecycle; Type: COMMENT; Schema: analytics; Owner: postgres
--

COMMENT ON TABLE analytics.student_lifecycle IS 'EVT-01 | Immutable. Every student state change. Enables cohort and funnel analysis.';


--
-- TOC entry 290 (class 1259 OID 31215)
-- Name: student_lifecycle_event_id_seq; Type: SEQUENCE; Schema: analytics; Owner: postgres
--

CREATE SEQUENCE analytics.student_lifecycle_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE analytics.student_lifecycle_event_id_seq OWNER TO postgres;

--
-- TOC entry 4770 (class 0 OID 0)
-- Dependencies: 290
-- Name: student_lifecycle_event_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: postgres
--

ALTER SEQUENCE analytics.student_lifecycle_event_id_seq OWNED BY analytics.student_lifecycle.event_id;


--
-- TOC entry 335 (class 1259 OID 31731)
-- Name: student_touchpoints; Type: TABLE; Schema: analytics; Owner: postgres
--

CREATE TABLE analytics.student_touchpoints (
    event_id bigint NOT NULL,
    student_id integer NOT NULL,
    student_email text NOT NULL,
    class_id integer,
    type clean.touchpoint_type NOT NULL,
    sentiment_score numeric(3,2),
    payload jsonb NOT NULL,
    created_by text NOT NULL,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE analytics.student_touchpoints OWNER TO postgres;

--
-- TOC entry 4771 (class 0 OID 0)
-- Dependencies: 335
-- Name: TABLE student_touchpoints; Type: COMMENT; Schema: analytics; Owner: postgres
--

COMMENT ON TABLE analytics.student_touchpoints IS 'EVT-12 | Immutable. Product team primary table. Slice by type=post_class_feedback + sentiment trend. Cross-join with teacher_observations to find early churn signals.';


--
-- TOC entry 334 (class 1259 OID 31730)
-- Name: student_touchpoints_event_id_seq; Type: SEQUENCE; Schema: analytics; Owner: postgres
--

CREATE SEQUENCE analytics.student_touchpoints_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE analytics.student_touchpoints_event_id_seq OWNER TO postgres;

--
-- TOC entry 4772 (class 0 OID 0)
-- Dependencies: 334
-- Name: student_touchpoints_event_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: postgres
--

ALTER SEQUENCE analytics.student_touchpoints_event_id_seq OWNED BY analytics.student_touchpoints.event_id;


--
-- TOC entry 297 (class 1259 OID 31254)
-- Name: subscription_facts; Type: TABLE; Schema: analytics; Owner: postgres
--

CREATE TABLE analytics.subscription_facts (
    event_id bigint NOT NULL,
    event_type text NOT NULL,
    subscription_id integer NOT NULL,
    student_id integer NOT NULL,
    student_email text NOT NULL,
    plan_type text NOT NULL,
    plan_name text NOT NULL,
    from_status text,
    to_status text NOT NULL,
    amount_ils numeric(10,2),
    classes_per_month integer,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE analytics.subscription_facts OWNER TO postgres;

--
-- TOC entry 4773 (class 0 OID 0)
-- Dependencies: 297
-- Name: TABLE subscription_facts; Type: COMMENT; Schema: analytics; Owner: postgres
--

COMMENT ON TABLE analytics.subscription_facts IS 'EVT-04 | Immutable. Every subscription state change. Drives MRR movement analysis.';


--
-- TOC entry 296 (class 1259 OID 31253)
-- Name: subscription_facts_event_id_seq; Type: SEQUENCE; Schema: analytics; Owner: postgres
--

CREATE SEQUENCE analytics.subscription_facts_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE analytics.subscription_facts_event_id_seq OWNER TO postgres;

--
-- TOC entry 4774 (class 0 OID 0)
-- Dependencies: 296
-- Name: subscription_facts_event_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: postgres
--

ALTER SEQUENCE analytics.subscription_facts_event_id_seq OWNED BY analytics.subscription_facts.event_id;


--
-- TOC entry 305 (class 1259 OID 31302)
-- Name: teacher_facts; Type: TABLE; Schema: analytics; Owner: postgres
--

CREATE TABLE analytics.teacher_facts (
    event_id bigint NOT NULL,
    event_type text NOT NULL,
    teacher_id integer NOT NULL,
    teacher_email text NOT NULL,
    class_id integer,
    amount_ils numeric(10,2),
    rating numeric(3,2),
    from_status text,
    to_status text,
    metadata jsonb,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE analytics.teacher_facts OWNER TO postgres;

--
-- TOC entry 4775 (class 0 OID 0)
-- Dependencies: 305
-- Name: TABLE teacher_facts; Type: COMMENT; Schema: analytics; Owner: postgres
--

COMMENT ON TABLE analytics.teacher_facts IS 'EVT-08 | Immutable. All teacher-side analytics in one place for performance and compensation analytics.';


--
-- TOC entry 304 (class 1259 OID 31301)
-- Name: teacher_facts_event_id_seq; Type: SEQUENCE; Schema: analytics; Owner: postgres
--

CREATE SEQUENCE analytics.teacher_facts_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE analytics.teacher_facts_event_id_seq OWNER TO postgres;

--
-- TOC entry 4776 (class 0 OID 0)
-- Dependencies: 304
-- Name: teacher_facts_event_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: postgres
--

ALTER SEQUENCE analytics.teacher_facts_event_id_seq OWNED BY analytics.teacher_facts.event_id;


--
-- TOC entry 337 (class 1259 OID 31745)
-- Name: teacher_observations; Type: TABLE; Schema: analytics; Owner: postgres
--

CREATE TABLE analytics.teacher_observations (
    observation_id bigint NOT NULL,
    class_id integer NOT NULL,
    teacher_id integer NOT NULL,
    teacher_email text NOT NULL,
    student_id integer NOT NULL,
    student_email text NOT NULL,
    struggle_areas text[],
    strengths text[],
    engagement_level smallint,
    notes text,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT teacher_observations_engagement_level_check CHECK (((engagement_level >= 1) AND (engagement_level <= 5)))
);


ALTER TABLE analytics.teacher_observations OWNER TO postgres;

--
-- TOC entry 4777 (class 0 OID 0)
-- Dependencies: 337
-- Name: TABLE teacher_observations; Type: COMMENT; Schema: analytics; Owner: postgres
--

COMMENT ON TABLE analytics.teacher_observations IS 'EVT-13 | Immutable. Teacher structured notes per class. Feeds lesson planning.';


--
-- TOC entry 336 (class 1259 OID 31744)
-- Name: teacher_observations_observation_id_seq; Type: SEQUENCE; Schema: analytics; Owner: postgres
--

CREATE SEQUENCE analytics.teacher_observations_observation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE analytics.teacher_observations_observation_id_seq OWNER TO postgres;

--
-- TOC entry 4778 (class 0 OID 0)
-- Dependencies: 336
-- Name: teacher_observations_observation_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: postgres
--

ALTER SEQUENCE analytics.teacher_observations_observation_id_seq OWNED BY analytics.teacher_observations.observation_id;


--
-- TOC entry 301 (class 1259 OID 31278)
-- Name: vocabulary_facts; Type: TABLE; Schema: analytics; Owner: postgres
--

CREATE TABLE analytics.vocabulary_facts (
    event_id bigint NOT NULL,
    event_type text DEFAULT 'word_practiced'::text NOT NULL,
    student_id integer NOT NULL,
    word_id integer NOT NULL,
    word text NOT NULL,
    list_name text,
    was_correct boolean NOT NULL,
    accuracy_at_event numeric(5,2),
    practice_count_at_event integer,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE analytics.vocabulary_facts OWNER TO postgres;

--
-- TOC entry 4779 (class 0 OID 0)
-- Dependencies: 301
-- Name: TABLE vocabulary_facts; Type: COMMENT; Schema: analytics; Owner: postgres
--

COMMENT ON TABLE analytics.vocabulary_facts IS 'EVT-06 | Immutable. Every word practice event. Enables vocabulary retention curve analysis.';


--
-- TOC entry 300 (class 1259 OID 31277)
-- Name: vocabulary_facts_event_id_seq; Type: SEQUENCE; Schema: analytics; Owner: postgres
--

CREATE SEQUENCE analytics.vocabulary_facts_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE analytics.vocabulary_facts_event_id_seq OWNER TO postgres;

--
-- TOC entry 4780 (class 0 OID 0)
-- Dependencies: 300
-- Name: vocabulary_facts_event_id_seq; Type: SEQUENCE OWNED BY; Schema: analytics; Owner: postgres
--

ALTER SEQUENCE analytics.vocabulary_facts_event_id_seq OWNED BY analytics.vocabulary_facts.event_id;


--
-- TOC entry 256 (class 1259 OID 30755)
-- Name: achievements; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.achievements (
    achievement_id integer NOT NULL,
    student_id integer NOT NULL,
    achievement_type clean.achievement_type NOT NULL,
    title text NOT NULL,
    description text,
    points_awarded integer DEFAULT 0 NOT NULL,
    metadata jsonb,
    earned_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.achievements OWNER TO postgres;

--
-- TOC entry 4781 (class 0 OID 0)
-- Dependencies: 256
-- Name: TABLE achievements; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.achievements IS 'CLN-20 | FK → CLN-01. Badges, milestones, streaks. Points awarded also logged in CLN-21.';


--
-- TOC entry 255 (class 1259 OID 30754)
-- Name: achievements_achievement_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.achievements_achievement_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.achievements_achievement_id_seq OWNER TO postgres;

--
-- TOC entry 4782 (class 0 OID 0)
-- Dependencies: 255
-- Name: achievements_achievement_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.achievements_achievement_id_seq OWNED BY clean.achievements.achievement_id;


--
-- TOC entry 248 (class 1259 OID 30680)
-- Name: app_sessions; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.app_sessions (
    session_id bigint NOT NULL,
    student_id integer NOT NULL,
    device_type text,
    platform text,
    app_version text,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    ended_at timestamp with time zone,
    duration_secs integer,
    screens_visited jsonb
);


ALTER TABLE clean.app_sessions OWNER TO postgres;

--
-- TOC entry 4783 (class 0 OID 0)
-- Dependencies: 248
-- Name: TABLE app_sessions; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.app_sessions IS 'CLN-16 | FK → CLN-01. Session-level engagement. Critical for churn prediction features.';


--
-- TOC entry 247 (class 1259 OID 30679)
-- Name: app_sessions_session_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.app_sessions_session_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.app_sessions_session_id_seq OWNER TO postgres;

--
-- TOC entry 4784 (class 0 OID 0)
-- Dependencies: 247
-- Name: app_sessions_session_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.app_sessions_session_id_seq OWNED BY clean.app_sessions.session_id;


--
-- TOC entry 274 (class 1259 OID 30980)
-- Name: churn_risk_scores; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.churn_risk_scores (
    score_id integer NOT NULL,
    student_id integer NOT NULL,
    risk_score numeric(4,3) NOT NULL,
    risk_level clean.risk_level NOT NULL,
    contributing_factors jsonb,
    model_version text,
    assessed_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT churn_risk_scores_risk_score_check CHECK (((risk_score >= (0)::numeric) AND (risk_score <= (1)::numeric)))
);


ALTER TABLE clean.churn_risk_scores OWNER TO postgres;

--
-- TOC entry 4785 (class 0 OID 0)
-- Dependencies: 274
-- Name: TABLE churn_risk_scores; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.churn_risk_scores IS 'CLN-29 | FK → CLN-01. Append-only score history. Enables week-over-week risk trend analysis.';


--
-- TOC entry 273 (class 1259 OID 30979)
-- Name: churn_risk_scores_score_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.churn_risk_scores_score_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.churn_risk_scores_score_id_seq OWNER TO postgres;

--
-- TOC entry 4786 (class 0 OID 0)
-- Dependencies: 273
-- Name: churn_risk_scores_score_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.churn_risk_scores_score_id_seq OWNED BY clean.churn_risk_scores.score_id;


--
-- TOC entry 243 (class 1259 OID 30617)
-- Name: class_analytics; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.class_analytics (
    event_id bigint NOT NULL,
    class_id integer NOT NULL,
    event_type clean.class_event_type NOT NULL,
    triggered_by_user_id integer,
    triggered_by_system text,
    metadata jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.class_analytics OWNER TO postgres;

--
-- TOC entry 4787 (class 0 OID 0)
-- Dependencies: 243
-- Name: TABLE class_analytics; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.class_analytics IS 'CLN-13 | FK → CLN-12. Audit backbone. Written BEFORE every state transition. Reconciliation cron compares vs lifecycle_status.';


--
-- TOC entry 242 (class 1259 OID 30616)
-- Name: class_analytics_event_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.class_analytics_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.class_analytics_event_id_seq OWNER TO postgres;

--
-- TOC entry 4788 (class 0 OID 0)
-- Dependencies: 242
-- Name: class_analytics_event_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.class_analytics_event_id_seq OWNED BY clean.class_analytics.event_id;


--
-- TOC entry 241 (class 1259 OID 30578)
-- Name: classes; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.classes (
    class_id integer NOT NULL,
    idempotency_key text NOT NULL,
    student_id integer NOT NULL,
    teacher_id integer NOT NULL,
    subscription_id integer,
    meeting_start timestamp with time zone NOT NULL,
    meeting_end timestamp with time zone,
    lifecycle_status clean.class_status DEFAULT 'draft'::clean.class_status NOT NULL,
    zoom_meeting_uuid text,
    zoom_recording_url text,
    zoom_recording_id text,
    zoom_audio_url text,
    recording_completed_at timestamp with time zone,
    cancellation_reason text,
    cancelled_by integer,
    cancelled_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    join_url text,
    admin_url text
);


ALTER TABLE clean.classes OWNER TO postgres;

--
-- TOC entry 4789 (class 0 OID 0)
-- Dependencies: 241
-- Name: TABLE classes; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.classes IS 'CLN-12 | FK → CLN-01, CLN-02, CLN-09. 7-state lifecycle_status. UNIQUE(teacher_id, meeting_start) pranalytics double-booking.';


--
-- TOC entry 246 (class 1259 OID 30663)
-- Name: daily_activity; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.daily_activity (
    student_id integer NOT NULL,
    activity_date date NOT NULL,
    xp_earned integer DEFAULT 0 NOT NULL,
    lessons_completed integer DEFAULT 0 NOT NULL,
    games_played integer DEFAULT 0 NOT NULL,
    streak_day integer DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.daily_activity OWNER TO postgres;

--
-- TOC entry 4790 (class 0 OID 0)
-- Dependencies: 246
-- Name: TABLE daily_activity; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.daily_activity IS 'CLN-15 | FK → CLN-01. Daily rollup per student. For session-level granularity use CLN-16.';


--
-- TOC entry 233 (class 1259 OID 30440)
-- Name: families; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.families (
    family_id integer NOT NULL,
    parent_student_id integer NOT NULL,
    family_status clean.family_status DEFAULT 'active'::clean.family_status NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.families OWNER TO postgres;

--
-- TOC entry 4791 (class 0 OID 0)
-- Dependencies: 233
-- Name: TABLE families; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.families IS 'CLN-07 | FK → CLN-01. Family account header. Parent is a real student.';


--
-- TOC entry 232 (class 1259 OID 30439)
-- Name: families_family_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.families_family_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.families_family_id_seq OWNER TO postgres;

--
-- TOC entry 4792 (class 0 OID 0)
-- Dependencies: 232
-- Name: families_family_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.families_family_id_seq OWNED BY clean.families.family_id;


--
-- TOC entry 235 (class 1259 OID 30459)
-- Name: family_children; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.family_children (
    child_id integer NOT NULL,
    family_id integer NOT NULL,
    student_id integer NOT NULL,
    child_name text NOT NULL,
    child_age integer NOT NULL,
    child_email text,
    relationship_to_parent clean.child_relationship DEFAULT 'son'::clean.child_relationship NOT NULL,
    payplus_subscription_id text,
    subscription_type clean.sub_frequency,
    duration_months integer,
    monthly_amount numeric(8,2),
    custom_amount numeric(8,2),
    status clean.subscription_status DEFAULT 'pending'::clean.subscription_status NOT NULL,
    subscription_start_date date,
    next_payment_date date,
    last_payment_date date,
    child_notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.family_children OWNER TO postgres;

--
-- TOC entry 4793 (class 0 OID 0)
-- Dependencies: 235
-- Name: TABLE family_children; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.family_children IS 'CLN-08 | FK → CLN-07, CLN-01. Child has own student account (student_id). Holds per-child billing details.';


--
-- TOC entry 234 (class 1259 OID 30458)
-- Name: family_children_child_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.family_children_child_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.family_children_child_id_seq OWNER TO postgres;

--
-- TOC entry 4794 (class 0 OID 0)
-- Dependencies: 234
-- Name: family_children_child_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.family_children_child_id_seq OWNED BY clean.family_children.child_id;


--
-- TOC entry 254 (class 1259 OID 30731)
-- Name: game_sessions; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.game_sessions (
    session_id integer NOT NULL,
    game_id integer NOT NULL,
    student_id integer NOT NULL,
    score integer DEFAULT 0 NOT NULL,
    score_percentage numeric(5,2),
    completed boolean DEFAULT false NOT NULL,
    time_taken_secs integer,
    answers_payload jsonb,
    played_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.game_sessions OWNER TO postgres;

--
-- TOC entry 4795 (class 0 OID 0)
-- Dependencies: 254
-- Name: TABLE game_sessions; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.game_sessions IS 'CLN-19 | FK → CLN-18, CLN-01. Individual play record. score drives CLN-21 points_ledger insert.';


--
-- TOC entry 253 (class 1259 OID 30730)
-- Name: game_sessions_session_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.game_sessions_session_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.game_sessions_session_id_seq OWNER TO postgres;

--
-- TOC entry 4796 (class 0 OID 0)
-- Dependencies: 253
-- Name: game_sessions_session_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.game_sessions_session_id_seq OWNED BY clean.game_sessions.session_id;


--
-- TOC entry 252 (class 1259 OID 30714)
-- Name: games; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.games (
    game_id integer NOT NULL,
    student_id integer NOT NULL,
    game_type clean.game_type NOT NULL,
    difficulty_level clean.cefr_level,
    content jsonb NOT NULL,
    max_points integer DEFAULT 100 NOT NULL,
    time_limit_secs integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.games OWNER TO postgres;

--
-- TOC entry 4797 (class 0 OID 0)
-- Dependencies: 252
-- Name: TABLE games; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.games IS 'CLN-18 | FK → CLN-01. AI-generated game definition. Content stored as JSONB (questions, options, answers).';


--
-- TOC entry 251 (class 1259 OID 30713)
-- Name: games_game_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.games_game_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.games_game_id_seq OWNER TO postgres;

--
-- TOC entry 4798 (class 0 OID 0)
-- Dependencies: 251
-- Name: games_game_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.games_game_id_seq OWNED BY clean.games.game_id;


--
-- TOC entry 245 (class 1259 OID 30639)
-- Name: lesson_attempts; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.lesson_attempts (
    attempt_id bigint NOT NULL,
    class_id integer NOT NULL,
    student_id integer NOT NULL,
    score_percentage numeric(5,2),
    vocabulary_score numeric(5,2),
    grammar_score numeric(5,2),
    fluency_score numeric(5,2),
    cefr_detected clean.cefr_level,
    confidence_score numeric(5,2),
    mistakes_payload jsonb,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.lesson_attempts OWNER TO postgres;

--
-- TOC entry 4799 (class 0 OID 0)
-- Dependencies: 245
-- Name: TABLE lesson_attempts; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.lesson_attempts IS 'CLN-14 | FK → CLN-12, CLN-01. One AI analysis per class (UNIQUE class_id). Gate: class cannot reach verified without this record.';


--
-- TOC entry 244 (class 1259 OID 30638)
-- Name: lesson_attempts_attempt_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.lesson_attempts_attempt_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.lesson_attempts_attempt_id_seq OWNER TO postgres;

--
-- TOC entry 4800 (class 0 OID 0)
-- Dependencies: 244
-- Name: lesson_attempts_attempt_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.lesson_attempts_attempt_id_seq OWNED BY clean.lesson_attempts.attempt_id;


--
-- TOC entry 325 (class 1259 OID 31454)
-- Name: llm_lesson_analyses; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.llm_lesson_analyses (
    analysis_id bigint NOT NULL,
    zoom_meeting_id text NOT NULL,
    class_id integer,
    student_id integer,
    job_id text,
    model_used text,
    cefr_level clean.cefr_level,
    vocabulary_score numeric(5,2),
    grammar_score numeric(5,2),
    fluency_score numeric(5,2),
    engagement_level text,
    summary text,
    grammar_feedback text,
    vocabulary_feedback text,
    pronunciation_feedback text,
    general_comment text,
    vocabulary_words jsonb,
    grammar_points jsonb,
    topics jsonb,
    status clean.llm_status DEFAULT 'queued'::clean.llm_status NOT NULL,
    processed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.llm_lesson_analyses OWNER TO postgres;

--
-- TOC entry 4801 (class 0 OID 0)
-- Dependencies: 325
-- Name: TABLE llm_lesson_analyses; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.llm_lesson_analyses IS 'CLN-35 | FK → CLN-01, CLN-12. Unpacked from raw.llm_audio_analyses. Real MySQL columns: vocabulary_score, grammar_score, fluency_score, vocabulary_words, grammar_points.';


--
-- TOC entry 324 (class 1259 OID 31453)
-- Name: llm_lesson_analyses_analysis_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.llm_lesson_analyses_analysis_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.llm_lesson_analyses_analysis_id_seq OWNER TO postgres;

--
-- TOC entry 4802 (class 0 OID 0)
-- Dependencies: 324
-- Name: llm_lesson_analyses_analysis_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.llm_lesson_analyses_analysis_id_seq OWNED BY clean.llm_lesson_analyses.analysis_id;


--
-- TOC entry 326 (class 1259 OID 31480)
-- Name: llm_model_usage_daily; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.llm_model_usage_daily (
    metric_date date NOT NULL,
    model text NOT NULL,
    total_requests integer DEFAULT 0 NOT NULL,
    failed_requests integer DEFAULT 0 NOT NULL,
    total_tokens_prompt bigint DEFAULT 0 NOT NULL,
    total_tokens_completion bigint DEFAULT 0 NOT NULL,
    total_cost_usd numeric(10,4) DEFAULT 0 NOT NULL,
    avg_latency_ms numeric(8,2),
    avg_total_ms numeric(8,2),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.llm_model_usage_daily OWNER TO postgres;

--
-- TOC entry 4803 (class 0 OID 0)
-- Dependencies: 326
-- Name: TABLE llm_model_usage_daily; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.llm_model_usage_daily IS 'CLN-36 | Daily LLM cost and performance aggregation. Derived from raw.llm_request_attempts real columns: latency_ms, tokens_prompt, tokens_completion, cost_estimate.';


--
-- TOC entry 328 (class 1259 OID 31495)
-- Name: llm_system_health; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.llm_system_health (
    health_id bigint NOT NULL,
    component text NOT NULL,
    last_heartbeat timestamp with time zone,
    last_job_at timestamp with time zone,
    last_error_at timestamp with time zone,
    last_error text,
    jobs_processed integer DEFAULT 0 NOT NULL,
    jobs_failed integer DEFAULT 0 NOT NULL,
    queue_depth integer DEFAULT 0 NOT NULL,
    circuit_breaker text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.llm_system_health OWNER TO postgres;

--
-- TOC entry 4804 (class 0 OID 0)
-- Dependencies: 328
-- Name: TABLE llm_system_health; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.llm_system_health IS 'CLN-37 | Source: MySQL llm_system_health (11 rows). Live pipeline heartbeat. circuit_breaker open = pipeline paused.';


--
-- TOC entry 327 (class 1259 OID 31494)
-- Name: llm_system_health_health_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.llm_system_health_health_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.llm_system_health_health_id_seq OWNER TO postgres;

--
-- TOC entry 4805 (class 0 OID 0)
-- Dependencies: 327
-- Name: llm_system_health_health_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.llm_system_health_health_id_seq OWNED BY clean.llm_system_health.health_id;


--
-- TOC entry 250 (class 1259 OID 30696)
-- Name: notifications_log; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.notifications_log (
    notification_id bigint NOT NULL,
    student_id integer NOT NULL,
    channel clean.notification_channel NOT NULL,
    template_name text,
    content_preview text,
    sent_at timestamp with time zone DEFAULT now() NOT NULL,
    delivered_at timestamp with time zone,
    opened_at timestamp with time zone,
    clicked_at timestamp with time zone,
    failed boolean DEFAULT false NOT NULL,
    failure_reason text,
    metadata jsonb
);


ALTER TABLE clean.notifications_log OWNER TO postgres;

--
-- TOC entry 4806 (class 0 OID 0)
-- Dependencies: 250
-- Name: TABLE notifications_log; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.notifications_log IS 'CLN-17 | FK → CLN-01. Record of all Aisensy WhatsApp, push, email, SMS messages sent.';


--
-- TOC entry 249 (class 1259 OID 30695)
-- Name: notifications_log_notification_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.notifications_log_notification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.notifications_log_notification_id_seq OWNER TO postgres;

--
-- TOC entry 4807 (class 0 OID 0)
-- Dependencies: 249
-- Name: notifications_log_notification_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.notifications_log_notification_id_seq OWNED BY clean.notifications_log.notification_id;


--
-- TOC entry 266 (class 1259 OID 30854)
-- Name: payment_transactions; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.payment_transactions (
    txn_id integer NOT NULL,
    idempotency_key text NOT NULL,
    student_id integer NOT NULL,
    subscription_id integer,
    transaction_context clean.txn_context DEFAULT 'solo'::clean.txn_context NOT NULL,
    family_id integer,
    child_id integer,
    amount numeric(10,2) NOT NULL,
    currency character varying(5) DEFAULT 'ILS'::character varying NOT NULL,
    payment_type clean.sub_frequency,
    is_recurring boolean DEFAULT false NOT NULL,
    status clean.txn_status DEFAULT 'initiated'::clean.txn_status NOT NULL,
    payplus_transaction_uid text,
    payplus_page_request_uid text,
    payplus_raw_response jsonb,
    refund_amount numeric(10,2),
    refund_type text,
    refund_reason text,
    refunded_at timestamp with time zone,
    failure_reason text,
    failure_count integer DEFAULT 0 NOT NULL,
    generated_by integer,
    processed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.payment_transactions OWNER TO postgres;

--
-- TOC entry 4808 (class 0 OID 0)
-- Dependencies: 266
-- Name: TABLE payment_transactions; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.payment_transactions IS 'CLN-25 | FK → CLN-01, CLN-09, CLN-07, CLN-08. SINGLE unified payment ledger. transaction_context (solo/family) eliminates need for UNION in MRR queries.';


--
-- TOC entry 265 (class 1259 OID 30853)
-- Name: payment_transactions_txn_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.payment_transactions_txn_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.payment_transactions_txn_id_seq OWNER TO postgres;

--
-- TOC entry 4809 (class 0 OID 0)
-- Dependencies: 265
-- Name: payment_transactions_txn_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.payment_transactions_txn_id_seq OWNED BY clean.payment_transactions.txn_id;


--
-- TOC entry 258 (class 1259 OID 30773)
-- Name: points_ledger; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.points_ledger (
    ledger_id bigint NOT NULL,
    student_id integer NOT NULL,
    points integer NOT NULL,
    source_type text NOT NULL,
    source_id integer,
    description text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.points_ledger OWNER TO postgres;

--
-- TOC entry 4810 (class 0 OID 0)
-- Dependencies: 258
-- Name: TABLE points_ledger; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.points_ledger IS 'CLN-21 | FK → CLN-01. Immutable audit trail for every XP transaction. total_xp in students is derived from this.';


--
-- TOC entry 257 (class 1259 OID 30772)
-- Name: points_ledger_ledger_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.points_ledger_ledger_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.points_ledger_ledger_id_seq OWNER TO postgres;

--
-- TOC entry 4811 (class 0 OID 0)
-- Dependencies: 257
-- Name: points_ledger_ledger_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.points_ledger_ledger_id_seq OWNED BY clean.points_ledger.ledger_id;


--
-- TOC entry 225 (class 1259 OID 30356)
-- Name: questionnaire_responses; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.questionnaire_responses (
    response_id integer NOT NULL,
    student_id integer NOT NULL,
    idempotency_key text NOT NULL,
    learning_goals text,
    preferred_style clean.learning_style,
    availability jsonb,
    current_level clean.cefr_level,
    additional_info text,
    version integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.questionnaire_responses OWNER TO postgres;

--
-- TOC entry 4812 (class 0 OID 0)
-- Dependencies: 225
-- Name: TABLE questionnaire_responses; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.questionnaire_responses IS 'CLN-03 | FK → CLN-01. Student onboarding questionnaire. idempotency pranalytics double-submit.';


--
-- TOC entry 224 (class 1259 OID 30355)
-- Name: questionnaire_responses_response_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.questionnaire_responses_response_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.questionnaire_responses_response_id_seq OWNER TO postgres;

--
-- TOC entry 4813 (class 0 OID 0)
-- Dependencies: 224
-- Name: questionnaire_responses_response_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.questionnaire_responses_response_id_seq OWNED BY clean.questionnaire_responses.response_id;


--
-- TOC entry 278 (class 1259 OID 31026)
-- Name: referral_config; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.referral_config (
    config_id integer NOT NULL,
    config_key text NOT NULL,
    config_value jsonb NOT NULL,
    description text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.referral_config OWNER TO postgres;

--
-- TOC entry 4814 (class 0 OID 0)
-- Dependencies: 278
-- Name: TABLE referral_config; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.referral_config IS 'CLN-31 | No FK. Key/value config: reward amounts, expiry days, max referrals per user.';


--
-- TOC entry 277 (class 1259 OID 31025)
-- Name: referral_config_config_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.referral_config_config_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.referral_config_config_id_seq OWNER TO postgres;

--
-- TOC entry 4815 (class 0 OID 0)
-- Dependencies: 277
-- Name: referral_config_config_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.referral_config_config_id_seq OWNED BY clean.referral_config.config_id;


--
-- TOC entry 284 (class 1259 OID 31096)
-- Name: referral_fraud_logs; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.referral_fraud_logs (
    fraud_id integer NOT NULL,
    referral_id integer,
    referrer_id integer NOT NULL,
    referee_id integer NOT NULL,
    fraud_type clean.fraud_type NOT NULL,
    fraud_score numeric(5,2) DEFAULT 0 NOT NULL,
    details jsonb,
    is_blocked boolean DEFAULT false NOT NULL,
    reviewed_by integer,
    reviewed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.referral_fraud_logs OWNER TO postgres;

--
-- TOC entry 4816 (class 0 OID 0)
-- Dependencies: 284
-- Name: TABLE referral_fraud_logs; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.referral_fraud_logs IS 'CLN-34 | FK → CLN-32, CLN-01 x3. fraud_score is NUMERIC(5,2) not INT for precision.';


--
-- TOC entry 283 (class 1259 OID 31095)
-- Name: referral_fraud_logs_fraud_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.referral_fraud_logs_fraud_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.referral_fraud_logs_fraud_id_seq OWNER TO postgres;

--
-- TOC entry 4817 (class 0 OID 0)
-- Dependencies: 283
-- Name: referral_fraud_logs_fraud_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.referral_fraud_logs_fraud_id_seq OWNED BY clean.referral_fraud_logs.fraud_id;


--
-- TOC entry 282 (class 1259 OID 31067)
-- Name: referral_rewards; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.referral_rewards (
    reward_id integer NOT NULL,
    referral_id integer NOT NULL,
    student_id integer NOT NULL,
    reward_type text NOT NULL,
    amount numeric(10,2),
    currency character varying(5) DEFAULT 'ILS'::character varying,
    txn_id integer,
    status clean.reward_status DEFAULT 'pending'::clean.reward_status NOT NULL,
    issued_at timestamp with time zone DEFAULT now() NOT NULL,
    applied_at timestamp with time zone,
    expires_at timestamp with time zone
);


ALTER TABLE clean.referral_rewards OWNER TO postgres;

--
-- TOC entry 4818 (class 0 OID 0)
-- Dependencies: 282
-- Name: TABLE referral_rewards; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.referral_rewards IS 'CLN-33 | FK → CLN-32, CLN-01, CLN-25. Reward linked to payment_transaction to confirm it was actually applied.';


--
-- TOC entry 281 (class 1259 OID 31066)
-- Name: referral_rewards_reward_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.referral_rewards_reward_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.referral_rewards_reward_id_seq OWNER TO postgres;

--
-- TOC entry 4819 (class 0 OID 0)
-- Dependencies: 281
-- Name: referral_rewards_reward_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.referral_rewards_reward_id_seq OWNED BY clean.referral_rewards.reward_id;


--
-- TOC entry 280 (class 1259 OID 31038)
-- Name: referrals; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.referrals (
    referral_id integer NOT NULL,
    idempotency_key text NOT NULL,
    referrer_id integer NOT NULL,
    referee_id integer,
    referral_code text NOT NULL,
    source_channel text,
    status clean.referral_status DEFAULT 'pending'::clean.referral_status NOT NULL,
    converted_at timestamp with time zone,
    expires_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.referrals OWNER TO postgres;

--
-- TOC entry 4820 (class 0 OID 0)
-- Dependencies: 280
-- Name: TABLE referrals; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.referrals IS 'CLN-32 | FK → CLN-01 (referrer), CLN-01 (referee). idempotency_key pranalytics duplicate submissions.';


--
-- TOC entry 279 (class 1259 OID 31037)
-- Name: referrals_referral_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.referrals_referral_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.referrals_referral_id_seq OWNER TO postgres;

--
-- TOC entry 4821 (class 0 OID 0)
-- Dependencies: 279
-- Name: referrals_referral_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.referrals_referral_id_seq OWNED BY clean.referrals.referral_id;


--
-- TOC entry 276 (class 1259 OID 30998)
-- Name: retention_interventions; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.retention_interventions (
    intervention_id integer NOT NULL,
    student_id integer NOT NULL,
    risk_score_id integer,
    intervention_type clean.intervention_type NOT NULL,
    triggered_by text NOT NULL,
    assigned_to integer,
    notes text,
    outcome clean.intervention_outcome DEFAULT 'pending'::clean.intervention_outcome NOT NULL,
    actioned_at timestamp with time zone DEFAULT now() NOT NULL,
    resolved_at timestamp with time zone
);


ALTER TABLE clean.retention_interventions OWNER TO postgres;

--
-- TOC entry 4822 (class 0 OID 0)
-- Dependencies: 276
-- Name: TABLE retention_interventions; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.retention_interventions IS 'CLN-30 | FK → CLN-01, CLN-29. Closes the loop: risk score → intervention → outcome. Measures intervention effectiveness.';


--
-- TOC entry 275 (class 1259 OID 30997)
-- Name: retention_interventions_intervention_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.retention_interventions_intervention_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.retention_interventions_intervention_id_seq OWNER TO postgres;

--
-- TOC entry 4823 (class 0 OID 0)
-- Dependencies: 275
-- Name: retention_interventions_intervention_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.retention_interventions_intervention_id_seq OWNED BY clean.retention_interventions.intervention_id;


--
-- TOC entry 333 (class 1259 OID 31718)
-- Name: sales_agents; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.sales_agents (
    agent_id integer NOT NULL,
    name text NOT NULL,
    email text NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.sales_agents OWNER TO postgres;

--
-- TOC entry 4824 (class 0 OID 0)
-- Dependencies: 333
-- Name: TABLE sales_agents; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.sales_agents IS 'CLN-38 | Sales agents micro-table. FK target for analytics.leads.assigned_agent_id.';


--
-- TOC entry 332 (class 1259 OID 31717)
-- Name: sales_agents_agent_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.sales_agents_agent_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.sales_agents_agent_id_seq OWNER TO postgres;

--
-- TOC entry 4825 (class 0 OID 0)
-- Dependencies: 332
-- Name: sales_agents_agent_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.sales_agents_agent_id_seq OWNED BY clean.sales_agents.agent_id;


--
-- TOC entry 222 (class 1259 OID 30315)
-- Name: students; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.students (
    student_id integer NOT NULL,
    email text NOT NULL,
    full_name text NOT NULL,
    mobile text,
    country_code text,
    timezone text DEFAULT 'UTC'::text NOT NULL,
    native_language character varying(10),
    learning_goal clean.learning_goal,
    preferred_style clean.learning_style,
    cefr_level clean.cefr_level DEFAULT 'A1'::clean.cefr_level NOT NULL,
    onboarding_step clean.onboarding_step DEFAULT 'registered'::clean.onboarding_step NOT NULL,
    status clean.user_status DEFAULT 'pending'::clean.user_status NOT NULL,
    total_classes integer DEFAULT 0 NOT NULL,
    total_xp integer DEFAULT 0 NOT NULL,
    last_active_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.students OWNER TO postgres;

--
-- TOC entry 4826 (class 0 OID 0)
-- Dependencies: 222
-- Name: TABLE students; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.students IS 'Typed student entity. ENUMs for status at app layer.';


--
-- TOC entry 238 (class 1259 OID 30518)
-- Name: subscription_members; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.subscription_members (
    subscription_id integer NOT NULL,
    student_id integer NOT NULL,
    family_id integer,
    role clean.member_role DEFAULT 'owner'::clean.member_role NOT NULL,
    status clean.subscription_status DEFAULT 'active'::clean.subscription_status NOT NULL,
    joined_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.subscription_members OWNER TO postgres;

--
-- TOC entry 4827 (class 0 OID 0)
-- Dependencies: 238
-- Name: TABLE subscription_members; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.subscription_members IS 'CLN-10 | FK → CLN-09, CLN-01, CLN-07. Bridge: student ↔ subscription. Family cancellation auto-resolves all child access.';


--
-- TOC entry 240 (class 1259 OID 30545)
-- Name: subscription_modifications; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.subscription_modifications (
    mod_id integer NOT NULL,
    subscription_id integer NOT NULL,
    child_id integer,
    old_plan clean.sub_frequency,
    new_plan clean.sub_frequency,
    old_amount numeric(8,2),
    new_amount numeric(8,2),
    reason clean.mod_reason NOT NULL,
    requested_by integer,
    processed_by integer,
    effective_date date NOT NULL,
    notes text,
    payplus_mod_id text,
    status clean.mod_status DEFAULT 'pending'::clean.mod_status NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.subscription_modifications OWNER TO postgres;

--
-- TOC entry 4828 (class 0 OID 0)
-- Dependencies: 240
-- Name: TABLE subscription_modifications; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.subscription_modifications IS 'CLN-11 | FK → CLN-09, CLN-08. Audit trail for plan changes.';


--
-- TOC entry 239 (class 1259 OID 30544)
-- Name: subscription_modifications_mod_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.subscription_modifications_mod_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.subscription_modifications_mod_id_seq OWNER TO postgres;

--
-- TOC entry 4829 (class 0 OID 0)
-- Dependencies: 239
-- Name: subscription_modifications_mod_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.subscription_modifications_mod_id_seq OWNED BY clean.subscription_modifications.mod_id;


--
-- TOC entry 237 (class 1259 OID 30488)
-- Name: subscriptions; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.subscriptions (
    subscription_id integer NOT NULL,
    idempotency_key text NOT NULL,
    owner_student_id integer NOT NULL,
    plan_type clean.plan_type DEFAULT 'solo'::clean.plan_type NOT NULL,
    plan_name text NOT NULL,
    classes_per_month integer NOT NULL,
    classes_remaining integer NOT NULL,
    amount_ils numeric(10,2) NOT NULL,
    currency character varying(5) DEFAULT 'ILS'::character varying NOT NULL,
    billing_frequency clean.sub_frequency DEFAULT 'monthly'::clean.sub_frequency NOT NULL,
    billing_cycle_start date NOT NULL,
    billing_cycle_end date NOT NULL,
    next_billing_date date,
    status clean.subscription_status DEFAULT 'pending'::clean.subscription_status NOT NULL,
    payplus_subscription_id text,
    managed_by_id integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_classes_remaining CHECK ((classes_remaining >= 0))
);


ALTER TABLE clean.subscriptions OWNER TO postgres;

--
-- TOC entry 4830 (class 0 OID 0)
-- Dependencies: 237
-- Name: TABLE subscriptions; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.subscriptions IS 'CLN-09 | FK → CLN-01. Subscription contract. classes_remaining >= 0 enforced by constraint.';


--
-- TOC entry 236 (class 1259 OID 30487)
-- Name: subscriptions_subscription_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.subscriptions_subscription_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.subscriptions_subscription_id_seq OWNER TO postgres;

--
-- TOC entry 4831 (class 0 OID 0)
-- Dependencies: 236
-- Name: subscriptions_subscription_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.subscriptions_subscription_id_seq OWNED BY clean.subscriptions.subscription_id;


--
-- TOC entry 229 (class 1259 OID 30397)
-- Name: teacher_availability; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.teacher_availability (
    availability_id integer NOT NULL,
    teacher_id integer NOT NULL,
    day_of_week smallint NOT NULL,
    start_time time without time zone NOT NULL,
    end_time time without time zone NOT NULL,
    timezone text DEFAULT 'UTC'::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_availability_times CHECK ((end_time > start_time)),
    CONSTRAINT teacher_availability_day_of_week_check CHECK (((day_of_week >= 0) AND (day_of_week <= 6)))
);


ALTER TABLE clean.teacher_availability OWNER TO postgres;

--
-- TOC entry 4832 (class 0 OID 0)
-- Dependencies: 229
-- Name: TABLE teacher_availability; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.teacher_availability IS 'CLN-05 | FK → CLN-02. Recurring weekly slots. UNIQUE pranalytics duplicate slots.';


--
-- TOC entry 228 (class 1259 OID 30396)
-- Name: teacher_availability_availability_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.teacher_availability_availability_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.teacher_availability_availability_id_seq OWNER TO postgres;

--
-- TOC entry 4833 (class 0 OID 0)
-- Dependencies: 228
-- Name: teacher_availability_availability_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.teacher_availability_availability_id_seq OWNED BY clean.teacher_availability.availability_id;


--
-- TOC entry 268 (class 1259 OID 30903)
-- Name: teacher_earning_analytics; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.teacher_earning_analytics (
    earning_id bigint NOT NULL,
    teacher_id integer NOT NULL,
    class_id integer,
    source_type text NOT NULL,
    amount_ils numeric(10,2) NOT NULL,
    description text,
    earned_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.teacher_earning_analytics OWNER TO postgres;

--
-- TOC entry 4834 (class 0 OID 0)
-- Dependencies: 268
-- Name: TABLE teacher_earning_analytics; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.teacher_earning_analytics IS 'CLN-26 | FK → CLN-02, CLN-12. Immutable per-event earning log. Line items for payslip disputes.';


--
-- TOC entry 267 (class 1259 OID 30902)
-- Name: teacher_earning_analytics_earning_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.teacher_earning_analytics_earning_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.teacher_earning_analytics_earning_id_seq OWNER TO postgres;

--
-- TOC entry 4835 (class 0 OID 0)
-- Dependencies: 267
-- Name: teacher_earning_analytics_earning_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.teacher_earning_analytics_earning_id_seq OWNED BY clean.teacher_earning_analytics.earning_id;


--
-- TOC entry 231 (class 1259 OID 30420)
-- Name: teacher_holidays; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.teacher_holidays (
    holiday_id integer NOT NULL,
    teacher_id integer NOT NULL,
    holiday_date date NOT NULL,
    full_day boolean DEFAULT true NOT NULL,
    start_time time without time zone,
    end_time time without time zone,
    reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.teacher_holidays OWNER TO postgres;

--
-- TOC entry 4836 (class 0 OID 0)
-- Dependencies: 231
-- Name: TABLE teacher_holidays; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.teacher_holidays IS 'CLN-06 | FK → CLN-02. One-off unavailability. Booking must check both CLN-05 and CLN-06.';


--
-- TOC entry 230 (class 1259 OID 30419)
-- Name: teacher_holidays_holiday_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.teacher_holidays_holiday_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.teacher_holidays_holiday_id_seq OWNER TO postgres;

--
-- TOC entry 4837 (class 0 OID 0)
-- Dependencies: 230
-- Name: teacher_holidays_holiday_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.teacher_holidays_holiday_id_seq OWNED BY clean.teacher_holidays.holiday_id;


--
-- TOC entry 272 (class 1259 OID 30956)
-- Name: teacher_payout_transactions; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.teacher_payout_transactions (
    payout_id integer NOT NULL,
    payslip_id integer NOT NULL,
    teacher_id integer NOT NULL,
    amount numeric(10,2) NOT NULL,
    currency character varying(5) DEFAULT 'ILS'::character varying NOT NULL,
    payout_method text,
    reference_no text,
    status clean.payout_status DEFAULT 'pending'::clean.payout_status NOT NULL,
    initiated_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    failure_reason text
);


ALTER TABLE clean.teacher_payout_transactions OWNER TO postgres;

--
-- TOC entry 4838 (class 0 OID 0)
-- Dependencies: 272
-- Name: TABLE teacher_payout_transactions; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.teacher_payout_transactions IS 'CLN-28 | FK → CLN-27, CLN-02. Actual money movement out to teacher. Separate from payslip approval.';


--
-- TOC entry 271 (class 1259 OID 30955)
-- Name: teacher_payout_transactions_payout_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.teacher_payout_transactions_payout_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.teacher_payout_transactions_payout_id_seq OWNER TO postgres;

--
-- TOC entry 4839 (class 0 OID 0)
-- Dependencies: 271
-- Name: teacher_payout_transactions_payout_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.teacher_payout_transactions_payout_id_seq OWNED BY clean.teacher_payout_transactions.payout_id;


--
-- TOC entry 270 (class 1259 OID 30925)
-- Name: teacher_payslips; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.teacher_payslips (
    payslip_id integer NOT NULL,
    teacher_id integer NOT NULL,
    period_start date NOT NULL,
    period_end date NOT NULL,
    total_classes integer DEFAULT 0 NOT NULL,
    gross_amount numeric(10,2) DEFAULT 0 NOT NULL,
    deductions numeric(10,2) DEFAULT 0 NOT NULL,
    net_amount numeric(10,2) DEFAULT 0 NOT NULL,
    currency character varying(5) DEFAULT 'ILS'::character varying NOT NULL,
    status clean.payslip_status DEFAULT 'draft'::clean.payslip_status NOT NULL,
    approved_by integer,
    approved_at timestamp with time zone,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.teacher_payslips OWNER TO postgres;

--
-- TOC entry 4840 (class 0 OID 0)
-- Dependencies: 270
-- Name: TABLE teacher_payslips; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.teacher_payslips IS 'CLN-27 | FK → CLN-02. Monthly payslip header. Line items are in CLN-26.';


--
-- TOC entry 269 (class 1259 OID 30924)
-- Name: teacher_payslips_payslip_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.teacher_payslips_payslip_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.teacher_payslips_payslip_id_seq OWNER TO postgres;

--
-- TOC entry 4841 (class 0 OID 0)
-- Dependencies: 269
-- Name: teacher_payslips_payslip_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.teacher_payslips_payslip_id_seq OWNED BY clean.teacher_payslips.payslip_id;


--
-- TOC entry 227 (class 1259 OID 30375)
-- Name: teacher_recommendations; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.teacher_recommendations (
    recommendation_id integer NOT NULL,
    questionnaire_id integer NOT NULL,
    teacher_id integer NOT NULL,
    match_score numeric(5,2),
    rank integer,
    reasoning text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.teacher_recommendations OWNER TO postgres;

--
-- TOC entry 4842 (class 0 OID 0)
-- Dependencies: 227
-- Name: TABLE teacher_recommendations; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.teacher_recommendations IS 'CLN-04 | FK → CLN-03, CLN-02. AI-generated teacher match scores per student questionnaire.';


--
-- TOC entry 226 (class 1259 OID 30374)
-- Name: teacher_recommendations_recommendation_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.teacher_recommendations_recommendation_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.teacher_recommendations_recommendation_id_seq OWNER TO postgres;

--
-- TOC entry 4843 (class 0 OID 0)
-- Dependencies: 226
-- Name: teacher_recommendations_recommendation_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.teacher_recommendations_recommendation_id_seq OWNED BY clean.teacher_recommendations.recommendation_id;


--
-- TOC entry 223 (class 1259 OID 30336)
-- Name: teachers; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.teachers (
    teacher_id integer NOT NULL,
    email text NOT NULL,
    full_name text NOT NULL,
    timezone text DEFAULT 'UTC'::text NOT NULL,
    bio text,
    specializations jsonb,
    teaching_languages jsonb,
    cefr_can_teach jsonb,
    hourly_rate numeric(8,2),
    currency character varying(5) DEFAULT 'ILS'::character varying NOT NULL,
    status clean.teacher_status DEFAULT 'pending_review'::clean.teacher_status NOT NULL,
    avg_rating numeric(3,2) DEFAULT 0 NOT NULL,
    total_classes_taught integer DEFAULT 0 NOT NULL,
    verification_rate numeric(5,2) DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.teachers OWNER TO postgres;

--
-- TOC entry 4844 (class 0 OID 0)
-- Dependencies: 223
-- Name: TABLE teachers; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.teachers IS 'Typed teacher entity. ENUMs for status at app layer.';


--
-- TOC entry 260 (class 1259 OID 30790)
-- Name: word_lists; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.word_lists (
    list_id integer NOT NULL,
    student_id integer NOT NULL,
    name character varying(120) NOT NULL,
    description text,
    is_favorite boolean DEFAULT false NOT NULL,
    word_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.word_lists OWNER TO postgres;

--
-- TOC entry 4845 (class 0 OID 0)
-- Dependencies: 260
-- Name: TABLE word_lists; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.word_lists IS 'CLN-22 | FK → CLN-01. Student or AI-generated word collections.';


--
-- TOC entry 259 (class 1259 OID 30789)
-- Name: word_lists_list_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.word_lists_list_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.word_lists_list_id_seq OWNER TO postgres;

--
-- TOC entry 4846 (class 0 OID 0)
-- Dependencies: 259
-- Name: word_lists_list_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.word_lists_list_id_seq OWNED BY clean.word_lists.list_id;


--
-- TOC entry 264 (class 1259 OID 30832)
-- Name: word_practice_sessions; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.word_practice_sessions (
    practice_id integer NOT NULL,
    list_id integer NOT NULL,
    student_id integer NOT NULL,
    words_practiced integer DEFAULT 0 NOT NULL,
    correct_count integer DEFAULT 0 NOT NULL,
    score_pct numeric(5,2),
    duration_secs integer,
    practiced_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.word_practice_sessions OWNER TO postgres;

--
-- TOC entry 4847 (class 0 OID 0)
-- Dependencies: 264
-- Name: TABLE word_practice_sessions; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.word_practice_sessions IS 'CLN-24 | FK → CLN-22, CLN-01. Each drill session for a word list.';


--
-- TOC entry 263 (class 1259 OID 30831)
-- Name: word_practice_sessions_practice_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.word_practice_sessions_practice_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.word_practice_sessions_practice_id_seq OWNER TO postgres;

--
-- TOC entry 4848 (class 0 OID 0)
-- Dependencies: 263
-- Name: word_practice_sessions_practice_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.word_practice_sessions_practice_id_seq OWNED BY clean.word_practice_sessions.practice_id;


--
-- TOC entry 262 (class 1259 OID 30810)
-- Name: words; Type: TABLE; Schema: clean; Owner: postgres
--

CREATE TABLE clean.words (
    word_id integer NOT NULL,
    list_id integer NOT NULL,
    word character varying(120) NOT NULL,
    translation character varying(240) NOT NULL,
    notes text,
    is_favorite boolean DEFAULT false NOT NULL,
    practice_count integer DEFAULT 0 NOT NULL,
    correct_count integer DEFAULT 0 NOT NULL,
    accuracy numeric(5,2) DEFAULT 0 NOT NULL,
    last_practiced timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE clean.words OWNER TO postgres;

--
-- TOC entry 4849 (class 0 OID 0)
-- Dependencies: 262
-- Name: TABLE words; Type: COMMENT; Schema: clean; Owner: postgres
--

COMMENT ON TABLE clean.words IS 'CLN-23 | FK → CLN-22. Individual word with accuracy tracking.';


--
-- TOC entry 261 (class 1259 OID 30809)
-- Name: words_word_id_seq; Type: SEQUENCE; Schema: clean; Owner: postgres
--

CREATE SEQUENCE clean.words_word_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE clean.words_word_id_seq OWNER TO postgres;

--
-- TOC entry 4850 (class 0 OID 0)
-- Dependencies: 261
-- Name: words_word_id_seq; Type: SEQUENCE OWNED BY; Schema: clean; Owner: postgres
--

ALTER SEQUENCE clean.words_word_id_seq OWNED BY clean.words.word_id;


--
-- TOC entry 345 (class 1259 OID 98097)
-- Name: classes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.classes (
    id integer NOT NULL,
    student_id integer,
    teacher_id integer NOT NULL,
    feedback_id integer,
    meeting_start timestamp without time zone,
    meeting_end timestamp without time zone,
    status character varying(50) DEFAULT 'pending'::character varying,
    join_url text,
    admin_url text,
    zoom_id character varying(255),
    student_goal text,
    student_goal_note text,
    question_and_answer character varying(200),
    next_month_class_term smallint DEFAULT 0 NOT NULL,
    bonus_class smallint DEFAULT 0 NOT NULL,
    is_trial smallint,
    subscription_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    booked_by character varying(255) DEFAULT 'Student'::character varying,
    canceled_by character varying(255) DEFAULT 'Student'::character varying,
    cancel_reason text,
    booked_by_admin_id bigint,
    class_type character varying(255) DEFAULT 'website'::character varying,
    batch_id character varying(255),
    is_game_approved smallint DEFAULT 0 NOT NULL,
    is_regular_hide smallint DEFAULT 0 NOT NULL,
    demo_class_id integer,
    is_present smallint DEFAULT 1 NOT NULL,
    cancellation_reason text,
    cancelled_by integer,
    cancelled_at timestamp without time zone,
    get_classes_for_extension character varying(20) DEFAULT 'not_updated'::character varying NOT NULL,
    recording_status character varying(50) DEFAULT 'pending'::character varying,
    recording_url text,
    zoom_meeting_id character varying(20) GENERATED ALWAYS AS (
CASE
    WHEN ((join_url ~~ '%/j/%'::text) AND (join_url ~~ '%?pwd%'::text)) THEN split_part(split_part(join_url, '/j/'::text, 2), '?pwd'::text, 1)
    WHEN (join_url ~~ '%/j/%'::text) THEN split_part(join_url, '/j/'::text, 2)
    ELSE NULL::text
END) STORED
);


ALTER TABLE public.classes OWNER TO postgres;

--
-- TOC entry 344 (class 1259 OID 98096)
-- Name: classes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.classes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.classes_id_seq OWNER TO postgres;

--
-- TOC entry 4851 (class 0 OID 0)
-- Dependencies: 344
-- Name: classes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.classes_id_seq OWNED BY public.classes.id;


--
-- TOC entry 355 (class 1259 OID 98192)
-- Name: llm_audio_analyses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.llm_audio_analyses (
    id bigint NOT NULL,
    job_id character(36) NOT NULL,
    zoom_meeting_id character varying(64),
    summary text NOT NULL,
    topics jsonb NOT NULL,
    level character varying(50) NOT NULL,
    grammar_feedback text,
    vocabulary_feedback text,
    pronunciation_feedback text,
    general_comment text,
    vocabulary_score integer DEFAULT 0,
    grammar_score integer DEFAULT 0,
    fluency_score integer DEFAULT 0,
    engagement_level character varying(10) DEFAULT 'medium'::character varying,
    raw_analysis jsonb NOT NULL,
    vocabulary_words jsonb,
    grammar_points jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT llm_audio_analyses_engagement_level_check CHECK (((engagement_level)::text = ANY ((ARRAY['low'::character varying, 'medium'::character varying, 'high'::character varying])::text[])))
);


ALTER TABLE public.llm_audio_analyses OWNER TO postgres;

--
-- TOC entry 354 (class 1259 OID 98191)
-- Name: llm_audio_analyses_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.llm_audio_analyses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.llm_audio_analyses_id_seq OWNER TO postgres;

--
-- TOC entry 4852 (class 0 OID 0)
-- Dependencies: 354
-- Name: llm_audio_analyses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.llm_audio_analyses_id_seq OWNED BY public.llm_audio_analyses.id;


--
-- TOC entry 357 (class 1259 OID 98213)
-- Name: llm_intake_queue; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.llm_intake_queue (
    id bigint NOT NULL,
    audio_url text NOT NULL,
    level character varying(50) DEFAULT 'unknown'::character varying,
    language character varying(50) DEFAULT 'hebrew'::character varying,
    zoom_meeting_id character varying(64),
    topic character varying(255) DEFAULT ''::character varying,
    tokens integer,
    idempotency_key character varying(512),
    priority integer DEFAULT 100,
    status character varying(32) DEFAULT 'PENDING'::character varying,
    request_id character(36),
    attempt_count integer DEFAULT 0,
    max_attempts integer DEFAULT 5,
    error text,
    metadata jsonb,
    queued_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    admitted_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.llm_intake_queue OWNER TO postgres;

--
-- TOC entry 356 (class 1259 OID 98212)
-- Name: llm_intake_queue_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.llm_intake_queue_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.llm_intake_queue_id_seq OWNER TO postgres;

--
-- TOC entry 4853 (class 0 OID 0)
-- Dependencies: 356
-- Name: llm_intake_queue_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.llm_intake_queue_id_seq OWNED BY public.llm_intake_queue.id;


--
-- TOC entry 353 (class 1259 OID 98186)
-- Name: llm_model_usage_daily; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.llm_model_usage_daily (
    model character varying(255) NOT NULL,
    date date NOT NULL,
    total_tokens integer,
    total_cost numeric(10,6)
);


ALTER TABLE public.llm_model_usage_daily OWNER TO postgres;

--
-- TOC entry 347 (class 1259 OID 98132)
-- Name: llm_prompt_templates; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.llm_prompt_templates (
    id character(36) NOT NULL,
    version integer,
    name text,
    content text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.llm_prompt_templates OWNER TO postgres;

--
-- TOC entry 358 (class 1259 OID 98233)
-- Name: llm_rate_limits; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.llm_rate_limits (
    id integer DEFAULT 1 NOT NULL,
    rpm_limit integer DEFAULT 15,
    tpm_limit integer DEFAULT 1000000,
    rpd_limit integer DEFAULT 1500,
    max_pipeline_depth integer DEFAULT 20,
    estimated_tokens_per_audio integer DEFAULT 50000,
    intake_batch_size integer DEFAULT 5,
    intake_poll_seconds integer DEFAULT 10,
    max_intake_attempts integer DEFAULT 5,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.llm_rate_limits OWNER TO postgres;

--
-- TOC entry 349 (class 1259 OID 98155)
-- Name: llm_request_attempts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.llm_request_attempts (
    id character(36) NOT NULL,
    request_id character(36),
    attempt_number integer,
    provider text,
    model text,
    started_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    ended_at timestamp without time zone,
    latency_ms integer,
    status character varying(255),
    error text,
    tokens_prompt integer,
    tokens_completion integer,
    cost_estimate numeric(10,6),
    worker_id text,
    resolve_ms integer,
    download_ms integer,
    upload_ms integer,
    analyze_ms integer,
    store_ms integer,
    total_ms integer,
    audio_file_size_bytes bigint
);


ALTER TABLE public.llm_request_attempts OWNER TO postgres;

--
-- TOC entry 351 (class 1259 OID 98172)
-- Name: llm_request_events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.llm_request_events (
    id character(36) NOT NULL,
    request_id character(36),
    event_type text,
    event_data jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.llm_request_events OWNER TO postgres;

--
-- TOC entry 348 (class 1259 OID 98140)
-- Name: llm_requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.llm_requests (
    id character(36) NOT NULL,
    user_id character(36),
    idempotency_key text,
    prompt_template_id character(36),
    provider text,
    model text,
    payload jsonb,
    status character varying(255),
    attempt_count integer DEFAULT 0,
    priority integer DEFAULT 100,
    schema_definition jsonb,
    schema_validation_status text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    locked_at timestamp without time zone,
    worker_id text,
    dedup_hit_count integer DEFAULT 0
);


ALTER TABLE public.llm_requests OWNER TO postgres;

--
-- TOC entry 350 (class 1259 OID 98164)
-- Name: llm_responses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.llm_responses (
    request_id character(36) NOT NULL,
    raw_response jsonb,
    parsed_response jsonb,
    completed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.llm_responses OWNER TO postgres;

--
-- TOC entry 361 (class 1259 OID 98262)
-- Name: llm_system_health; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.llm_system_health (
    id character varying(128) NOT NULL,
    component character varying(32) NOT NULL,
    last_heartbeat timestamp without time zone,
    last_job_at timestamp without time zone,
    last_error_at timestamp without time zone,
    last_error text,
    jobs_processed bigint DEFAULT 0,
    jobs_failed bigint DEFAULT 0,
    queue_depth integer,
    circuit_breaker character varying(16),
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.llm_system_health OWNER TO postgres;

--
-- TOC entry 352 (class 1259 OID 98181)
-- Name: llm_user_usage_daily; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.llm_user_usage_daily (
    user_id character(36) NOT NULL,
    date date NOT NULL,
    total_tokens integer,
    total_cost numeric(10,6)
);


ALTER TABLE public.llm_user_usage_daily OWNER TO postgres;

--
-- TOC entry 346 (class 1259 OID 98124)
-- Name: llm_users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.llm_users (
    id character(36) NOT NULL,
    email text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.llm_users OWNER TO postgres;

--
-- TOC entry 343 (class 1259 OID 98086)
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    full_name character varying(255),
    email character varying(255),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.users OWNER TO postgres;

--
-- TOC entry 342 (class 1259 OID 98085)
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO postgres;

--
-- TOC entry 4854 (class 0 OID 0)
-- Dependencies: 342
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- TOC entry 360 (class 1259 OID 98249)
-- Name: zoom_processing_queue; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zoom_processing_queue (
    id integer NOT NULL,
    meeting_id character varying(100) NOT NULL,
    session_uuid character varying(100),
    webhook_payload jsonb NOT NULL,
    retry_count integer DEFAULT 0,
    error_message text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    started_at timestamp without time zone,
    completed_at timestamp without time zone,
    llm_response_raw text
);


ALTER TABLE public.zoom_processing_queue OWNER TO postgres;

--
-- TOC entry 359 (class 1259 OID 98248)
-- Name: zoom_processing_queue_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.zoom_processing_queue_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.zoom_processing_queue_id_seq OWNER TO postgres;

--
-- TOC entry 4855 (class 0 OID 0)
-- Dependencies: 359
-- Name: zoom_processing_queue_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.zoom_processing_queue_id_seq OWNED BY public.zoom_processing_queue.id;


--
-- TOC entry 217 (class 1259 OID 30270)
-- Name: app_analytics; Type: TABLE; Schema: raw; Owner: postgres
--

CREATE TABLE raw.app_analytics (
    event_id bigint NOT NULL,
    event_type text NOT NULL,
    entity_id integer,
    idempotency_key text NOT NULL,
    payload jsonb NOT NULL,
    _etl_loaded_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE raw.app_analytics OWNER TO postgres;

--
-- TOC entry 4856 (class 0 OID 0)
-- Dependencies: 217
-- Name: TABLE app_analytics; Type: COMMENT; Schema: raw; Owner: postgres
--

COMMENT ON TABLE raw.app_analytics IS 'RAW-02 | App-emitted analytics: class_completed, game_played, payment_received, etc.';


--
-- TOC entry 216 (class 1259 OID 30269)
-- Name: app_analytics_event_id_seq; Type: SEQUENCE; Schema: raw; Owner: postgres
--

CREATE SEQUENCE raw.app_analytics_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE raw.app_analytics_event_id_seq OWNER TO postgres;

--
-- TOC entry 4857 (class 0 OID 0)
-- Dependencies: 216
-- Name: app_analytics_event_id_seq; Type: SEQUENCE OWNED BY; Schema: raw; Owner: postgres
--

ALTER SEQUENCE raw.app_analytics_event_id_seq OWNED BY raw.app_analytics.event_id;


--
-- TOC entry 215 (class 1259 OID 30256)
-- Name: app_users; Type: TABLE; Schema: raw; Owner: postgres
--

CREATE TABLE raw.app_users (
    id bigint NOT NULL,
    source_id integer NOT NULL,
    idempotency_key text NOT NULL,
    payload jsonb NOT NULL,
    _etl_loaded_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE raw.app_users OWNER TO postgres;

--
-- TOC entry 4858 (class 0 OID 0)
-- Dependencies: 215
-- Name: TABLE app_users; Type: COMMENT; Schema: raw; Owner: postgres
--

COMMENT ON TABLE raw.app_users IS 'Dual-write from app on every users INSERT/UPDATE. Append-only, never query for business logic.';


--
-- TOC entry 214 (class 1259 OID 30255)
-- Name: app_users_id_seq; Type: SEQUENCE; Schema: raw; Owner: postgres
--

CREATE SEQUENCE raw.app_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE raw.app_users_id_seq OWNER TO postgres;

--
-- TOC entry 4859 (class 0 OID 0)
-- Dependencies: 214
-- Name: app_users_id_seq; Type: SEQUENCE OWNED BY; Schema: raw; Owner: postgres
--

ALTER SEQUENCE raw.app_users_id_seq OWNED BY raw.app_users.id;


--
-- TOC entry 219 (class 1259 OID 30285)
-- Name: billing_webhooks; Type: TABLE; Schema: raw; Owner: postgres
--

CREATE TABLE raw.billing_webhooks (
    webhook_id bigint NOT NULL,
    source text DEFAULT 'payplus'::text NOT NULL,
    event_type text NOT NULL,
    idempotency_key text NOT NULL,
    payplus_sequence bigint,
    payload jsonb NOT NULL,
    processed boolean DEFAULT false NOT NULL,
    _etl_loaded_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE raw.billing_webhooks OWNER TO postgres;

--
-- TOC entry 4860 (class 0 OID 0)
-- Dependencies: 219
-- Name: TABLE billing_webhooks; Type: COMMENT; Schema: raw; Owner: postgres
--

COMMENT ON TABLE raw.billing_webhooks IS 'RAW-03 | PayPlus webhooks. Process ORDER BY _etl_loaded_at ASC, payplus_sequence ASC. Aggregate terminal state per subscription_id before UPDATE.';


--
-- TOC entry 218 (class 1259 OID 30284)
-- Name: billing_webhooks_webhook_id_seq; Type: SEQUENCE; Schema: raw; Owner: postgres
--

CREATE SEQUENCE raw.billing_webhooks_webhook_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE raw.billing_webhooks_webhook_id_seq OWNER TO postgres;

--
-- TOC entry 4861 (class 0 OID 0)
-- Dependencies: 218
-- Name: billing_webhooks_webhook_id_seq; Type: SEQUENCE OWNED BY; Schema: raw; Owner: postgres
--

ALTER SEQUENCE raw.billing_webhooks_webhook_id_seq OWNED BY raw.billing_webhooks.webhook_id;


--
-- TOC entry 221 (class 1259 OID 30302)
-- Name: dead_letter; Type: TABLE; Schema: raw; Owner: postgres
--

CREATE TABLE raw.dead_letter (
    id bigint NOT NULL,
    source_table text NOT NULL,
    source_row_id bigint NOT NULL,
    idempotency_key text,
    rejection_reason text NOT NULL,
    payload jsonb NOT NULL,
    retry_count integer DEFAULT 0 NOT NULL,
    last_retried_at timestamp with time zone,
    resolved boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE raw.dead_letter OWNER TO postgres;

--
-- TOC entry 4862 (class 0 OID 0)
-- Dependencies: 221
-- Name: TABLE dead_letter; Type: COMMENT; Schema: raw; Owner: postgres
--

COMMENT ON TABLE raw.dead_letter IS 'RAW-04 | Rows rejected by clean layer (FK violation, bad data). Investigate and replay. Never silently drop.';


--
-- TOC entry 220 (class 1259 OID 30301)
-- Name: dead_letter_id_seq; Type: SEQUENCE; Schema: raw; Owner: postgres
--

CREATE SEQUENCE raw.dead_letter_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE raw.dead_letter_id_seq OWNER TO postgres;

--
-- TOC entry 4863 (class 0 OID 0)
-- Dependencies: 220
-- Name: dead_letter_id_seq; Type: SEQUENCE OWNED BY; Schema: raw; Owner: postgres
--

ALTER SEQUENCE raw.dead_letter_id_seq OWNED BY raw.dead_letter.id;


--
-- TOC entry 317 (class 1259 OID 31398)
-- Name: llm_audio_analyses; Type: TABLE; Schema: raw; Owner: postgres
--

CREATE TABLE raw.llm_audio_analyses (
    id bigint NOT NULL,
    source_id integer,
    idempotency_key text DEFAULT (gen_random_uuid())::text NOT NULL,
    payload jsonb,
    _etl_loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    job_id text,
    zoom_meeting_id text,
    summary text,
    topics jsonb,
    level text,
    grammar_feedback text,
    vocabulary_feedback text,
    pronunciation_feedback text,
    general_comment text,
    vocabulary_score integer DEFAULT 0,
    grammar_score integer DEFAULT 0,
    fluency_score integer DEFAULT 0,
    engagement_level text DEFAULT 'medium'::text,
    raw_analysis jsonb,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    vocabulary_words jsonb,
    grammar_points jsonb,
    student_id integer,
    teacher_id integer,
    meeting_start timestamp with time zone,
    student_turn_count integer,
    teacher_turn_count integer,
    student_talking_ratio numeric(4,3),
    self_correction_count integer,
    error_counts jsonb,
    pronunciation_flags jsonb,
    grammar_error_rate numeric(6,2),
    advanced_vocabulary_ratio numeric(4,3),
    avg_words_per_speaking_turn integer,
    total_error_count integer
);


ALTER TABLE raw.llm_audio_analyses OWNER TO postgres;

--
-- TOC entry 4864 (class 0 OID 0)
-- Dependencies: 317
-- Name: TABLE llm_audio_analyses; Type: COMMENT; Schema: raw; Owner: postgres
--

COMMENT ON TABLE raw.llm_audio_analyses IS 'RAW-08 | Source: MySQL llm_audio_analyses (2,486 rows). Massive nested JSON with all AI scores. Unpacked in clean layer.';


--
-- TOC entry 316 (class 1259 OID 31397)
-- Name: llm_audio_analyses_id_seq; Type: SEQUENCE; Schema: raw; Owner: postgres
--

CREATE SEQUENCE raw.llm_audio_analyses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE raw.llm_audio_analyses_id_seq OWNER TO postgres;

--
-- TOC entry 4865 (class 0 OID 0)
-- Dependencies: 316
-- Name: llm_audio_analyses_id_seq; Type: SEQUENCE OWNED BY; Schema: raw; Owner: postgres
--

ALTER SEQUENCE raw.llm_audio_analyses_id_seq OWNED BY raw.llm_audio_analyses.id;


--
-- TOC entry 319 (class 1259 OID 31412)
-- Name: llm_intake_queue; Type: TABLE; Schema: raw; Owner: postgres
--

CREATE TABLE raw.llm_intake_queue (
    id bigint NOT NULL,
    source_id integer,
    idempotency_key text DEFAULT (gen_random_uuid())::text NOT NULL,
    payload jsonb,
    _etl_loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    status text DEFAULT 'PENDING'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    audio_url text,
    level text DEFAULT 'unknown'::text,
    language text DEFAULT 'hebrew'::text,
    zoom_meeting_id text,
    topic text,
    priority integer DEFAULT 100 NOT NULL,
    request_id text,
    attempt_count integer DEFAULT 0 NOT NULL,
    max_attempts integer DEFAULT 5 NOT NULL,
    error text,
    metadata jsonb,
    updated_at timestamp with time zone,
    admitted_at timestamp with time zone
);


ALTER TABLE raw.llm_intake_queue OWNER TO postgres;

--
-- TOC entry 4866 (class 0 OID 0)
-- Dependencies: 319
-- Name: TABLE llm_intake_queue; Type: COMMENT; Schema: raw; Owner: postgres
--

COMMENT ON TABLE raw.llm_intake_queue IS 'RAW-09 | Source: MySQL llm_intake_queue (2,619 rows). Queue entries before LLM processing.';


--
-- TOC entry 318 (class 1259 OID 31411)
-- Name: llm_intake_queue_id_seq; Type: SEQUENCE; Schema: raw; Owner: postgres
--

CREATE SEQUENCE raw.llm_intake_queue_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE raw.llm_intake_queue_id_seq OWNER TO postgres;

--
-- TOC entry 4867 (class 0 OID 0)
-- Dependencies: 318
-- Name: llm_intake_queue_id_seq; Type: SEQUENCE OWNED BY; Schema: raw; Owner: postgres
--

ALTER SEQUENCE raw.llm_intake_queue_id_seq OWNED BY raw.llm_intake_queue.id;


--
-- TOC entry 321 (class 1259 OID 31426)
-- Name: llm_request_attempts; Type: TABLE; Schema: raw; Owner: postgres
--

CREATE TABLE raw.llm_request_attempts (
    id bigint NOT NULL,
    source_id text,
    idempotency_key text DEFAULT (gen_random_uuid())::text NOT NULL,
    payload jsonb,
    _etl_loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    request_id text,
    attempt_number integer,
    provider text,
    model text,
    status text,
    error text,
    latency_ms integer,
    tokens_prompt integer,
    tokens_completion integer,
    cost_estimate numeric(10,6),
    worker_id text,
    total_ms integer,
    audio_file_size_bytes bigint,
    started_at timestamp with time zone,
    ended_at timestamp with time zone,
    resolve_ms integer,
    download_ms integer,
    upload_ms integer,
    analyze_ms integer,
    store_ms integer
);


ALTER TABLE raw.llm_request_attempts OWNER TO postgres;

--
-- TOC entry 4868 (class 0 OID 0)
-- Dependencies: 321
-- Name: TABLE llm_request_attempts; Type: COMMENT; Schema: raw; Owner: postgres
--

COMMENT ON TABLE raw.llm_request_attempts IS 'RAW-10 | Source: MySQL llm_request_attempts (3,180 rows). Per-attempt latency, cost, stage breakdowns.';


--
-- TOC entry 320 (class 1259 OID 31425)
-- Name: llm_request_attempts_id_seq; Type: SEQUENCE; Schema: raw; Owner: postgres
--

CREATE SEQUENCE raw.llm_request_attempts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE raw.llm_request_attempts_id_seq OWNER TO postgres;

--
-- TOC entry 4869 (class 0 OID 0)
-- Dependencies: 320
-- Name: llm_request_attempts_id_seq; Type: SEQUENCE OWNED BY; Schema: raw; Owner: postgres
--

ALTER SEQUENCE raw.llm_request_attempts_id_seq OWNED BY raw.llm_request_attempts.id;


--
-- TOC entry 323 (class 1259 OID 31440)
-- Name: llm_request_events; Type: TABLE; Schema: raw; Owner: postgres
--

CREATE TABLE raw.llm_request_events (
    id bigint NOT NULL,
    source_id text,
    idempotency_key text DEFAULT (gen_random_uuid())::text NOT NULL,
    payload jsonb,
    _etl_loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    request_id text,
    event_type text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    event_data jsonb
);


ALTER TABLE raw.llm_request_events OWNER TO postgres;

--
-- TOC entry 4870 (class 0 OID 0)
-- Dependencies: 323
-- Name: TABLE llm_request_events; Type: COMMENT; Schema: raw; Owner: postgres
--

COMMENT ON TABLE raw.llm_request_events IS 'RAW-11 | Source: MySQL llm_request_events (8,523 rows). Event log for every request state change.';


--
-- TOC entry 322 (class 1259 OID 31439)
-- Name: llm_request_events_id_seq; Type: SEQUENCE; Schema: raw; Owner: postgres
--

CREATE SEQUENCE raw.llm_request_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE raw.llm_request_events_id_seq OWNER TO postgres;

--
-- TOC entry 4871 (class 0 OID 0)
-- Dependencies: 322
-- Name: llm_request_events_id_seq; Type: SEQUENCE OWNED BY; Schema: raw; Owner: postgres
--

ALTER SEQUENCE raw.llm_request_events_id_seq OWNED BY raw.llm_request_events.id;


--
-- TOC entry 313 (class 1259 OID 31370)
-- Name: llm_requests; Type: TABLE; Schema: raw; Owner: postgres
--

CREATE TABLE raw.llm_requests (
    id bigint NOT NULL,
    source_id text,
    idempotency_key text DEFAULT (gen_random_uuid())::text NOT NULL,
    payload jsonb,
    _etl_loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    status text DEFAULT 'queued'::text NOT NULL,
    request_id text,
    class_id integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    user_id text,
    prompt_template_id text,
    provider text,
    model text,
    attempt_count integer DEFAULT 0 NOT NULL,
    priority integer DEFAULT 100 NOT NULL,
    schema_validation_status text,
    updated_at timestamp with time zone,
    locked_at timestamp with time zone,
    worker_id text,
    dedup_hit_count integer DEFAULT 0 NOT NULL,
    schema_definition jsonb
);


ALTER TABLE raw.llm_requests OWNER TO postgres;

--
-- TOC entry 4872 (class 0 OID 0)
-- Dependencies: 313
-- Name: TABLE llm_requests; Type: COMMENT; Schema: raw; Owner: postgres
--

COMMENT ON TABLE raw.llm_requests IS 'RAW-06 | Source: MySQL llm_requests (2,614 rows). Full request blobs. Append-only.';


--
-- TOC entry 312 (class 1259 OID 31369)
-- Name: llm_requests_id_seq; Type: SEQUENCE; Schema: raw; Owner: postgres
--

CREATE SEQUENCE raw.llm_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE raw.llm_requests_id_seq OWNER TO postgres;

--
-- TOC entry 4873 (class 0 OID 0)
-- Dependencies: 312
-- Name: llm_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: raw; Owner: postgres
--

ALTER SEQUENCE raw.llm_requests_id_seq OWNED BY raw.llm_requests.id;


--
-- TOC entry 315 (class 1259 OID 31384)
-- Name: llm_responses; Type: TABLE; Schema: raw; Owner: postgres
--

CREATE TABLE raw.llm_responses (
    id bigint NOT NULL,
    source_id text,
    idempotency_key text DEFAULT (gen_random_uuid())::text NOT NULL,
    payload jsonb,
    _etl_loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    raw_response text,
    parsed_response jsonb,
    request_id text
);


ALTER TABLE raw.llm_responses OWNER TO postgres;

--
-- TOC entry 4874 (class 0 OID 0)
-- Dependencies: 315
-- Name: TABLE llm_responses; Type: COMMENT; Schema: raw; Owner: postgres
--

COMMENT ON TABLE raw.llm_responses IS 'RAW-07 | Source: MySQL llm_responses (2,579 rows). raw_response + parsed_response blobs.';


--
-- TOC entry 314 (class 1259 OID 31383)
-- Name: llm_responses_id_seq; Type: SEQUENCE; Schema: raw; Owner: postgres
--

CREATE SEQUENCE raw.llm_responses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE raw.llm_responses_id_seq OWNER TO postgres;

--
-- TOC entry 4875 (class 0 OID 0)
-- Dependencies: 314
-- Name: llm_responses_id_seq; Type: SEQUENCE OWNED BY; Schema: raw; Owner: postgres
--

ALTER SEQUENCE raw.llm_responses_id_seq OWNED BY raw.llm_responses.id;


--
-- TOC entry 363 (class 1259 OID 128795)
-- Name: student_error_history; Type: TABLE; Schema: raw; Owner: postgres
--

CREATE TABLE raw.student_error_history (
    id bigint NOT NULL,
    student_id integer NOT NULL,
    error_type text NOT NULL,
    first_detected_at date NOT NULL,
    last_detected_at date NOT NULL,
    total_occurrences integer DEFAULT 0 NOT NULL,
    lessons_observed_count integer DEFAULT 0 NOT NULL,
    consecutive_clean_lessons integer DEFAULT 0 NOT NULL,
    resolved boolean DEFAULT false NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE raw.student_error_history OWNER TO postgres;

--
-- TOC entry 362 (class 1259 OID 128794)
-- Name: student_error_history_id_seq; Type: SEQUENCE; Schema: raw; Owner: postgres
--

ALTER TABLE raw.student_error_history ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME raw.student_error_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 365 (class 1259 OID 128813)
-- Name: student_progress_timeseries; Type: TABLE; Schema: raw; Owner: postgres
--

CREATE TABLE raw.student_progress_timeseries (
    id bigint NOT NULL,
    student_id integer NOT NULL,
    teacher_id integer,
    analysis_id bigint,
    zoom_meeting_id text,
    lesson_date date NOT NULL,
    cefr_level text,
    vocabulary_score integer,
    grammar_score integer,
    fluency_score integer,
    engagement_level text,
    student_talking_ratio numeric(4,3),
    self_correction_count integer,
    student_turn_count integer,
    total_error_count integer,
    grammar_error_rate numeric(6,2),
    advanced_vocabulary_ratio numeric(4,3),
    avg_words_per_turn integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE raw.student_progress_timeseries OWNER TO postgres;

--
-- TOC entry 364 (class 1259 OID 128812)
-- Name: student_progress_timeseries_id_seq; Type: SEQUENCE; Schema: raw; Owner: postgres
--

ALTER TABLE raw.student_progress_timeseries ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME raw.student_progress_timeseries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 311 (class 1259 OID 31352)
-- Name: zoom_webhook_request; Type: TABLE; Schema: raw; Owner: postgres
--

CREATE TABLE raw.zoom_webhook_request (
    id bigint NOT NULL,
    source_id text,
    idempotency_key text DEFAULT (gen_random_uuid())::text NOT NULL,
    meeting_id text NOT NULL,
    session_uuid text,
    recording_start timestamp with time zone,
    recording_end timestamp with time zone,
    audio_url text,
    urls text,
    payload jsonb,
    retry_count integer DEFAULT 0 NOT NULL,
    error_message text,
    processed boolean DEFAULT false NOT NULL,
    _etl_loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    llm_response_raw jsonb,
    created_at timestamp with time zone,
    webhook_payload jsonb
);


ALTER TABLE raw.zoom_webhook_request OWNER TO postgres;

--
-- TOC entry 4876 (class 0 OID 0)
-- Dependencies: 311
-- Name: TABLE zoom_webhook_request; Type: COMMENT; Schema: raw; Owner: postgres
--

COMMENT ON TABLE raw.zoom_webhook_request IS 'RAW-05 | Zoom recording webhooks. Renamed from zoom_processing_queue. recording_start, recording_end, audio_url extracted from payload on ingest.';


--
-- TOC entry 4877 (class 0 OID 0)
-- Dependencies: 311
-- Name: COLUMN zoom_webhook_request.idempotency_key; Type: COMMENT; Schema: raw; Owner: postgres
--

COMMENT ON COLUMN raw.zoom_webhook_request.idempotency_key IS 'Built from session_uuid. Kept for consistency with other raw tables.';


--
-- TOC entry 4878 (class 0 OID 0)
-- Dependencies: 311
-- Name: COLUMN zoom_webhook_request.session_uuid; Type: COMMENT; Schema: raw; Owner: postgres
--

COMMENT ON COLUMN raw.zoom_webhook_request.session_uuid IS 'Unique session identifier from Zoom. Used as natural idempotency key — no duplicate inserts possible.';


--
-- TOC entry 4879 (class 0 OID 0)
-- Dependencies: 311
-- Name: COLUMN zoom_webhook_request.audio_url; Type: COMMENT; Schema: raw; Owner: postgres
--

COMMENT ON COLUMN raw.zoom_webhook_request.audio_url IS 'Primary m4a audio file url extracted from payload.';


--
-- TOC entry 4880 (class 0 OID 0)
-- Dependencies: 311
-- Name: COLUMN zoom_webhook_request.urls; Type: COMMENT; Schema: raw; Owner: postgres
--

COMMENT ON COLUMN raw.zoom_webhook_request.urls IS 'All urls found in payload comma separated, all file types.';


--
-- TOC entry 310 (class 1259 OID 31351)
-- Name: zoom_webhook_request_id_seq; Type: SEQUENCE; Schema: raw; Owner: postgres
--

CREATE SEQUENCE raw.zoom_webhook_request_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE raw.zoom_webhook_request_id_seq OWNER TO postgres;

--
-- TOC entry 4881 (class 0 OID 0)
-- Dependencies: 310
-- Name: zoom_webhook_request_id_seq; Type: SEQUENCE OWNED BY; Schema: raw; Owner: postgres
--

ALTER SEQUENCE raw.zoom_webhook_request_id_seq OWNED BY raw.zoom_webhook_request.id;


--
-- TOC entry 289 (class 1259 OID 31198)
-- Name: revenue_snapshot; Type: TABLE; Schema: serve; Owner: postgres
--

CREATE TABLE serve.revenue_snapshot (
    snapshot_date date NOT NULL,
    mrr_ils numeric(12,2) DEFAULT 0 NOT NULL,
    arr_ils numeric(12,2) DEFAULT 0 NOT NULL,
    active_subscriptions integer DEFAULT 0 NOT NULL,
    family_plan_count integer DEFAULT 0 NOT NULL,
    solo_plan_count integer DEFAULT 0 NOT NULL,
    new_signups integer DEFAULT 0 NOT NULL,
    churned_count integer DEFAULT 0 NOT NULL,
    avg_revenue_per_user numeric(10,2) DEFAULT 0 NOT NULL,
    total_transactions integer DEFAULT 0 NOT NULL,
    failed_transactions integer DEFAULT 0 NOT NULL,
    total_referral_rewards numeric(10,2) DEFAULT 0 NOT NULL,
    _etl_updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE serve.revenue_snapshot OWNER TO postgres;

--
-- TOC entry 4882 (class 0 OID 0)
-- Dependencies: 289
-- Name: TABLE revenue_snapshot; Type: COMMENT; Schema: serve; Owner: postgres
--

COMMENT ON TABLE serve.revenue_snapshot IS 'SRV-05 | No FK. Built from CLN-25, CLN-09. Daily micro-batch. Reverse-ETL → Dashboard.';


--
-- TOC entry 329 (class 1259 OID 31509)
-- Name: student_ai_profile; Type: TABLE; Schema: serve; Owner: postgres
--

CREATE TABLE serve.student_ai_profile (
    student_id integer NOT NULL,
    latest_cefr_level clean.cefr_level,
    latest_vocabulary_score numeric(5,2),
    latest_grammar_score numeric(5,2),
    latest_fluency_score numeric(5,2),
    avg_vocabulary_score numeric(5,2),
    avg_grammar_score numeric(5,2),
    avg_fluency_score numeric(5,2),
    weakest_skill text,
    most_common_error text,
    total_ai_lessons integer DEFAULT 0 NOT NULL,
    last_analysis_at timestamp with time zone,
    _etl_updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE serve.student_ai_profile OWNER TO postgres;

--
-- TOC entry 4883 (class 0 OID 0)
-- Dependencies: 329
-- Name: TABLE student_ai_profile; Type: COMMENT; Schema: serve; Owner: postgres
--

COMMENT ON TABLE serve.student_ai_profile IS 'SRV-06 | FK → CLN-01. Built from CLN-35. One row per student. Mobile app progress screen. Reverse-ETL every 15 min.';


--
-- TOC entry 286 (class 1259 OID 31145)
-- Name: student_gamification_profile; Type: TABLE; Schema: serve; Owner: postgres
--

CREATE TABLE serve.student_gamification_profile (
    student_id integer NOT NULL,
    current_streak_days integer DEFAULT 0 NOT NULL,
    longest_streak_days integer DEFAULT 0 NOT NULL,
    total_xp integer DEFAULT 0 NOT NULL,
    current_league text,
    games_played integer DEFAULT 0 NOT NULL,
    last_active_at timestamp with time zone,
    _etl_updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE serve.student_gamification_profile OWNER TO postgres;

--
-- TOC entry 4884 (class 0 OID 0)
-- Dependencies: 286
-- Name: TABLE student_gamification_profile; Type: COMMENT; Schema: serve; Owner: postgres
--

COMMENT ON TABLE serve.student_gamification_profile IS 'SRV-02 | FK → CLN-01. Built from CLN-15, CLN-19, CLN-21. Reverse-ETL → Mobile App.';


--
-- TOC entry 287 (class 1259 OID 31163)
-- Name: student_health_monetization; Type: TABLE; Schema: serve; Owner: postgres
--

CREATE TABLE serve.student_health_monetization (
    student_id integer NOT NULL,
    access_level text DEFAULT 'Free'::text NOT NULL,
    subscription_status clean.subscription_status,
    classes_remaining integer,
    is_family_plan_member boolean DEFAULT false NOT NULL,
    family_role clean.member_role,
    churn_risk_score numeric(4,3),
    risk_level clean.risk_level,
    days_since_last_active integer,
    _etl_updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE serve.student_health_monetization OWNER TO postgres;

--
-- TOC entry 4885 (class 0 OID 0)
-- Dependencies: 287
-- Name: TABLE student_health_monetization; Type: COMMENT; Schema: serve; Owner: postgres
--

COMMENT ON TABLE serve.student_health_monetization IS 'SRV-03 | FK → CLN-01. Built from CLN-10, CLN-09, CLN-15, CLN-29. Reverse-ETL → Mobile App + Dashboard.';


--
-- TOC entry 285 (class 1259 OID 31129)
-- Name: student_mastery_profile; Type: TABLE; Schema: serve; Owner: postgres
--

CREATE TABLE serve.student_mastery_profile (
    student_id integer NOT NULL,
    cefr_level clean.cefr_level,
    fluency_score numeric(5,2),
    vocabulary_score numeric(5,2),
    grammar_score numeric(5,2),
    weakest_concept text,
    total_lessons_completed integer DEFAULT 0 NOT NULL,
    vocabulary_count integer DEFAULT 0 NOT NULL,
    _etl_updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE serve.student_mastery_profile OWNER TO postgres;

--
-- TOC entry 4886 (class 0 OID 0)
-- Dependencies: 285
-- Name: TABLE student_mastery_profile; Type: COMMENT; Schema: serve; Owner: postgres
--

COMMENT ON TABLE serve.student_mastery_profile IS 'SRV-01 | FK → CLN-01. Built from CLN-14. Reverse-ETL → Mobile App. Trigger: lesson_attempt completed.';


--
-- TOC entry 288 (class 1259 OID 31180)
-- Name: teacher_performance_profile; Type: TABLE; Schema: serve; Owner: postgres
--

CREATE TABLE serve.teacher_performance_profile (
    teacher_id integer NOT NULL,
    avg_rating numeric(3,2) DEFAULT 0 NOT NULL,
    total_classes_taught integer DEFAULT 0 NOT NULL,
    verification_rate numeric(5,2) DEFAULT 0 NOT NULL,
    avg_topics_per_class numeric(5,2) DEFAULT 0 NOT NULL,
    student_retention_rate numeric(5,2) DEFAULT 0 NOT NULL,
    total_earnings_ils numeric(12,2) DEFAULT 0 NOT NULL,
    _etl_updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE serve.teacher_performance_profile OWNER TO postgres;

--
-- TOC entry 4887 (class 0 OID 0)
-- Dependencies: 288
-- Name: TABLE teacher_performance_profile; Type: COMMENT; Schema: serve; Owner: postgres
--

COMMENT ON TABLE serve.teacher_performance_profile IS 'SRV-04 | FK → CLN-02. Built from CLN-12, CLN-14, CLN-26. Reverse-ETL → Dashboard.';


--
-- TOC entry 3999 (class 2604 OID 31763)
-- Name: campaigns campaign_id; Type: DEFAULT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.campaigns ALTER COLUMN campaign_id SET DEFAULT nextval('analytics.campaigns_campaign_id_seq'::regclass);


--
-- TOC entry 3911 (class 2604 OID 31231)
-- Name: class_facts event_id; Type: DEFAULT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.class_facts ALTER COLUMN event_id SET DEFAULT nextval('analytics.class_facts_event_id_seq'::regclass);


--
-- TOC entry 3918 (class 2604 OID 31269)
-- Name: gamification_facts event_id; Type: DEFAULT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.gamification_facts ALTER COLUMN event_id SET DEFAULT nextval('analytics.gamification_facts_event_id_seq'::regclass);


--
-- TOC entry 3930 (class 2604 OID 31330)
-- Name: intervention_facts event_id; Type: DEFAULT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.intervention_facts ALTER COLUMN event_id SET DEFAULT nextval('analytics.intervention_facts_event_id_seq'::regclass);


--
-- TOC entry 4005 (class 2604 OID 31780)
-- Name: leads lead_id; Type: DEFAULT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.leads ALTER COLUMN lead_id SET DEFAULT nextval('analytics.leads_lead_id_seq'::regclass);


--
-- TOC entry 3989 (class 2604 OID 31528)
-- Name: llm_facts event_id; Type: DEFAULT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.llm_facts ALTER COLUMN event_id SET DEFAULT nextval('analytics.llm_facts_event_id_seq'::regclass);


--
-- TOC entry 3914 (class 2604 OID 31244)
-- Name: payment_facts event_id; Type: DEFAULT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.payment_facts ALTER COLUMN event_id SET DEFAULT nextval('analytics.payment_facts_event_id_seq'::regclass);


--
-- TOC entry 3923 (class 2604 OID 31293)
-- Name: referral_facts event_id; Type: DEFAULT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.referral_facts ALTER COLUMN event_id SET DEFAULT nextval('analytics.referral_facts_event_id_seq'::regclass);


--
-- TOC entry 3927 (class 2604 OID 31317)
-- Name: risk_facts event_id; Type: DEFAULT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.risk_facts ALTER COLUMN event_id SET DEFAULT nextval('analytics.risk_facts_event_id_seq'::regclass);


--
-- TOC entry 3909 (class 2604 OID 31219)
-- Name: student_lifecycle event_id; Type: DEFAULT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.student_lifecycle ALTER COLUMN event_id SET DEFAULT nextval('analytics.student_lifecycle_event_id_seq'::regclass);


--
-- TOC entry 3995 (class 2604 OID 31734)
-- Name: student_touchpoints event_id; Type: DEFAULT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.student_touchpoints ALTER COLUMN event_id SET DEFAULT nextval('analytics.student_touchpoints_event_id_seq'::regclass);


--
-- TOC entry 3916 (class 2604 OID 31257)
-- Name: subscription_facts event_id; Type: DEFAULT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.subscription_facts ALTER COLUMN event_id SET DEFAULT nextval('analytics.subscription_facts_event_id_seq'::regclass);


--
-- TOC entry 3925 (class 2604 OID 31305)
-- Name: teacher_facts event_id; Type: DEFAULT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.teacher_facts ALTER COLUMN event_id SET DEFAULT nextval('analytics.teacher_facts_event_id_seq'::regclass);


--
-- TOC entry 3997 (class 2604 OID 31748)
-- Name: teacher_observations observation_id; Type: DEFAULT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.teacher_observations ALTER COLUMN observation_id SET DEFAULT nextval('analytics.teacher_observations_observation_id_seq'::regclass);


--
-- TOC entry 3920 (class 2604 OID 31281)
-- Name: vocabulary_facts event_id; Type: DEFAULT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.vocabulary_facts ALTER COLUMN event_id SET DEFAULT nextval('analytics.vocabulary_facts_event_id_seq'::regclass);


--
-- TOC entry 3816 (class 2604 OID 30758)
-- Name: achievements achievement_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.achievements ALTER COLUMN achievement_id SET DEFAULT nextval('clean.achievements_achievement_id_seq'::regclass);


--
-- TOC entry 3804 (class 2604 OID 30683)
-- Name: app_sessions session_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.app_sessions ALTER COLUMN session_id SET DEFAULT nextval('clean.app_sessions_session_id_seq'::regclass);


--
-- TOC entry 3860 (class 2604 OID 30983)
-- Name: churn_risk_scores score_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.churn_risk_scores ALTER COLUMN score_id SET DEFAULT nextval('clean.churn_risk_scores_score_id_seq'::regclass);


--
-- TOC entry 3794 (class 2604 OID 30620)
-- Name: class_analytics event_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.class_analytics ALTER COLUMN event_id SET DEFAULT nextval('clean.class_analytics_event_id_seq'::regclass);


--
-- TOC entry 3767 (class 2604 OID 30443)
-- Name: families family_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.families ALTER COLUMN family_id SET DEFAULT nextval('clean.families_family_id_seq'::regclass);


--
-- TOC entry 3771 (class 2604 OID 30462)
-- Name: family_children child_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.family_children ALTER COLUMN child_id SET DEFAULT nextval('clean.family_children_child_id_seq'::regclass);


--
-- TOC entry 3812 (class 2604 OID 30734)
-- Name: game_sessions session_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.game_sessions ALTER COLUMN session_id SET DEFAULT nextval('clean.game_sessions_session_id_seq'::regclass);


--
-- TOC entry 3809 (class 2604 OID 30717)
-- Name: games game_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.games ALTER COLUMN game_id SET DEFAULT nextval('clean.games_game_id_seq'::regclass);


--
-- TOC entry 3796 (class 2604 OID 30642)
-- Name: lesson_attempts attempt_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.lesson_attempts ALTER COLUMN attempt_id SET DEFAULT nextval('clean.lesson_attempts_attempt_id_seq'::regclass);


--
-- TOC entry 3972 (class 2604 OID 31457)
-- Name: llm_lesson_analyses analysis_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.llm_lesson_analyses ALTER COLUMN analysis_id SET DEFAULT nextval('clean.llm_lesson_analyses_analysis_id_seq'::regclass);


--
-- TOC entry 3982 (class 2604 OID 31498)
-- Name: llm_system_health health_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.llm_system_health ALTER COLUMN health_id SET DEFAULT nextval('clean.llm_system_health_health_id_seq'::regclass);


--
-- TOC entry 3806 (class 2604 OID 30699)
-- Name: notifications_log notification_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.notifications_log ALTER COLUMN notification_id SET DEFAULT nextval('clean.notifications_log_notification_id_seq'::regclass);


--
-- TOC entry 3837 (class 2604 OID 30857)
-- Name: payment_transactions txn_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.payment_transactions ALTER COLUMN txn_id SET DEFAULT nextval('clean.payment_transactions_txn_id_seq'::regclass);


--
-- TOC entry 3819 (class 2604 OID 30776)
-- Name: points_ledger ledger_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.points_ledger ALTER COLUMN ledger_id SET DEFAULT nextval('clean.points_ledger_ledger_id_seq'::regclass);


--
-- TOC entry 3754 (class 2604 OID 30359)
-- Name: questionnaire_responses response_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.questionnaire_responses ALTER COLUMN response_id SET DEFAULT nextval('clean.questionnaire_responses_response_id_seq'::regclass);


--
-- TOC entry 3865 (class 2604 OID 31029)
-- Name: referral_config config_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.referral_config ALTER COLUMN config_id SET DEFAULT nextval('clean.referral_config_config_id_seq'::regclass);


--
-- TOC entry 3875 (class 2604 OID 31099)
-- Name: referral_fraud_logs fraud_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.referral_fraud_logs ALTER COLUMN fraud_id SET DEFAULT nextval('clean.referral_fraud_logs_fraud_id_seq'::regclass);


--
-- TOC entry 3871 (class 2604 OID 31070)
-- Name: referral_rewards reward_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.referral_rewards ALTER COLUMN reward_id SET DEFAULT nextval('clean.referral_rewards_reward_id_seq'::regclass);


--
-- TOC entry 3867 (class 2604 OID 31041)
-- Name: referrals referral_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.referrals ALTER COLUMN referral_id SET DEFAULT nextval('clean.referrals_referral_id_seq'::regclass);


--
-- TOC entry 3862 (class 2604 OID 31001)
-- Name: retention_interventions intervention_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.retention_interventions ALTER COLUMN intervention_id SET DEFAULT nextval('clean.retention_interventions_intervention_id_seq'::regclass);


--
-- TOC entry 3992 (class 2604 OID 31721)
-- Name: sales_agents agent_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.sales_agents ALTER COLUMN agent_id SET DEFAULT nextval('clean.sales_agents_agent_id_seq'::regclass);


--
-- TOC entry 3787 (class 2604 OID 30548)
-- Name: subscription_modifications mod_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.subscription_modifications ALTER COLUMN mod_id SET DEFAULT nextval('clean.subscription_modifications_mod_id_seq'::regclass);


--
-- TOC entry 3776 (class 2604 OID 30491)
-- Name: subscriptions subscription_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.subscriptions ALTER COLUMN subscription_id SET DEFAULT nextval('clean.subscriptions_subscription_id_seq'::regclass);


--
-- TOC entry 3759 (class 2604 OID 30400)
-- Name: teacher_availability availability_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_availability ALTER COLUMN availability_id SET DEFAULT nextval('clean.teacher_availability_availability_id_seq'::regclass);


--
-- TOC entry 3845 (class 2604 OID 30906)
-- Name: teacher_earning_analytics earning_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_earning_analytics ALTER COLUMN earning_id SET DEFAULT nextval('clean.teacher_earning_analytics_earning_id_seq'::regclass);


--
-- TOC entry 3764 (class 2604 OID 30423)
-- Name: teacher_holidays holiday_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_holidays ALTER COLUMN holiday_id SET DEFAULT nextval('clean.teacher_holidays_holiday_id_seq'::regclass);


--
-- TOC entry 3856 (class 2604 OID 30959)
-- Name: teacher_payout_transactions payout_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_payout_transactions ALTER COLUMN payout_id SET DEFAULT nextval('clean.teacher_payout_transactions_payout_id_seq'::regclass);


--
-- TOC entry 3847 (class 2604 OID 30928)
-- Name: teacher_payslips payslip_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_payslips ALTER COLUMN payslip_id SET DEFAULT nextval('clean.teacher_payslips_payslip_id_seq'::regclass);


--
-- TOC entry 3757 (class 2604 OID 30378)
-- Name: teacher_recommendations recommendation_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_recommendations ALTER COLUMN recommendation_id SET DEFAULT nextval('clean.teacher_recommendations_recommendation_id_seq'::regclass);


--
-- TOC entry 3821 (class 2604 OID 30793)
-- Name: word_lists list_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.word_lists ALTER COLUMN list_id SET DEFAULT nextval('clean.word_lists_list_id_seq'::regclass);


--
-- TOC entry 3833 (class 2604 OID 30835)
-- Name: word_practice_sessions practice_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.word_practice_sessions ALTER COLUMN practice_id SET DEFAULT nextval('clean.word_practice_sessions_practice_id_seq'::regclass);


--
-- TOC entry 3826 (class 2604 OID 30813)
-- Name: words word_id; Type: DEFAULT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.words ALTER COLUMN word_id SET DEFAULT nextval('clean.words_word_id_seq'::regclass);


--
-- TOC entry 4011 (class 2604 OID 98100)
-- Name: classes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.classes ALTER COLUMN id SET DEFAULT nextval('public.classes_id_seq'::regclass);


--
-- TOC entry 4034 (class 2604 OID 98195)
-- Name: llm_audio_analyses id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.llm_audio_analyses ALTER COLUMN id SET DEFAULT nextval('public.llm_audio_analyses_id_seq'::regclass);


--
-- TOC entry 4041 (class 2604 OID 98216)
-- Name: llm_intake_queue id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.llm_intake_queue ALTER COLUMN id SET DEFAULT nextval('public.llm_intake_queue_id_seq'::regclass);


--
-- TOC entry 4008 (class 2604 OID 98089)
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- TOC entry 4062 (class 2604 OID 98252)
-- Name: zoom_processing_queue id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zoom_processing_queue ALTER COLUMN id SET DEFAULT nextval('public.zoom_processing_queue_id_seq'::regclass);


--
-- TOC entry 3728 (class 2604 OID 30273)
-- Name: app_analytics event_id; Type: DEFAULT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.app_analytics ALTER COLUMN event_id SET DEFAULT nextval('raw.app_analytics_event_id_seq'::regclass);


--
-- TOC entry 3726 (class 2604 OID 30259)
-- Name: app_users id; Type: DEFAULT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.app_users ALTER COLUMN id SET DEFAULT nextval('raw.app_users_id_seq'::regclass);


--
-- TOC entry 3730 (class 2604 OID 30288)
-- Name: billing_webhooks webhook_id; Type: DEFAULT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.billing_webhooks ALTER COLUMN webhook_id SET DEFAULT nextval('raw.billing_webhooks_webhook_id_seq'::regclass);


--
-- TOC entry 3734 (class 2604 OID 30305)
-- Name: dead_letter id; Type: DEFAULT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.dead_letter ALTER COLUMN id SET DEFAULT nextval('raw.dead_letter_id_seq'::regclass);


--
-- TOC entry 3948 (class 2604 OID 31401)
-- Name: llm_audio_analyses id; Type: DEFAULT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.llm_audio_analyses ALTER COLUMN id SET DEFAULT nextval('raw.llm_audio_analyses_id_seq'::regclass);


--
-- TOC entry 3955 (class 2604 OID 31415)
-- Name: llm_intake_queue id; Type: DEFAULT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.llm_intake_queue ALTER COLUMN id SET DEFAULT nextval('raw.llm_intake_queue_id_seq'::regclass);


--
-- TOC entry 3965 (class 2604 OID 31429)
-- Name: llm_request_attempts id; Type: DEFAULT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.llm_request_attempts ALTER COLUMN id SET DEFAULT nextval('raw.llm_request_attempts_id_seq'::regclass);


--
-- TOC entry 3968 (class 2604 OID 31443)
-- Name: llm_request_events id; Type: DEFAULT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.llm_request_events ALTER COLUMN id SET DEFAULT nextval('raw.llm_request_events_id_seq'::regclass);


--
-- TOC entry 3937 (class 2604 OID 31373)
-- Name: llm_requests id; Type: DEFAULT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.llm_requests ALTER COLUMN id SET DEFAULT nextval('raw.llm_requests_id_seq'::regclass);


--
-- TOC entry 3945 (class 2604 OID 31387)
-- Name: llm_responses id; Type: DEFAULT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.llm_responses ALTER COLUMN id SET DEFAULT nextval('raw.llm_responses_id_seq'::regclass);


--
-- TOC entry 3932 (class 2604 OID 31355)
-- Name: zoom_webhook_request id; Type: DEFAULT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.zoom_webhook_request ALTER COLUMN id SET DEFAULT nextval('raw.zoom_webhook_request_id_seq'::regclass);


--
-- TOC entry 4450 (class 2606 OID 31772)
-- Name: campaigns campaigns_pkey; Type: CONSTRAINT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.campaigns
    ADD CONSTRAINT campaigns_pkey PRIMARY KEY (campaign_id);


--
-- TOC entry 4299 (class 2606 OID 31237)
-- Name: class_facts class_facts_pkey; Type: CONSTRAINT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.class_facts
    ADD CONSTRAINT class_facts_pkey PRIMARY KEY (event_id);


--
-- TOC entry 4312 (class 2606 OID 31274)
-- Name: gamification_facts gamification_facts_pkey; Type: CONSTRAINT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.gamification_facts
    ADD CONSTRAINT gamification_facts_pkey PRIMARY KEY (event_id);


--
-- TOC entry 4333 (class 2606 OID 31335)
-- Name: intervention_facts intervention_facts_pkey; Type: CONSTRAINT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.intervention_facts
    ADD CONSTRAINT intervention_facts_pkey PRIMARY KEY (event_id);


--
-- TOC entry 4460 (class 2606 OID 31786)
-- Name: leads leads_pkey; Type: CONSTRAINT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.leads
    ADD CONSTRAINT leads_pkey PRIMARY KEY (lead_id);


--
-- TOC entry 4432 (class 2606 OID 31534)
-- Name: llm_facts llm_facts_pkey; Type: CONSTRAINT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.llm_facts
    ADD CONSTRAINT llm_facts_pkey PRIMARY KEY (event_id);


--
-- TOC entry 4306 (class 2606 OID 31249)
-- Name: payment_facts payment_facts_pkey; Type: CONSTRAINT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.payment_facts
    ADD CONSTRAINT payment_facts_pkey PRIMARY KEY (event_id);


--
-- TOC entry 4321 (class 2606 OID 31298)
-- Name: referral_facts referral_facts_pkey; Type: CONSTRAINT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.referral_facts
    ADD CONSTRAINT referral_facts_pkey PRIMARY KEY (event_id);


--
-- TOC entry 4329 (class 2606 OID 31323)
-- Name: risk_facts risk_facts_pkey; Type: CONSTRAINT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.risk_facts
    ADD CONSTRAINT risk_facts_pkey PRIMARY KEY (event_id);


--
-- TOC entry 4297 (class 2606 OID 31224)
-- Name: student_lifecycle student_lifecycle_pkey; Type: CONSTRAINT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.student_lifecycle
    ADD CONSTRAINT student_lifecycle_pkey PRIMARY KEY (event_id);


--
-- TOC entry 4442 (class 2606 OID 31739)
-- Name: student_touchpoints student_touchpoints_pkey; Type: CONSTRAINT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.student_touchpoints
    ADD CONSTRAINT student_touchpoints_pkey PRIMARY KEY (event_id);


--
-- TOC entry 4310 (class 2606 OID 31262)
-- Name: subscription_facts subscription_facts_pkey; Type: CONSTRAINT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.subscription_facts
    ADD CONSTRAINT subscription_facts_pkey PRIMARY KEY (event_id);


--
-- TOC entry 4325 (class 2606 OID 31310)
-- Name: teacher_facts teacher_facts_pkey; Type: CONSTRAINT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.teacher_facts
    ADD CONSTRAINT teacher_facts_pkey PRIMARY KEY (event_id);


--
-- TOC entry 4448 (class 2606 OID 31754)
-- Name: teacher_observations teacher_observations_pkey; Type: CONSTRAINT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.teacher_observations
    ADD CONSTRAINT teacher_observations_pkey PRIMARY KEY (observation_id);


--
-- TOC entry 4317 (class 2606 OID 31287)
-- Name: vocabulary_facts vocabulary_facts_pkey; Type: CONSTRAINT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.vocabulary_facts
    ADD CONSTRAINT vocabulary_facts_pkey PRIMARY KEY (event_id);


--
-- TOC entry 4207 (class 2606 OID 30764)
-- Name: achievements achievements_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.achievements
    ADD CONSTRAINT achievements_pkey PRIMARY KEY (achievement_id);


--
-- TOC entry 4193 (class 2606 OID 30688)
-- Name: app_sessions app_sessions_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.app_sessions
    ADD CONSTRAINT app_sessions_pkey PRIMARY KEY (session_id);


--
-- TOC entry 4251 (class 2606 OID 30989)
-- Name: churn_risk_scores churn_risk_scores_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.churn_risk_scores
    ADD CONSTRAINT churn_risk_scores_pkey PRIMARY KEY (score_id);


--
-- TOC entry 4180 (class 2606 OID 30625)
-- Name: class_analytics class_analytics_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.class_analytics
    ADD CONSTRAINT class_analytics_pkey PRIMARY KEY (event_id);


--
-- TOC entry 4169 (class 2606 OID 30587)
-- Name: classes classes_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.classes
    ADD CONSTRAINT classes_pkey PRIMARY KEY (class_id);


--
-- TOC entry 4190 (class 2606 OID 30672)
-- Name: daily_activity daily_activity_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.daily_activity
    ADD CONSTRAINT daily_activity_pkey PRIMARY KEY (student_id, activity_date);


--
-- TOC entry 4142 (class 2606 OID 30450)
-- Name: families families_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.families
    ADD CONSTRAINT families_pkey PRIMARY KEY (family_id);


--
-- TOC entry 4146 (class 2606 OID 30470)
-- Name: family_children family_children_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.family_children
    ADD CONSTRAINT family_children_pkey PRIMARY KEY (child_id);


--
-- TOC entry 4203 (class 2606 OID 30741)
-- Name: game_sessions game_sessions_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.game_sessions
    ADD CONSTRAINT game_sessions_pkey PRIMARY KEY (session_id);


--
-- TOC entry 4200 (class 2606 OID 30723)
-- Name: games games_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.games
    ADD CONSTRAINT games_pkey PRIMARY KEY (game_id);


--
-- TOC entry 4186 (class 2606 OID 30648)
-- Name: lesson_attempts lesson_attempts_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.lesson_attempts
    ADD CONSTRAINT lesson_attempts_pkey PRIMARY KEY (attempt_id);


--
-- TOC entry 4415 (class 2606 OID 31464)
-- Name: llm_lesson_analyses llm_lesson_analyses_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.llm_lesson_analyses
    ADD CONSTRAINT llm_lesson_analyses_pkey PRIMARY KEY (analysis_id);


--
-- TOC entry 4420 (class 2606 OID 31492)
-- Name: llm_model_usage_daily llm_model_usage_daily_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.llm_model_usage_daily
    ADD CONSTRAINT llm_model_usage_daily_pkey PRIMARY KEY (metric_date, model);


--
-- TOC entry 4422 (class 2606 OID 31506)
-- Name: llm_system_health llm_system_health_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.llm_system_health
    ADD CONSTRAINT llm_system_health_pkey PRIMARY KEY (health_id);


--
-- TOC entry 4198 (class 2606 OID 30705)
-- Name: notifications_log notifications_log_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.notifications_log
    ADD CONSTRAINT notifications_log_pkey PRIMARY KEY (notification_id);


--
-- TOC entry 4233 (class 2606 OID 30868)
-- Name: payment_transactions payment_transactions_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.payment_transactions
    ADD CONSTRAINT payment_transactions_pkey PRIMARY KEY (txn_id);


--
-- TOC entry 4213 (class 2606 OID 30781)
-- Name: points_ledger points_ledger_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.points_ledger
    ADD CONSTRAINT points_ledger_pkey PRIMARY KEY (ledger_id);


--
-- TOC entry 4123 (class 2606 OID 30365)
-- Name: questionnaire_responses questionnaire_responses_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.questionnaire_responses
    ADD CONSTRAINT questionnaire_responses_pkey PRIMARY KEY (response_id);


--
-- TOC entry 4259 (class 2606 OID 31034)
-- Name: referral_config referral_config_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.referral_config
    ADD CONSTRAINT referral_config_pkey PRIMARY KEY (config_id);


--
-- TOC entry 4278 (class 2606 OID 31106)
-- Name: referral_fraud_logs referral_fraud_logs_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.referral_fraud_logs
    ADD CONSTRAINT referral_fraud_logs_pkey PRIMARY KEY (fraud_id);


--
-- TOC entry 4274 (class 2606 OID 31077)
-- Name: referral_rewards referral_rewards_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.referral_rewards
    ADD CONSTRAINT referral_rewards_pkey PRIMARY KEY (reward_id);


--
-- TOC entry 4266 (class 2606 OID 31048)
-- Name: referrals referrals_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.referrals
    ADD CONSTRAINT referrals_pkey PRIMARY KEY (referral_id);


--
-- TOC entry 4257 (class 2606 OID 31007)
-- Name: retention_interventions retention_interventions_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.retention_interventions
    ADD CONSTRAINT retention_interventions_pkey PRIMARY KEY (intervention_id);


--
-- TOC entry 4434 (class 2606 OID 31727)
-- Name: sales_agents sales_agents_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.sales_agents
    ADD CONSTRAINT sales_agents_pkey PRIMARY KEY (agent_id);


--
-- TOC entry 4111 (class 2606 OID 30329)
-- Name: students students_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (student_id);


--
-- TOC entry 4163 (class 2606 OID 30526)
-- Name: subscription_members subscription_members_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.subscription_members
    ADD CONSTRAINT subscription_members_pkey PRIMARY KEY (subscription_id, student_id);


--
-- TOC entry 4167 (class 2606 OID 30555)
-- Name: subscription_modifications subscription_modifications_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.subscription_modifications
    ADD CONSTRAINT subscription_modifications_pkey PRIMARY KEY (mod_id);


--
-- TOC entry 4157 (class 2606 OID 30502)
-- Name: subscriptions subscriptions_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (subscription_id);


--
-- TOC entry 4132 (class 2606 OID 30410)
-- Name: teacher_availability teacher_availability_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_availability
    ADD CONSTRAINT teacher_availability_pkey PRIMARY KEY (availability_id);


--
-- TOC entry 4239 (class 2606 OID 30911)
-- Name: teacher_earning_analytics teacher_earning_analytics_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_earning_analytics
    ADD CONSTRAINT teacher_earning_analytics_pkey PRIMARY KEY (earning_id);


--
-- TOC entry 4138 (class 2606 OID 30429)
-- Name: teacher_holidays teacher_holidays_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_holidays
    ADD CONSTRAINT teacher_holidays_pkey PRIMARY KEY (holiday_id);


--
-- TOC entry 4249 (class 2606 OID 30966)
-- Name: teacher_payout_transactions teacher_payout_transactions_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_payout_transactions
    ADD CONSTRAINT teacher_payout_transactions_pkey PRIMARY KEY (payout_id);


--
-- TOC entry 4243 (class 2606 OID 30940)
-- Name: teacher_payslips teacher_payslips_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_payslips
    ADD CONSTRAINT teacher_payslips_pkey PRIMARY KEY (payslip_id);


--
-- TOC entry 4129 (class 2606 OID 30383)
-- Name: teacher_recommendations teacher_recommendations_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_recommendations
    ADD CONSTRAINT teacher_recommendations_pkey PRIMARY KEY (recommendation_id);


--
-- TOC entry 4118 (class 2606 OID 30350)
-- Name: teachers teachers_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teachers
    ADD CONSTRAINT teachers_pkey PRIMARY KEY (teacher_id);


--
-- TOC entry 4176 (class 2606 OID 30591)
-- Name: classes uq_classes_booking; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.classes
    ADD CONSTRAINT uq_classes_booking UNIQUE (teacher_id, meeting_start);


--
-- TOC entry 4178 (class 2606 OID 30589)
-- Name: classes uq_classes_idem; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.classes
    ADD CONSTRAINT uq_classes_idem UNIQUE (idempotency_key);


--
-- TOC entry 4417 (class 2606 OID 31466)
-- Name: llm_lesson_analyses uq_cln_llm_analysis_meeting; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.llm_lesson_analyses
    ADD CONSTRAINT uq_cln_llm_analysis_meeting UNIQUE (zoom_meeting_id);


--
-- TOC entry 4424 (class 2606 OID 31508)
-- Name: llm_system_health uq_cln_llm_health_component; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.llm_system_health
    ADD CONSTRAINT uq_cln_llm_health_component UNIQUE (component);


--
-- TOC entry 4152 (class 2606 OID 30472)
-- Name: family_children uq_family_child_student; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.family_children
    ADD CONSTRAINT uq_family_child_student UNIQUE (family_id, student_id);


--
-- TOC entry 4188 (class 2606 OID 30650)
-- Name: lesson_attempts uq_lesson_attempts_class; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.lesson_attempts
    ADD CONSTRAINT uq_lesson_attempts_class UNIQUE (class_id);


--
-- TOC entry 4235 (class 2606 OID 30870)
-- Name: payment_transactions uq_payment_txn_idem; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.payment_transactions
    ADD CONSTRAINT uq_payment_txn_idem UNIQUE (idempotency_key);


--
-- TOC entry 4245 (class 2606 OID 30942)
-- Name: teacher_payslips uq_payslip_period; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_payslips
    ADD CONSTRAINT uq_payslip_period UNIQUE (teacher_id, period_start, period_end);


--
-- TOC entry 4125 (class 2606 OID 30367)
-- Name: questionnaire_responses uq_questionnaire_idem; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.questionnaire_responses
    ADD CONSTRAINT uq_questionnaire_idem UNIQUE (idempotency_key);


--
-- TOC entry 4268 (class 2606 OID 31052)
-- Name: referrals uq_referral_code; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.referrals
    ADD CONSTRAINT uq_referral_code UNIQUE (referral_code);


--
-- TOC entry 4261 (class 2606 OID 31036)
-- Name: referral_config uq_referral_config_key; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.referral_config
    ADD CONSTRAINT uq_referral_config_key UNIQUE (config_key);


--
-- TOC entry 4270 (class 2606 OID 31050)
-- Name: referrals uq_referrals_idem; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.referrals
    ADD CONSTRAINT uq_referrals_idem UNIQUE (idempotency_key);


--
-- TOC entry 4436 (class 2606 OID 31729)
-- Name: sales_agents uq_sales_agents_email; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.sales_agents
    ADD CONSTRAINT uq_sales_agents_email UNIQUE (email);


--
-- TOC entry 4113 (class 2606 OID 30331)
-- Name: students uq_students_email; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.students
    ADD CONSTRAINT uq_students_email UNIQUE (email);


--
-- TOC entry 4159 (class 2606 OID 30504)
-- Name: subscriptions uq_subscriptions_idem; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.subscriptions
    ADD CONSTRAINT uq_subscriptions_idem UNIQUE (idempotency_key);


--
-- TOC entry 4134 (class 2606 OID 30412)
-- Name: teacher_availability uq_teacher_availability; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_availability
    ADD CONSTRAINT uq_teacher_availability UNIQUE (teacher_id, day_of_week, start_time);


--
-- TOC entry 4140 (class 2606 OID 30431)
-- Name: teacher_holidays uq_teacher_holiday; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_holidays
    ADD CONSTRAINT uq_teacher_holiday UNIQUE (teacher_id, holiday_date, start_time);


--
-- TOC entry 4120 (class 2606 OID 30352)
-- Name: teachers uq_teachers_email; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teachers
    ADD CONSTRAINT uq_teachers_email UNIQUE (email);


--
-- TOC entry 4217 (class 2606 OID 30801)
-- Name: word_lists word_lists_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.word_lists
    ADD CONSTRAINT word_lists_pkey PRIMARY KEY (list_id);


--
-- TOC entry 4225 (class 2606 OID 30840)
-- Name: word_practice_sessions word_practice_sessions_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.word_practice_sessions
    ADD CONSTRAINT word_practice_sessions_pkey PRIMARY KEY (practice_id);


--
-- TOC entry 4221 (class 2606 OID 30823)
-- Name: words words_pkey; Type: CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.words
    ADD CONSTRAINT words_pkey PRIMARY KEY (word_id);


--
-- TOC entry 4464 (class 2606 OID 98116)
-- Name: classes classes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.classes
    ADD CONSTRAINT classes_pkey PRIMARY KEY (id);


--
-- TOC entry 4500 (class 2606 OID 98206)
-- Name: llm_audio_analyses llm_audio_analyses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.llm_audio_analyses
    ADD CONSTRAINT llm_audio_analyses_pkey PRIMARY KEY (id);


--
-- TOC entry 4504 (class 2606 OID 98230)
-- Name: llm_intake_queue llm_intake_queue_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.llm_intake_queue
    ADD CONSTRAINT llm_intake_queue_pkey PRIMARY KEY (id);


--
-- TOC entry 4493 (class 2606 OID 98190)
-- Name: llm_model_usage_daily llm_model_usage_daily_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.llm_model_usage_daily
    ADD CONSTRAINT llm_model_usage_daily_pkey PRIMARY KEY (model, date);


--
-- TOC entry 4475 (class 2606 OID 98139)
-- Name: llm_prompt_templates llm_prompt_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.llm_prompt_templates
    ADD CONSTRAINT llm_prompt_templates_pkey PRIMARY KEY (id);


--
-- TOC entry 4506 (class 2606 OID 98247)
-- Name: llm_rate_limits llm_rate_limits_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.llm_rate_limits
    ADD CONSTRAINT llm_rate_limits_pkey PRIMARY KEY (id);


--
-- TOC entry 4484 (class 2606 OID 98162)
-- Name: llm_request_attempts llm_request_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.llm_request_attempts
    ADD CONSTRAINT llm_request_attempts_pkey PRIMARY KEY (id);


--
-- TOC entry 4489 (class 2606 OID 98179)
-- Name: llm_request_events llm_request_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.llm_request_events
    ADD CONSTRAINT llm_request_events_pkey PRIMARY KEY (id);


--
-- TOC entry 4481 (class 2606 OID 98151)
-- Name: llm_requests llm_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.llm_requests
    ADD CONSTRAINT llm_requests_pkey PRIMARY KEY (id);


--
-- TOC entry 4486 (class 2606 OID 98171)
-- Name: llm_responses llm_responses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.llm_responses
    ADD CONSTRAINT llm_responses_pkey PRIMARY KEY (request_id);


--
-- TOC entry 4513 (class 2606 OID 98271)
-- Name: llm_system_health llm_system_health_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.llm_system_health
    ADD CONSTRAINT llm_system_health_pkey PRIMARY KEY (id);


--
-- TOC entry 4491 (class 2606 OID 98185)
-- Name: llm_user_usage_daily llm_user_usage_daily_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.llm_user_usage_daily
    ADD CONSTRAINT llm_user_usage_daily_pkey PRIMARY KEY (user_id, date);


--
-- TOC entry 4473 (class 2606 OID 98131)
-- Name: llm_users llm_users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.llm_users
    ADD CONSTRAINT llm_users_pkey PRIMARY KEY (id);


--
-- TOC entry 4462 (class 2606 OID 98095)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 4511 (class 2606 OID 98258)
-- Name: zoom_processing_queue zoom_processing_queue_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.zoom_processing_queue
    ADD CONSTRAINT zoom_processing_queue_pkey PRIMARY KEY (id);


--
-- TOC entry 4088 (class 2606 OID 30278)
-- Name: app_analytics app_analytics_pkey; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.app_analytics
    ADD CONSTRAINT app_analytics_pkey PRIMARY KEY (event_id);


--
-- TOC entry 4082 (class 2606 OID 30264)
-- Name: app_users app_users_pkey; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.app_users
    ADD CONSTRAINT app_users_pkey PRIMARY KEY (id);


--
-- TOC entry 4095 (class 2606 OID 30295)
-- Name: billing_webhooks billing_webhooks_pkey; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.billing_webhooks
    ADD CONSTRAINT billing_webhooks_pkey PRIMARY KEY (webhook_id);


--
-- TOC entry 4102 (class 2606 OID 30312)
-- Name: dead_letter dead_letter_pkey; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.dead_letter
    ADD CONSTRAINT dead_letter_pkey PRIMARY KEY (id);


--
-- TOC entry 4379 (class 2606 OID 31406)
-- Name: llm_audio_analyses llm_audio_analyses_pkey; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.llm_audio_analyses
    ADD CONSTRAINT llm_audio_analyses_pkey PRIMARY KEY (id);


--
-- TOC entry 4389 (class 2606 OID 31420)
-- Name: llm_intake_queue llm_intake_queue_pkey; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.llm_intake_queue
    ADD CONSTRAINT llm_intake_queue_pkey PRIMARY KEY (id);


--
-- TOC entry 4400 (class 2606 OID 31434)
-- Name: llm_request_attempts llm_request_attempts_pkey; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.llm_request_attempts
    ADD CONSTRAINT llm_request_attempts_pkey PRIMARY KEY (id);


--
-- TOC entry 4408 (class 2606 OID 31448)
-- Name: llm_request_events llm_request_events_pkey; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.llm_request_events
    ADD CONSTRAINT llm_request_events_pkey PRIMARY KEY (id);


--
-- TOC entry 4356 (class 2606 OID 31378)
-- Name: llm_requests llm_requests_pkey; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.llm_requests
    ADD CONSTRAINT llm_requests_pkey PRIMARY KEY (id);


--
-- TOC entry 4366 (class 2606 OID 31392)
-- Name: llm_responses llm_responses_pkey; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.llm_responses
    ADD CONSTRAINT llm_responses_pkey PRIMARY KEY (id);


--
-- TOC entry 4518 (class 2606 OID 128806)
-- Name: student_error_history student_error_history_pkey; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.student_error_history
    ADD CONSTRAINT student_error_history_pkey PRIMARY KEY (id);


--
-- TOC entry 4520 (class 2606 OID 128808)
-- Name: student_error_history student_error_history_student_id_error_type_key; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.student_error_history
    ADD CONSTRAINT student_error_history_student_id_error_type_key UNIQUE (student_id, error_type);


--
-- TOC entry 4525 (class 2606 OID 128820)
-- Name: student_progress_timeseries student_progress_timeseries_pkey; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.student_progress_timeseries
    ADD CONSTRAINT student_progress_timeseries_pkey PRIMARY KEY (id);


--
-- TOC entry 4527 (class 2606 OID 128822)
-- Name: student_progress_timeseries student_progress_timeseries_student_id_analysis_id_key; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.student_progress_timeseries
    ADD CONSTRAINT student_progress_timeseries_student_id_analysis_id_key UNIQUE (student_id, analysis_id);


--
-- TOC entry 4093 (class 2606 OID 30280)
-- Name: app_analytics uq_raw_app_analytics_idem; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.app_analytics
    ADD CONSTRAINT uq_raw_app_analytics_idem UNIQUE (idempotency_key);


--
-- TOC entry 4086 (class 2606 OID 30266)
-- Name: app_users uq_raw_app_users_idem; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.app_users
    ADD CONSTRAINT uq_raw_app_users_idem UNIQUE (idempotency_key);


--
-- TOC entry 4402 (class 2606 OID 31436)
-- Name: llm_request_attempts uq_raw_llm_attempts_idem; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.llm_request_attempts
    ADD CONSTRAINT uq_raw_llm_attempts_idem UNIQUE (idempotency_key);


--
-- TOC entry 4381 (class 2606 OID 31408)
-- Name: llm_audio_analyses uq_raw_llm_audio_idem; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.llm_audio_analyses
    ADD CONSTRAINT uq_raw_llm_audio_idem UNIQUE (idempotency_key);


--
-- TOC entry 4410 (class 2606 OID 31450)
-- Name: llm_request_events uq_raw_llm_events_idem; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.llm_request_events
    ADD CONSTRAINT uq_raw_llm_events_idem UNIQUE (idempotency_key);


--
-- TOC entry 4391 (class 2606 OID 31422)
-- Name: llm_intake_queue uq_raw_llm_intake_idem; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.llm_intake_queue
    ADD CONSTRAINT uq_raw_llm_intake_idem UNIQUE (idempotency_key);


--
-- TOC entry 4358 (class 2606 OID 31380)
-- Name: llm_requests uq_raw_llm_requests_idem; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.llm_requests
    ADD CONSTRAINT uq_raw_llm_requests_idem UNIQUE (idempotency_key);


--
-- TOC entry 4368 (class 2606 OID 31394)
-- Name: llm_responses uq_raw_llm_responses_idem; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.llm_responses
    ADD CONSTRAINT uq_raw_llm_responses_idem UNIQUE (idempotency_key);


--
-- TOC entry 4100 (class 2606 OID 30297)
-- Name: billing_webhooks uq_raw_webhooks_idem; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.billing_webhooks
    ADD CONSTRAINT uq_raw_webhooks_idem UNIQUE (idempotency_key);


--
-- TOC entry 4341 (class 2606 OID 31553)
-- Name: zoom_webhook_request uq_raw_zoom_session_uuid; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.zoom_webhook_request
    ADD CONSTRAINT uq_raw_zoom_session_uuid UNIQUE (session_uuid);


--
-- TOC entry 4343 (class 2606 OID 97988)
-- Name: zoom_webhook_request uq_zoom_webhook_idempotency; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.zoom_webhook_request
    ADD CONSTRAINT uq_zoom_webhook_idempotency UNIQUE (idempotency_key);


--
-- TOC entry 4345 (class 2606 OID 31362)
-- Name: zoom_webhook_request zoom_webhook_request_pkey; Type: CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.zoom_webhook_request
    ADD CONSTRAINT zoom_webhook_request_pkey PRIMARY KEY (id);


--
-- TOC entry 4293 (class 2606 OID 31214)
-- Name: revenue_snapshot revenue_snapshot_pkey; Type: CONSTRAINT; Schema: serve; Owner: postgres
--

ALTER TABLE ONLY serve.revenue_snapshot
    ADD CONSTRAINT revenue_snapshot_pkey PRIMARY KEY (snapshot_date);


--
-- TOC entry 4427 (class 2606 OID 31517)
-- Name: student_ai_profile student_ai_profile_pkey; Type: CONSTRAINT; Schema: serve; Owner: postgres
--

ALTER TABLE ONLY serve.student_ai_profile
    ADD CONSTRAINT student_ai_profile_pkey PRIMARY KEY (student_id);


--
-- TOC entry 4284 (class 2606 OID 31156)
-- Name: student_gamification_profile student_gamification_profile_pkey; Type: CONSTRAINT; Schema: serve; Owner: postgres
--

ALTER TABLE ONLY serve.student_gamification_profile
    ADD CONSTRAINT student_gamification_profile_pkey PRIMARY KEY (student_id);


--
-- TOC entry 4288 (class 2606 OID 31172)
-- Name: student_health_monetization student_health_monetization_pkey; Type: CONSTRAINT; Schema: serve; Owner: postgres
--

ALTER TABLE ONLY serve.student_health_monetization
    ADD CONSTRAINT student_health_monetization_pkey PRIMARY KEY (student_id);


--
-- TOC entry 4281 (class 2606 OID 31138)
-- Name: student_mastery_profile student_mastery_profile_pkey; Type: CONSTRAINT; Schema: serve; Owner: postgres
--

ALTER TABLE ONLY serve.student_mastery_profile
    ADD CONSTRAINT student_mastery_profile_pkey PRIMARY KEY (student_id);


--
-- TOC entry 4291 (class 2606 OID 31191)
-- Name: teacher_performance_profile teacher_performance_profile_pkey; Type: CONSTRAINT; Schema: serve; Owner: postgres
--

ALTER TABLE ONLY serve.teacher_performance_profile
    ADD CONSTRAINT teacher_performance_profile_pkey PRIMARY KEY (teacher_id);


--
-- TOC entry 4451 (class 1259 OID 31774)
-- Name: idx_evt_campaigns_channel; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_campaigns_channel ON analytics.campaigns USING btree (channel);


--
-- TOC entry 4452 (class 1259 OID 31775)
-- Name: idx_evt_campaigns_launched; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_campaigns_launched ON analytics.campaigns USING btree (launched_at DESC);


--
-- TOC entry 4453 (class 1259 OID 31773)
-- Name: idx_evt_campaigns_type; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_campaigns_type ON analytics.campaigns USING btree (campaign_type, launched_at DESC);


--
-- TOC entry 4300 (class 1259 OID 31238)
-- Name: idx_evt_class_student; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_class_student ON analytics.class_facts USING btree (student_id, occurred_at DESC);


--
-- TOC entry 4301 (class 1259 OID 31239)
-- Name: idx_evt_class_teacher; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_class_teacher ON analytics.class_facts USING btree (teacher_id, occurred_at DESC);


--
-- TOC entry 4313 (class 1259 OID 31275)
-- Name: idx_evt_game_student; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_game_student ON analytics.gamification_facts USING btree (student_id, occurred_at DESC);


--
-- TOC entry 4314 (class 1259 OID 31276)
-- Name: idx_evt_game_type; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_game_type ON analytics.gamification_facts USING btree (event_type, occurred_at DESC);


--
-- TOC entry 4330 (class 1259 OID 31336)
-- Name: idx_evt_intervention_student; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_intervention_student ON analytics.intervention_facts USING btree (student_id, occurred_at DESC);


--
-- TOC entry 4331 (class 1259 OID 31337)
-- Name: idx_evt_intervention_type; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_intervention_type ON analytics.intervention_facts USING btree (intervention_type, outcome);


--
-- TOC entry 4454 (class 1259 OID 31802)
-- Name: idx_evt_leads_agent; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_leads_agent ON analytics.leads USING btree (assigned_agent_id, funnel_stage);


--
-- TOC entry 4455 (class 1259 OID 31806)
-- Name: idx_evt_leads_campaign; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_leads_campaign ON analytics.leads USING btree (campaign_id) WHERE (campaign_id IS NOT NULL);


--
-- TOC entry 4456 (class 1259 OID 31804)
-- Name: idx_evt_leads_source; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_leads_source ON analytics.leads USING btree (source, funnel_stage);


--
-- TOC entry 4457 (class 1259 OID 31803)
-- Name: idx_evt_leads_stage; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_leads_stage ON analytics.leads USING btree (funnel_stage, created_at DESC);


--
-- TOC entry 4458 (class 1259 OID 31805)
-- Name: idx_evt_leads_student; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_leads_student ON analytics.leads USING btree (converted_student_id) WHERE (converted_student_id IS NOT NULL);


--
-- TOC entry 4294 (class 1259 OID 31225)
-- Name: idx_evt_lifecycle_student; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_lifecycle_student ON analytics.student_lifecycle USING btree (student_id, occurred_at DESC);


--
-- TOC entry 4295 (class 1259 OID 31226)
-- Name: idx_evt_lifecycle_type; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_lifecycle_type ON analytics.student_lifecycle USING btree (event_type, occurred_at DESC);


--
-- TOC entry 4428 (class 1259 OID 31535)
-- Name: idx_evt_llm_student; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_llm_student ON analytics.llm_facts USING btree (student_id, occurred_at DESC);


--
-- TOC entry 4429 (class 1259 OID 31536)
-- Name: idx_evt_llm_teacher; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_llm_teacher ON analytics.llm_facts USING btree (teacher_id, occurred_at DESC);


--
-- TOC entry 4430 (class 1259 OID 31537)
-- Name: idx_evt_llm_type; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_llm_type ON analytics.llm_facts USING btree (event_type, occurred_at DESC);


--
-- TOC entry 4443 (class 1259 OID 31757)
-- Name: idx_evt_observations_class; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_observations_class ON analytics.teacher_observations USING btree (class_id);


--
-- TOC entry 4444 (class 1259 OID 31758)
-- Name: idx_evt_observations_engage; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_observations_engage ON analytics.teacher_observations USING btree (engagement_level, occurred_at DESC);


--
-- TOC entry 4445 (class 1259 OID 31756)
-- Name: idx_evt_observations_student; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_observations_student ON analytics.teacher_observations USING btree (student_id, occurred_at DESC);


--
-- TOC entry 4446 (class 1259 OID 31755)
-- Name: idx_evt_observations_teacher; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_observations_teacher ON analytics.teacher_observations USING btree (teacher_id, occurred_at DESC);


--
-- TOC entry 4302 (class 1259 OID 31252)
-- Name: idx_evt_payment_date; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_payment_date ON analytics.payment_facts USING btree (occurred_at DESC);


--
-- TOC entry 4303 (class 1259 OID 31250)
-- Name: idx_evt_payment_student; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_payment_student ON analytics.payment_facts USING btree (student_id, occurred_at DESC);


--
-- TOC entry 4304 (class 1259 OID 31251)
-- Name: idx_evt_payment_type; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_payment_type ON analytics.payment_facts USING btree (event_type, occurred_at DESC);


--
-- TOC entry 4318 (class 1259 OID 31299)
-- Name: idx_evt_referral_referrer; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_referral_referrer ON analytics.referral_facts USING btree (referrer_id, occurred_at DESC);


--
-- TOC entry 4319 (class 1259 OID 31300)
-- Name: idx_evt_referral_type; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_referral_type ON analytics.referral_facts USING btree (event_type, occurred_at DESC);


--
-- TOC entry 4326 (class 1259 OID 31325)
-- Name: idx_evt_risk_level; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_risk_level ON analytics.risk_facts USING btree (risk_level, occurred_at DESC);


--
-- TOC entry 4327 (class 1259 OID 31324)
-- Name: idx_evt_risk_student; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_risk_student ON analytics.risk_facts USING btree (student_id, occurred_at DESC);


--
-- TOC entry 4307 (class 1259 OID 31263)
-- Name: idx_evt_sub_student; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_sub_student ON analytics.subscription_facts USING btree (student_id, occurred_at DESC);


--
-- TOC entry 4308 (class 1259 OID 31264)
-- Name: idx_evt_sub_type; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_sub_type ON analytics.subscription_facts USING btree (event_type, occurred_at DESC);


--
-- TOC entry 4322 (class 1259 OID 31311)
-- Name: idx_evt_teacher_teacher; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_teacher_teacher ON analytics.teacher_facts USING btree (teacher_id, occurred_at DESC);


--
-- TOC entry 4323 (class 1259 OID 31312)
-- Name: idx_evt_teacher_type; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_teacher_type ON analytics.teacher_facts USING btree (event_type, occurred_at DESC);


--
-- TOC entry 4437 (class 1259 OID 31742)
-- Name: idx_evt_touchpoints_class; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_touchpoints_class ON analytics.student_touchpoints USING btree (class_id) WHERE (class_id IS NOT NULL);


--
-- TOC entry 4438 (class 1259 OID 31743)
-- Name: idx_evt_touchpoints_sentiment; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_touchpoints_sentiment ON analytics.student_touchpoints USING btree (sentiment_score DESC) WHERE (sentiment_score IS NOT NULL);


--
-- TOC entry 4439 (class 1259 OID 31740)
-- Name: idx_evt_touchpoints_student; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_touchpoints_student ON analytics.student_touchpoints USING btree (student_id, occurred_at DESC);


--
-- TOC entry 4440 (class 1259 OID 31741)
-- Name: idx_evt_touchpoints_type; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_touchpoints_type ON analytics.student_touchpoints USING btree (type, occurred_at DESC);


--
-- TOC entry 4315 (class 1259 OID 31288)
-- Name: idx_evt_vocab_student; Type: INDEX; Schema: analytics; Owner: postgres
--

CREATE INDEX idx_evt_vocab_student ON analytics.vocabulary_facts USING btree (student_id, occurred_at DESC);


--
-- TOC entry 4208 (class 1259 OID 30770)
-- Name: idx_achievements_student; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_achievements_student ON clean.achievements USING btree (student_id, earned_at DESC);


--
-- TOC entry 4209 (class 1259 OID 30771)
-- Name: idx_achievements_type; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_achievements_type ON clean.achievements USING btree (achievement_type);


--
-- TOC entry 4194 (class 1259 OID 30694)
-- Name: idx_app_sessions_student; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_app_sessions_student ON clean.app_sessions USING btree (student_id, started_at DESC);


--
-- TOC entry 4130 (class 1259 OID 30418)
-- Name: idx_availability_teacher; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_availability_teacher ON clean.teacher_availability USING btree (teacher_id, is_active);


--
-- TOC entry 4252 (class 1259 OID 30996)
-- Name: idx_churn_risk_level; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_churn_risk_level ON clean.churn_risk_scores USING btree (risk_level, assessed_at DESC);


--
-- TOC entry 4253 (class 1259 OID 30995)
-- Name: idx_churn_risk_student; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_churn_risk_student ON clean.churn_risk_scores USING btree (student_id, assessed_at DESC);


--
-- TOC entry 4181 (class 1259 OID 30636)
-- Name: idx_class_analytics_class; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_class_analytics_class ON clean.class_analytics USING btree (class_id, event_type);


--
-- TOC entry 4182 (class 1259 OID 30637)
-- Name: idx_class_analytics_created; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_class_analytics_created ON clean.class_analytics USING btree (created_at DESC);


--
-- TOC entry 4170 (class 1259 OID 114222)
-- Name: idx_classes_meeting; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_classes_meeting ON clean.classes USING btree (zoom_meeting_uuid, meeting_start);


--
-- TOC entry 4171 (class 1259 OID 30614)
-- Name: idx_classes_start; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_classes_start ON clean.classes USING btree (meeting_start DESC);


--
-- TOC entry 4172 (class 1259 OID 30615)
-- Name: idx_classes_status; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_classes_status ON clean.classes USING btree (lifecycle_status);


--
-- TOC entry 4173 (class 1259 OID 30612)
-- Name: idx_classes_student; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_classes_student ON clean.classes USING btree (student_id, lifecycle_status);


--
-- TOC entry 4174 (class 1259 OID 30613)
-- Name: idx_classes_teacher; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_classes_teacher ON clean.classes USING btree (teacher_id, lifecycle_status);


--
-- TOC entry 4411 (class 1259 OID 31478)
-- Name: idx_cln_llm_analysis_class; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_cln_llm_analysis_class ON clean.llm_lesson_analyses USING btree (class_id);


--
-- TOC entry 4412 (class 1259 OID 31479)
-- Name: idx_cln_llm_analysis_status; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_cln_llm_analysis_status ON clean.llm_lesson_analyses USING btree (status);


--
-- TOC entry 4413 (class 1259 OID 31477)
-- Name: idx_cln_llm_analysis_student; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_cln_llm_analysis_student ON clean.llm_lesson_analyses USING btree (student_id, created_at DESC);


--
-- TOC entry 4418 (class 1259 OID 31493)
-- Name: idx_cln_llm_usage_date; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_cln_llm_usage_date ON clean.llm_model_usage_daily USING btree (metric_date DESC);


--
-- TOC entry 4191 (class 1259 OID 30678)
-- Name: idx_daily_activity_date; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_daily_activity_date ON clean.daily_activity USING btree (activity_date DESC);


--
-- TOC entry 4143 (class 1259 OID 30456)
-- Name: idx_families_parent; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_families_parent ON clean.families USING btree (parent_student_id);


--
-- TOC entry 4144 (class 1259 OID 30457)
-- Name: idx_families_status; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_families_status ON clean.families USING btree (family_status);


--
-- TOC entry 4147 (class 1259 OID 30483)
-- Name: idx_family_children_family; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_family_children_family ON clean.family_children USING btree (family_id);


--
-- TOC entry 4148 (class 1259 OID 30486)
-- Name: idx_family_children_payment; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_family_children_payment ON clean.family_children USING btree (next_payment_date);


--
-- TOC entry 4149 (class 1259 OID 30485)
-- Name: idx_family_children_status; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_family_children_status ON clean.family_children USING btree (status);


--
-- TOC entry 4150 (class 1259 OID 30484)
-- Name: idx_family_children_student; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_family_children_student ON clean.family_children USING btree (student_id);


--
-- TOC entry 4275 (class 1259 OID 31127)
-- Name: idx_fraud_logs_referrer; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_fraud_logs_referrer ON clean.referral_fraud_logs USING btree (referrer_id);


--
-- TOC entry 4276 (class 1259 OID 31128)
-- Name: idx_fraud_logs_type; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_fraud_logs_type ON clean.referral_fraud_logs USING btree (fraud_type, is_blocked);


--
-- TOC entry 4204 (class 1259 OID 30753)
-- Name: idx_game_sessions_game; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_game_sessions_game ON clean.game_sessions USING btree (game_id);


--
-- TOC entry 4205 (class 1259 OID 30752)
-- Name: idx_game_sessions_student; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_game_sessions_student ON clean.game_sessions USING btree (student_id, played_at DESC);


--
-- TOC entry 4201 (class 1259 OID 30729)
-- Name: idx_games_student; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_games_student ON clean.games USING btree (student_id, game_type);


--
-- TOC entry 4135 (class 1259 OID 30438)
-- Name: idx_holidays_date; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_holidays_date ON clean.teacher_holidays USING btree (holiday_date);


--
-- TOC entry 4136 (class 1259 OID 30437)
-- Name: idx_holidays_teacher; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_holidays_teacher ON clean.teacher_holidays USING btree (teacher_id);


--
-- TOC entry 4254 (class 1259 OID 31024)
-- Name: idx_interventions_outcome; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_interventions_outcome ON clean.retention_interventions USING btree (outcome);


--
-- TOC entry 4255 (class 1259 OID 31023)
-- Name: idx_interventions_student; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_interventions_student ON clean.retention_interventions USING btree (student_id, actioned_at DESC);


--
-- TOC entry 4183 (class 1259 OID 30662)
-- Name: idx_lesson_attempts_cefr; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_lesson_attempts_cefr ON clean.lesson_attempts USING btree (cefr_detected);


--
-- TOC entry 4184 (class 1259 OID 30661)
-- Name: idx_lesson_attempts_student; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_lesson_attempts_student ON clean.lesson_attempts USING btree (student_id, completed_at DESC);


--
-- TOC entry 4195 (class 1259 OID 30712)
-- Name: idx_notifications_channel; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_notifications_channel ON clean.notifications_log USING btree (channel, sent_at DESC);


--
-- TOC entry 4196 (class 1259 OID 30711)
-- Name: idx_notifications_student; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_notifications_student ON clean.notifications_log USING btree (student_id, sent_at DESC);


--
-- TOC entry 4226 (class 1259 OID 30899)
-- Name: idx_payment_txn_context; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_payment_txn_context ON clean.payment_transactions USING btree (transaction_context, status);


--
-- TOC entry 4227 (class 1259 OID 30898)
-- Name: idx_payment_txn_family; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_payment_txn_family ON clean.payment_transactions USING btree (family_id);


--
-- TOC entry 4228 (class 1259 OID 30900)
-- Name: idx_payment_txn_payplus; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_payment_txn_payplus ON clean.payment_transactions USING btree (payplus_transaction_uid);


--
-- TOC entry 4229 (class 1259 OID 30901)
-- Name: idx_payment_txn_proc; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_payment_txn_proc ON clean.payment_transactions USING btree (processed_at DESC);


--
-- TOC entry 4230 (class 1259 OID 30896)
-- Name: idx_payment_txn_student; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_payment_txn_student ON clean.payment_transactions USING btree (student_id, status);


--
-- TOC entry 4231 (class 1259 OID 30897)
-- Name: idx_payment_txn_sub; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_payment_txn_sub ON clean.payment_transactions USING btree (subscription_id);


--
-- TOC entry 4246 (class 1259 OID 30977)
-- Name: idx_payout_txn_payslip; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_payout_txn_payslip ON clean.teacher_payout_transactions USING btree (payslip_id);


--
-- TOC entry 4247 (class 1259 OID 30978)
-- Name: idx_payout_txn_teacher; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_payout_txn_teacher ON clean.teacher_payout_transactions USING btree (teacher_id, status);


--
-- TOC entry 4240 (class 1259 OID 30954)
-- Name: idx_payslips_period; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_payslips_period ON clean.teacher_payslips USING btree (period_start, status);


--
-- TOC entry 4241 (class 1259 OID 30953)
-- Name: idx_payslips_teacher; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_payslips_teacher ON clean.teacher_payslips USING btree (teacher_id, status);


--
-- TOC entry 4210 (class 1259 OID 30788)
-- Name: idx_points_ledger_source; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_points_ledger_source ON clean.points_ledger USING btree (source_type, source_id);


--
-- TOC entry 4211 (class 1259 OID 30787)
-- Name: idx_points_ledger_student; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_points_ledger_student ON clean.points_ledger USING btree (student_id, created_at DESC);


--
-- TOC entry 4121 (class 1259 OID 30373)
-- Name: idx_questionnaire_student; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_questionnaire_student ON clean.questionnaire_responses USING btree (student_id);


--
-- TOC entry 4271 (class 1259 OID 31093)
-- Name: idx_referral_rewards_referral; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_referral_rewards_referral ON clean.referral_rewards USING btree (referral_id);


--
-- TOC entry 4272 (class 1259 OID 31094)
-- Name: idx_referral_rewards_student; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_referral_rewards_student ON clean.referral_rewards USING btree (student_id, status);


--
-- TOC entry 4262 (class 1259 OID 31065)
-- Name: idx_referrals_code; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_referrals_code ON clean.referrals USING btree (referral_code);


--
-- TOC entry 4263 (class 1259 OID 31064)
-- Name: idx_referrals_referee; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_referrals_referee ON clean.referrals USING btree (referee_id);


--
-- TOC entry 4264 (class 1259 OID 31063)
-- Name: idx_referrals_referrer; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_referrals_referrer ON clean.referrals USING btree (referrer_id, status);


--
-- TOC entry 4105 (class 1259 OID 30335)
-- Name: idx_students_active; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_students_active ON clean.students USING btree (last_active_at DESC);


--
-- TOC entry 4106 (class 1259 OID 30333)
-- Name: idx_students_cefr; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_students_cefr ON clean.students USING btree (cefr_level);


--
-- TOC entry 4107 (class 1259 OID 30334)
-- Name: idx_students_onboarding; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_students_onboarding ON clean.students USING btree (onboarding_step);


--
-- TOC entry 4108 (class 1259 OID 30332)
-- Name: idx_students_status; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_students_status ON clean.students USING btree (status);


--
-- TOC entry 4160 (class 1259 OID 30543)
-- Name: idx_sub_members_family; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_sub_members_family ON clean.subscription_members USING btree (family_id);


--
-- TOC entry 4161 (class 1259 OID 30542)
-- Name: idx_sub_members_student; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_sub_members_student ON clean.subscription_members USING btree (student_id, status);


--
-- TOC entry 4164 (class 1259 OID 30577)
-- Name: idx_sub_mods_effective; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_sub_mods_effective ON clean.subscription_modifications USING btree (effective_date, status);


--
-- TOC entry 4165 (class 1259 OID 30576)
-- Name: idx_sub_mods_sub; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_sub_mods_sub ON clean.subscription_modifications USING btree (subscription_id);


--
-- TOC entry 4153 (class 1259 OID 30516)
-- Name: idx_subscriptions_billing; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_subscriptions_billing ON clean.subscriptions USING btree (next_billing_date, status);


--
-- TOC entry 4154 (class 1259 OID 30515)
-- Name: idx_subscriptions_owner; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_subscriptions_owner ON clean.subscriptions USING btree (owner_student_id, status);


--
-- TOC entry 4155 (class 1259 OID 30517)
-- Name: idx_subscriptions_payplus; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_subscriptions_payplus ON clean.subscriptions USING btree (payplus_subscription_id);


--
-- TOC entry 4236 (class 1259 OID 30923)
-- Name: idx_teacher_earnings_class; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_teacher_earnings_class ON clean.teacher_earning_analytics USING btree (class_id);


--
-- TOC entry 4237 (class 1259 OID 30922)
-- Name: idx_teacher_earnings_teacher; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_teacher_earnings_teacher ON clean.teacher_earning_analytics USING btree (teacher_id, earned_at DESC);


--
-- TOC entry 4126 (class 1259 OID 30394)
-- Name: idx_teacher_rec_questionnaire; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_teacher_rec_questionnaire ON clean.teacher_recommendations USING btree (questionnaire_id);


--
-- TOC entry 4127 (class 1259 OID 30395)
-- Name: idx_teacher_rec_teacher; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_teacher_rec_teacher ON clean.teacher_recommendations USING btree (teacher_id);


--
-- TOC entry 4114 (class 1259 OID 30354)
-- Name: idx_teachers_rating; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_teachers_rating ON clean.teachers USING btree (avg_rating DESC);


--
-- TOC entry 4115 (class 1259 OID 30353)
-- Name: idx_teachers_status; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_teachers_status ON clean.teachers USING btree (status);


--
-- TOC entry 4214 (class 1259 OID 30808)
-- Name: idx_word_lists_favorite; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_word_lists_favorite ON clean.word_lists USING btree (student_id, is_favorite);


--
-- TOC entry 4215 (class 1259 OID 30807)
-- Name: idx_word_lists_student; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_word_lists_student ON clean.word_lists USING btree (student_id);


--
-- TOC entry 4222 (class 1259 OID 30852)
-- Name: idx_word_practice_list; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_word_practice_list ON clean.word_practice_sessions USING btree (list_id);


--
-- TOC entry 4223 (class 1259 OID 30851)
-- Name: idx_word_practice_student; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_word_practice_student ON clean.word_practice_sessions USING btree (student_id, practiced_at DESC);


--
-- TOC entry 4218 (class 1259 OID 30830)
-- Name: idx_words_favorite; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_words_favorite ON clean.words USING btree (list_id, is_favorite);


--
-- TOC entry 4219 (class 1259 OID 30829)
-- Name: idx_words_list; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE INDEX idx_words_list ON clean.words USING btree (list_id);


--
-- TOC entry 4109 (class 1259 OID 103175)
-- Name: students_email_unique; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE UNIQUE INDEX students_email_unique ON clean.students USING btree (email) WHERE (email IS NOT NULL);


--
-- TOC entry 4116 (class 1259 OID 103176)
-- Name: teachers_email_unique; Type: INDEX; Schema: clean; Owner: postgres
--

CREATE UNIQUE INDEX teachers_email_unique ON clean.teachers USING btree (email) WHERE (email IS NOT NULL);


--
-- TOC entry 4494 (class 1259 OID 98209)
-- Name: idx_audio_analyses_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_audio_analyses_created_at ON public.llm_audio_analyses USING btree (created_at);


--
-- TOC entry 4495 (class 1259 OID 98211)
-- Name: idx_audio_analyses_engagement_level; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_audio_analyses_engagement_level ON public.llm_audio_analyses USING btree (engagement_level);


--
-- TOC entry 4496 (class 1259 OID 98207)
-- Name: idx_audio_analyses_job_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_audio_analyses_job_id ON public.llm_audio_analyses USING btree (job_id);


--
-- TOC entry 4497 (class 1259 OID 98210)
-- Name: idx_audio_analyses_level; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_audio_analyses_level ON public.llm_audio_analyses USING btree (level);


--
-- TOC entry 4498 (class 1259 OID 98208)
-- Name: idx_audio_analyses_zoom_meeting_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_audio_analyses_zoom_meeting_id ON public.llm_audio_analyses USING btree (zoom_meeting_id);


--
-- TOC entry 4465 (class 1259 OID 98121)
-- Name: idx_batch_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_batch_id ON public.classes USING btree (batch_id);


--
-- TOC entry 4466 (class 1259 OID 98123)
-- Name: idx_classes_teacher_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_classes_teacher_status ON public.classes USING btree (teacher_id, status);


--
-- TOC entry 4501 (class 1259 OID 98232)
-- Name: idx_intake_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_intake_created_at ON public.llm_intake_queue USING btree (created_at);


--
-- TOC entry 4502 (class 1259 OID 98231)
-- Name: idx_intake_status_priority; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_intake_status_priority ON public.llm_intake_queue USING btree (status, priority DESC, created_at);


--
-- TOC entry 4467 (class 1259 OID 98119)
-- Name: idx_meeting_start; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_meeting_start ON public.classes USING btree (meeting_start);


--
-- TOC entry 4482 (class 1259 OID 98163)
-- Name: idx_request_attempts_request_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_request_attempts_request_id ON public.llm_request_attempts USING btree (request_id);


--
-- TOC entry 4487 (class 1259 OID 98180)
-- Name: idx_request_events_request_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_request_events_request_id ON public.llm_request_events USING btree (request_id);


--
-- TOC entry 4476 (class 1259 OID 98154)
-- Name: idx_requests_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_requests_created_at ON public.llm_requests USING btree (created_at);


--
-- TOC entry 4477 (class 1259 OID 98304)
-- Name: idx_requests_ik_null_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_requests_ik_null_user ON public.llm_requests USING btree (idempotency_key) WHERE (user_id IS NULL);


--
-- TOC entry 4478 (class 1259 OID 98153)
-- Name: idx_requests_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_requests_status ON public.llm_requests USING btree (status);


--
-- TOC entry 4479 (class 1259 OID 98152)
-- Name: idx_requests_user_id_idempotency_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_requests_user_id_idempotency_key ON public.llm_requests USING btree (user_id, idempotency_key);


--
-- TOC entry 4468 (class 1259 OID 98120)
-- Name: idx_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_status ON public.classes USING btree (status);


--
-- TOC entry 4469 (class 1259 OID 98117)
-- Name: idx_student_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_student_id ON public.classes USING btree (student_id);


--
-- TOC entry 4470 (class 1259 OID 98118)
-- Name: idx_teacher_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_teacher_id ON public.classes USING btree (teacher_id);


--
-- TOC entry 4471 (class 1259 OID 98122)
-- Name: idx_zoom_meeting_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_zoom_meeting_id ON public.classes USING btree (zoom_meeting_id);


--
-- TOC entry 4507 (class 1259 OID 98261)
-- Name: idx_zpq_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_zpq_created_at ON public.zoom_processing_queue USING btree (created_at);


--
-- TOC entry 4508 (class 1259 OID 98260)
-- Name: idx_zpq_meeting_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_zpq_meeting_id ON public.zoom_processing_queue USING btree (meeting_id);


--
-- TOC entry 4509 (class 1259 OID 98259)
-- Name: unique_session_uuid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX unique_session_uuid ON public.zoom_processing_queue USING btree (session_uuid);


--
-- TOC entry 4080 (class 1259 OID 103174)
-- Name: app_users_idempotency_key_unique; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE UNIQUE INDEX app_users_idempotency_key_unique ON raw.app_users USING btree (idempotency_key);


--
-- TOC entry 4103 (class 1259 OID 30314)
-- Name: idx_dead_letter_created; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_dead_letter_created ON raw.dead_letter USING btree (created_at DESC);


--
-- TOC entry 4104 (class 1259 OID 30313)
-- Name: idx_dead_letter_source; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_dead_letter_source ON raw.dead_letter USING btree (source_table, resolved);


--
-- TOC entry 4089 (class 1259 OID 30282)
-- Name: idx_raw_analytics_entity; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_analytics_entity ON raw.app_analytics USING btree (entity_id);


--
-- TOC entry 4090 (class 1259 OID 30283)
-- Name: idx_raw_analytics_loaded; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_analytics_loaded ON raw.app_analytics USING btree (_etl_loaded_at);


--
-- TOC entry 4091 (class 1259 OID 30281)
-- Name: idx_raw_analytics_type; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_analytics_type ON raw.app_analytics USING btree (event_type);


--
-- TOC entry 4392 (class 1259 OID 87415)
-- Name: idx_raw_llm_attempts_ended; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_attempts_ended ON raw.llm_request_attempts USING btree (ended_at);


--
-- TOC entry 4393 (class 1259 OID 31438)
-- Name: idx_raw_llm_attempts_loaded; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_attempts_loaded ON raw.llm_request_attempts USING btree (_etl_loaded_at);


--
-- TOC entry 4394 (class 1259 OID 31820)
-- Name: idx_raw_llm_attempts_model; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_attempts_model ON raw.llm_request_attempts USING btree (model);


--
-- TOC entry 4395 (class 1259 OID 31819)
-- Name: idx_raw_llm_attempts_request; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_attempts_request ON raw.llm_request_attempts USING btree (request_id);


--
-- TOC entry 4396 (class 1259 OID 31841)
-- Name: idx_raw_llm_attempts_source; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_attempts_source ON raw.llm_request_attempts USING btree (source_id);


--
-- TOC entry 4397 (class 1259 OID 87414)
-- Name: idx_raw_llm_attempts_started; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_attempts_started ON raw.llm_request_attempts USING btree (started_at);


--
-- TOC entry 4398 (class 1259 OID 31821)
-- Name: idx_raw_llm_attempts_status; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_attempts_status ON raw.llm_request_attempts USING btree (status);


--
-- TOC entry 4370 (class 1259 OID 87418)
-- Name: idx_raw_llm_audio_created; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_audio_created ON raw.llm_audio_analyses USING btree (created_at);


--
-- TOC entry 4371 (class 1259 OID 87417)
-- Name: idx_raw_llm_audio_job; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_audio_job ON raw.llm_audio_analyses USING btree (job_id);


--
-- TOC entry 4372 (class 1259 OID 31410)
-- Name: idx_raw_llm_audio_loaded; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_audio_loaded ON raw.llm_audio_analyses USING btree (_etl_loaded_at);


--
-- TOC entry 4373 (class 1259 OID 128793)
-- Name: idx_raw_llm_audio_meeting; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_audio_meeting ON raw.llm_audio_analyses USING btree (meeting_start);


--
-- TOC entry 4374 (class 1259 OID 31409)
-- Name: idx_raw_llm_audio_source; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_audio_source ON raw.llm_audio_analyses USING btree (source_id);


--
-- TOC entry 4375 (class 1259 OID 128791)
-- Name: idx_raw_llm_audio_student; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_audio_student ON raw.llm_audio_analyses USING btree (student_id);


--
-- TOC entry 4376 (class 1259 OID 128792)
-- Name: idx_raw_llm_audio_teacher; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_audio_teacher ON raw.llm_audio_analyses USING btree (teacher_id);


--
-- TOC entry 4377 (class 1259 OID 87416)
-- Name: idx_raw_llm_audio_zoom; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_audio_zoom ON raw.llm_audio_analyses USING btree (zoom_meeting_id);


--
-- TOC entry 4403 (class 1259 OID 31452)
-- Name: idx_raw_llm_events_loaded; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_events_loaded ON raw.llm_request_events USING btree (_etl_loaded_at);


--
-- TOC entry 4404 (class 1259 OID 31823)
-- Name: idx_raw_llm_events_request; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_events_request ON raw.llm_request_events USING btree (request_id);


--
-- TOC entry 4405 (class 1259 OID 31854)
-- Name: idx_raw_llm_events_source; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_events_source ON raw.llm_request_events USING btree (source_id);


--
-- TOC entry 4406 (class 1259 OID 31824)
-- Name: idx_raw_llm_events_type; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_events_type ON raw.llm_request_events USING btree (event_type);


--
-- TOC entry 4382 (class 1259 OID 31551)
-- Name: idx_raw_llm_intake_created; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_intake_created ON raw.llm_intake_queue USING btree (created_at DESC);


--
-- TOC entry 4383 (class 1259 OID 31424)
-- Name: idx_raw_llm_intake_loaded; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_intake_loaded ON raw.llm_intake_queue USING btree (_etl_loaded_at);


--
-- TOC entry 4384 (class 1259 OID 31818)
-- Name: idx_raw_llm_intake_request; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_intake_request ON raw.llm_intake_queue USING btree (request_id);


--
-- TOC entry 4385 (class 1259 OID 31423)
-- Name: idx_raw_llm_intake_source; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_intake_source ON raw.llm_intake_queue USING btree (source_id);


--
-- TOC entry 4386 (class 1259 OID 31550)
-- Name: idx_raw_llm_intake_status; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_intake_status ON raw.llm_intake_queue USING btree (status, _etl_loaded_at);


--
-- TOC entry 4387 (class 1259 OID 31817)
-- Name: idx_raw_llm_intake_zoom; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_intake_zoom ON raw.llm_intake_queue USING btree (zoom_meeting_id);


--
-- TOC entry 4346 (class 1259 OID 31546)
-- Name: idx_raw_llm_requests_class; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_requests_class ON raw.llm_requests USING btree (class_id);


--
-- TOC entry 4347 (class 1259 OID 31547)
-- Name: idx_raw_llm_requests_created; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_requests_created ON raw.llm_requests USING btree (created_at DESC);


--
-- TOC entry 4348 (class 1259 OID 31382)
-- Name: idx_raw_llm_requests_loaded; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_requests_loaded ON raw.llm_requests USING btree (_etl_loaded_at);


--
-- TOC entry 4349 (class 1259 OID 31812)
-- Name: idx_raw_llm_requests_model; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_requests_model ON raw.llm_requests USING btree (model);


--
-- TOC entry 4350 (class 1259 OID 79384)
-- Name: idx_raw_llm_requests_prompt; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_requests_prompt ON raw.llm_requests USING btree (prompt_template_id);


--
-- TOC entry 4351 (class 1259 OID 31825)
-- Name: idx_raw_llm_requests_source; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_requests_source ON raw.llm_requests USING btree (source_id);


--
-- TOC entry 4352 (class 1259 OID 31545)
-- Name: idx_raw_llm_requests_status; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_requests_status ON raw.llm_requests USING btree (status, _etl_loaded_at);


--
-- TOC entry 4353 (class 1259 OID 79383)
-- Name: idx_raw_llm_requests_user; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_requests_user ON raw.llm_requests USING btree (user_id);


--
-- TOC entry 4354 (class 1259 OID 31813)
-- Name: idx_raw_llm_requests_worker; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_requests_worker ON raw.llm_requests USING btree (worker_id);


--
-- TOC entry 4361 (class 1259 OID 87419)
-- Name: idx_raw_llm_responses_completed; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_responses_completed ON raw.llm_responses USING btree (completed_at);


--
-- TOC entry 4362 (class 1259 OID 31396)
-- Name: idx_raw_llm_responses_loaded; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_responses_loaded ON raw.llm_responses USING btree (_etl_loaded_at);


--
-- TOC entry 4363 (class 1259 OID 87413)
-- Name: idx_raw_llm_responses_request; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_responses_request ON raw.llm_responses USING btree (request_id);


--
-- TOC entry 4364 (class 1259 OID 31866)
-- Name: idx_raw_llm_responses_source; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_llm_responses_source ON raw.llm_responses USING btree (source_id);


--
-- TOC entry 4083 (class 1259 OID 30268)
-- Name: idx_raw_users_loaded; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_users_loaded ON raw.app_users USING btree (_etl_loaded_at);


--
-- TOC entry 4084 (class 1259 OID 30267)
-- Name: idx_raw_users_source; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_users_source ON raw.app_users USING btree (source_id);


--
-- TOC entry 4096 (class 1259 OID 30298)
-- Name: idx_raw_webhooks_proc; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_webhooks_proc ON raw.billing_webhooks USING btree (processed, _etl_loaded_at);


--
-- TOC entry 4097 (class 1259 OID 30300)
-- Name: idx_raw_webhooks_seq; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_webhooks_seq ON raw.billing_webhooks USING btree (payplus_sequence);


--
-- TOC entry 4098 (class 1259 OID 30299)
-- Name: idx_raw_webhooks_type; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_webhooks_type ON raw.billing_webhooks USING btree (event_type);


--
-- TOC entry 4334 (class 1259 OID 64992)
-- Name: idx_raw_zoom_created; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_zoom_created ON raw.zoom_webhook_request USING btree (created_at);


--
-- TOC entry 4335 (class 1259 OID 31368)
-- Name: idx_raw_zoom_loaded; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_zoom_loaded ON raw.zoom_webhook_request USING btree (_etl_loaded_at);


--
-- TOC entry 4336 (class 1259 OID 31366)
-- Name: idx_raw_zoom_meeting; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_zoom_meeting ON raw.zoom_webhook_request USING btree (meeting_id);


--
-- TOC entry 4337 (class 1259 OID 31367)
-- Name: idx_raw_zoom_processed; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_zoom_processed ON raw.zoom_webhook_request USING btree (processed, _etl_loaded_at);


--
-- TOC entry 4338 (class 1259 OID 31365)
-- Name: idx_raw_zoom_session; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_raw_zoom_session ON raw.zoom_webhook_request USING btree (session_uuid);


--
-- TOC entry 4514 (class 1259 OID 128810)
-- Name: idx_seh_error_type; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_seh_error_type ON raw.student_error_history USING btree (error_type);


--
-- TOC entry 4515 (class 1259 OID 128811)
-- Name: idx_seh_resolved; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_seh_resolved ON raw.student_error_history USING btree (student_id, resolved);


--
-- TOC entry 4516 (class 1259 OID 128809)
-- Name: idx_seh_student; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_seh_student ON raw.student_error_history USING btree (student_id);


--
-- TOC entry 4521 (class 1259 OID 128825)
-- Name: idx_spt_lesson_date; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_spt_lesson_date ON raw.student_progress_timeseries USING btree (lesson_date DESC);


--
-- TOC entry 4522 (class 1259 OID 128823)
-- Name: idx_spt_student_date; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_spt_student_date ON raw.student_progress_timeseries USING btree (student_id, lesson_date DESC);


--
-- TOC entry 4523 (class 1259 OID 128824)
-- Name: idx_spt_teacher_date; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_spt_teacher_date ON raw.student_progress_timeseries USING btree (teacher_id, lesson_date DESC);


--
-- TOC entry 4339 (class 1259 OID 109389)
-- Name: idx_zoom_recording_start; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE INDEX idx_zoom_recording_start ON raw.zoom_webhook_request USING btree (recording_start);


--
-- TOC entry 4359 (class 1259 OID 98537)
-- Name: uq_raw_llm_requests_ik_nulluser; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE UNIQUE INDEX uq_raw_llm_requests_ik_nulluser ON raw.llm_requests USING btree (idempotency_key) WHERE (user_id IS NULL);


--
-- TOC entry 4360 (class 1259 OID 98536)
-- Name: uq_raw_llm_requests_request_id; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE UNIQUE INDEX uq_raw_llm_requests_request_id ON raw.llm_requests USING btree (request_id);


--
-- TOC entry 4369 (class 1259 OID 98538)
-- Name: uq_raw_llm_responses_request_id; Type: INDEX; Schema: raw; Owner: postgres
--

CREATE UNIQUE INDEX uq_raw_llm_responses_request_id ON raw.llm_responses USING btree (request_id);


--
-- TOC entry 4282 (class 1259 OID 31162)
-- Name: idx_gamification_etl; Type: INDEX; Schema: serve; Owner: postgres
--

CREATE INDEX idx_gamification_etl ON serve.student_gamification_profile USING btree (_etl_updated_at DESC);


--
-- TOC entry 4285 (class 1259 OID 31179)
-- Name: idx_health_churn; Type: INDEX; Schema: serve; Owner: postgres
--

CREATE INDEX idx_health_churn ON serve.student_health_monetization USING btree (churn_risk_score DESC);


--
-- TOC entry 4286 (class 1259 OID 31178)
-- Name: idx_health_etl; Type: INDEX; Schema: serve; Owner: postgres
--

CREATE INDEX idx_health_etl ON serve.student_health_monetization USING btree (_etl_updated_at DESC);


--
-- TOC entry 4279 (class 1259 OID 31144)
-- Name: idx_mastery_etl; Type: INDEX; Schema: serve; Owner: postgres
--

CREATE INDEX idx_mastery_etl ON serve.student_mastery_profile USING btree (_etl_updated_at DESC);


--
-- TOC entry 4425 (class 1259 OID 31523)
-- Name: idx_srv_ai_profile_etl; Type: INDEX; Schema: serve; Owner: postgres
--

CREATE INDEX idx_srv_ai_profile_etl ON serve.student_ai_profile USING btree (_etl_updated_at DESC);


--
-- TOC entry 4289 (class 1259 OID 31197)
-- Name: idx_teacher_perf_etl; Type: INDEX; Schema: serve; Owner: postgres
--

CREATE INDEX idx_teacher_perf_etl ON serve.teacher_performance_profile USING btree (_etl_updated_at DESC);


--
-- TOC entry 4600 (class 2620 OID 98276)
-- Name: llm_intake_queue trg_intake_dedup; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_intake_dedup BEFORE INSERT ON public.llm_intake_queue FOR EACH ROW EXECUTE FUNCTION public.fn_intake_dedup();


--
-- TOC entry 4597 (class 2606 OID 31792)
-- Name: leads leads_assigned_agent_id_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.leads
    ADD CONSTRAINT leads_assigned_agent_id_fkey FOREIGN KEY (assigned_agent_id) REFERENCES clean.sales_agents(agent_id) ON DELETE SET NULL;


--
-- TOC entry 4598 (class 2606 OID 31787)
-- Name: leads leads_campaign_id_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.leads
    ADD CONSTRAINT leads_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES analytics.campaigns(campaign_id) ON DELETE SET NULL;


--
-- TOC entry 4599 (class 2606 OID 31797)
-- Name: leads leads_converted_student_id_fkey; Type: FK CONSTRAINT; Schema: analytics; Owner: postgres
--

ALTER TABLE ONLY analytics.leads
    ADD CONSTRAINT leads_converted_student_id_fkey FOREIGN KEY (converted_student_id) REFERENCES clean.students(student_id) ON DELETE SET NULL;


--
-- TOC entry 4559 (class 2606 OID 30765)
-- Name: achievements achievements_student_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.achievements
    ADD CONSTRAINT achievements_student_id_fkey FOREIGN KEY (student_id) REFERENCES clean.students(student_id) ON DELETE CASCADE;


--
-- TOC entry 4554 (class 2606 OID 30689)
-- Name: app_sessions app_sessions_student_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.app_sessions
    ADD CONSTRAINT app_sessions_student_id_fkey FOREIGN KEY (student_id) REFERENCES clean.students(student_id) ON DELETE CASCADE;


--
-- TOC entry 4576 (class 2606 OID 30990)
-- Name: churn_risk_scores churn_risk_scores_student_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.churn_risk_scores
    ADD CONSTRAINT churn_risk_scores_student_id_fkey FOREIGN KEY (student_id) REFERENCES clean.students(student_id) ON DELETE CASCADE;


--
-- TOC entry 4549 (class 2606 OID 30626)
-- Name: class_analytics class_analytics_class_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.class_analytics
    ADD CONSTRAINT class_analytics_class_id_fkey FOREIGN KEY (class_id) REFERENCES clean.classes(class_id) ON DELETE CASCADE;


--
-- TOC entry 4550 (class 2606 OID 30631)
-- Name: class_analytics class_analytics_triggered_by_user_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.class_analytics
    ADD CONSTRAINT class_analytics_triggered_by_user_id_fkey FOREIGN KEY (triggered_by_user_id) REFERENCES clean.students(student_id) ON DELETE SET NULL;


--
-- TOC entry 4545 (class 2606 OID 30607)
-- Name: classes classes_cancelled_by_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.classes
    ADD CONSTRAINT classes_cancelled_by_fkey FOREIGN KEY (cancelled_by) REFERENCES clean.students(student_id) ON DELETE SET NULL;


--
-- TOC entry 4546 (class 2606 OID 30592)
-- Name: classes classes_student_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.classes
    ADD CONSTRAINT classes_student_id_fkey FOREIGN KEY (student_id) REFERENCES clean.students(student_id) ON DELETE RESTRICT;


--
-- TOC entry 4547 (class 2606 OID 30602)
-- Name: classes classes_subscription_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.classes
    ADD CONSTRAINT classes_subscription_id_fkey FOREIGN KEY (subscription_id) REFERENCES clean.subscriptions(subscription_id) ON DELETE SET NULL;


--
-- TOC entry 4548 (class 2606 OID 30597)
-- Name: classes classes_teacher_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.classes
    ADD CONSTRAINT classes_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES clean.teachers(teacher_id) ON DELETE RESTRICT;


--
-- TOC entry 4553 (class 2606 OID 30673)
-- Name: daily_activity daily_activity_student_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.daily_activity
    ADD CONSTRAINT daily_activity_student_id_fkey FOREIGN KEY (student_id) REFERENCES clean.students(student_id) ON DELETE CASCADE;


--
-- TOC entry 4533 (class 2606 OID 30451)
-- Name: families families_parent_student_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.families
    ADD CONSTRAINT families_parent_student_id_fkey FOREIGN KEY (parent_student_id) REFERENCES clean.students(student_id) ON DELETE RESTRICT;


--
-- TOC entry 4534 (class 2606 OID 30473)
-- Name: family_children family_children_family_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.family_children
    ADD CONSTRAINT family_children_family_id_fkey FOREIGN KEY (family_id) REFERENCES clean.families(family_id) ON DELETE CASCADE;


--
-- TOC entry 4535 (class 2606 OID 30478)
-- Name: family_children family_children_student_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.family_children
    ADD CONSTRAINT family_children_student_id_fkey FOREIGN KEY (student_id) REFERENCES clean.students(student_id) ON DELETE RESTRICT;


--
-- TOC entry 4557 (class 2606 OID 30742)
-- Name: game_sessions game_sessions_game_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.game_sessions
    ADD CONSTRAINT game_sessions_game_id_fkey FOREIGN KEY (game_id) REFERENCES clean.games(game_id) ON DELETE CASCADE;


--
-- TOC entry 4558 (class 2606 OID 30747)
-- Name: game_sessions game_sessions_student_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.game_sessions
    ADD CONSTRAINT game_sessions_student_id_fkey FOREIGN KEY (student_id) REFERENCES clean.students(student_id) ON DELETE CASCADE;


--
-- TOC entry 4556 (class 2606 OID 30724)
-- Name: games games_student_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.games
    ADD CONSTRAINT games_student_id_fkey FOREIGN KEY (student_id) REFERENCES clean.students(student_id) ON DELETE CASCADE;


--
-- TOC entry 4551 (class 2606 OID 30651)
-- Name: lesson_attempts lesson_attempts_class_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.lesson_attempts
    ADD CONSTRAINT lesson_attempts_class_id_fkey FOREIGN KEY (class_id) REFERENCES clean.classes(class_id) ON DELETE CASCADE;


--
-- TOC entry 4552 (class 2606 OID 30656)
-- Name: lesson_attempts lesson_attempts_student_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.lesson_attempts
    ADD CONSTRAINT lesson_attempts_student_id_fkey FOREIGN KEY (student_id) REFERENCES clean.students(student_id) ON DELETE CASCADE;


--
-- TOC entry 4594 (class 2606 OID 31467)
-- Name: llm_lesson_analyses llm_lesson_analyses_class_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.llm_lesson_analyses
    ADD CONSTRAINT llm_lesson_analyses_class_id_fkey FOREIGN KEY (class_id) REFERENCES clean.classes(class_id) ON DELETE SET NULL;


--
-- TOC entry 4595 (class 2606 OID 31472)
-- Name: llm_lesson_analyses llm_lesson_analyses_student_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.llm_lesson_analyses
    ADD CONSTRAINT llm_lesson_analyses_student_id_fkey FOREIGN KEY (student_id) REFERENCES clean.students(student_id) ON DELETE SET NULL;


--
-- TOC entry 4555 (class 2606 OID 30706)
-- Name: notifications_log notifications_log_student_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.notifications_log
    ADD CONSTRAINT notifications_log_student_id_fkey FOREIGN KEY (student_id) REFERENCES clean.students(student_id) ON DELETE CASCADE;


--
-- TOC entry 4565 (class 2606 OID 30886)
-- Name: payment_transactions payment_transactions_child_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.payment_transactions
    ADD CONSTRAINT payment_transactions_child_id_fkey FOREIGN KEY (child_id) REFERENCES clean.family_children(child_id) ON DELETE SET NULL;


--
-- TOC entry 4566 (class 2606 OID 30881)
-- Name: payment_transactions payment_transactions_family_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.payment_transactions
    ADD CONSTRAINT payment_transactions_family_id_fkey FOREIGN KEY (family_id) REFERENCES clean.families(family_id) ON DELETE SET NULL;


--
-- TOC entry 4567 (class 2606 OID 30891)
-- Name: payment_transactions payment_transactions_generated_by_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.payment_transactions
    ADD CONSTRAINT payment_transactions_generated_by_fkey FOREIGN KEY (generated_by) REFERENCES clean.students(student_id) ON DELETE SET NULL;


--
-- TOC entry 4568 (class 2606 OID 30871)
-- Name: payment_transactions payment_transactions_student_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.payment_transactions
    ADD CONSTRAINT payment_transactions_student_id_fkey FOREIGN KEY (student_id) REFERENCES clean.students(student_id) ON DELETE RESTRICT;


--
-- TOC entry 4569 (class 2606 OID 30876)
-- Name: payment_transactions payment_transactions_subscription_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.payment_transactions
    ADD CONSTRAINT payment_transactions_subscription_id_fkey FOREIGN KEY (subscription_id) REFERENCES clean.subscriptions(subscription_id) ON DELETE SET NULL;


--
-- TOC entry 4560 (class 2606 OID 30782)
-- Name: points_ledger points_ledger_student_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.points_ledger
    ADD CONSTRAINT points_ledger_student_id_fkey FOREIGN KEY (student_id) REFERENCES clean.students(student_id) ON DELETE CASCADE;


--
-- TOC entry 4528 (class 2606 OID 30368)
-- Name: questionnaire_responses questionnaire_responses_student_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.questionnaire_responses
    ADD CONSTRAINT questionnaire_responses_student_id_fkey FOREIGN KEY (student_id) REFERENCES clean.students(student_id) ON DELETE CASCADE;


--
-- TOC entry 4585 (class 2606 OID 31117)
-- Name: referral_fraud_logs referral_fraud_logs_referee_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.referral_fraud_logs
    ADD CONSTRAINT referral_fraud_logs_referee_id_fkey FOREIGN KEY (referee_id) REFERENCES clean.students(student_id) ON DELETE CASCADE;


--
-- TOC entry 4586 (class 2606 OID 31107)
-- Name: referral_fraud_logs referral_fraud_logs_referral_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.referral_fraud_logs
    ADD CONSTRAINT referral_fraud_logs_referral_id_fkey FOREIGN KEY (referral_id) REFERENCES clean.referrals(referral_id) ON DELETE SET NULL;


--
-- TOC entry 4587 (class 2606 OID 31112)
-- Name: referral_fraud_logs referral_fraud_logs_referrer_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.referral_fraud_logs
    ADD CONSTRAINT referral_fraud_logs_referrer_id_fkey FOREIGN KEY (referrer_id) REFERENCES clean.students(student_id) ON DELETE CASCADE;


--
-- TOC entry 4588 (class 2606 OID 31122)
-- Name: referral_fraud_logs referral_fraud_logs_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.referral_fraud_logs
    ADD CONSTRAINT referral_fraud_logs_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES clean.students(student_id) ON DELETE SET NULL;


--
-- TOC entry 4582 (class 2606 OID 31078)
-- Name: referral_rewards referral_rewards_referral_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.referral_rewards
    ADD CONSTRAINT referral_rewards_referral_id_fkey FOREIGN KEY (referral_id) REFERENCES clean.referrals(referral_id) ON DELETE CASCADE;


--
-- TOC entry 4583 (class 2606 OID 31083)
-- Name: referral_rewards referral_rewards_student_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.referral_rewards
    ADD CONSTRAINT referral_rewards_student_id_fkey FOREIGN KEY (student_id) REFERENCES clean.students(student_id) ON DELETE CASCADE;


--
-- TOC entry 4584 (class 2606 OID 31088)
-- Name: referral_rewards referral_rewards_txn_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.referral_rewards
    ADD CONSTRAINT referral_rewards_txn_id_fkey FOREIGN KEY (txn_id) REFERENCES clean.payment_transactions(txn_id) ON DELETE SET NULL;


--
-- TOC entry 4580 (class 2606 OID 31058)
-- Name: referrals referrals_referee_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.referrals
    ADD CONSTRAINT referrals_referee_id_fkey FOREIGN KEY (referee_id) REFERENCES clean.students(student_id) ON DELETE SET NULL;


--
-- TOC entry 4581 (class 2606 OID 31053)
-- Name: referrals referrals_referrer_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.referrals
    ADD CONSTRAINT referrals_referrer_id_fkey FOREIGN KEY (referrer_id) REFERENCES clean.students(student_id) ON DELETE RESTRICT;


--
-- TOC entry 4577 (class 2606 OID 31018)
-- Name: retention_interventions retention_interventions_assigned_to_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.retention_interventions
    ADD CONSTRAINT retention_interventions_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES clean.students(student_id) ON DELETE SET NULL;


--
-- TOC entry 4578 (class 2606 OID 31013)
-- Name: retention_interventions retention_interventions_risk_score_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.retention_interventions
    ADD CONSTRAINT retention_interventions_risk_score_id_fkey FOREIGN KEY (risk_score_id) REFERENCES clean.churn_risk_scores(score_id) ON DELETE SET NULL;


--
-- TOC entry 4579 (class 2606 OID 31008)
-- Name: retention_interventions retention_interventions_student_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.retention_interventions
    ADD CONSTRAINT retention_interventions_student_id_fkey FOREIGN KEY (student_id) REFERENCES clean.students(student_id) ON DELETE CASCADE;


--
-- TOC entry 4538 (class 2606 OID 30537)
-- Name: subscription_members subscription_members_family_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.subscription_members
    ADD CONSTRAINT subscription_members_family_id_fkey FOREIGN KEY (family_id) REFERENCES clean.families(family_id) ON DELETE SET NULL;


--
-- TOC entry 4539 (class 2606 OID 30532)
-- Name: subscription_members subscription_members_student_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.subscription_members
    ADD CONSTRAINT subscription_members_student_id_fkey FOREIGN KEY (student_id) REFERENCES clean.students(student_id) ON DELETE CASCADE;


--
-- TOC entry 4540 (class 2606 OID 30527)
-- Name: subscription_members subscription_members_subscription_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.subscription_members
    ADD CONSTRAINT subscription_members_subscription_id_fkey FOREIGN KEY (subscription_id) REFERENCES clean.subscriptions(subscription_id) ON DELETE CASCADE;


--
-- TOC entry 4541 (class 2606 OID 30561)
-- Name: subscription_modifications subscription_modifications_child_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.subscription_modifications
    ADD CONSTRAINT subscription_modifications_child_id_fkey FOREIGN KEY (child_id) REFERENCES clean.family_children(child_id) ON DELETE SET NULL;


--
-- TOC entry 4542 (class 2606 OID 30571)
-- Name: subscription_modifications subscription_modifications_processed_by_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.subscription_modifications
    ADD CONSTRAINT subscription_modifications_processed_by_fkey FOREIGN KEY (processed_by) REFERENCES clean.students(student_id) ON DELETE SET NULL;


--
-- TOC entry 4543 (class 2606 OID 30566)
-- Name: subscription_modifications subscription_modifications_requested_by_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.subscription_modifications
    ADD CONSTRAINT subscription_modifications_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES clean.students(student_id) ON DELETE SET NULL;


--
-- TOC entry 4544 (class 2606 OID 30556)
-- Name: subscription_modifications subscription_modifications_subscription_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.subscription_modifications
    ADD CONSTRAINT subscription_modifications_subscription_id_fkey FOREIGN KEY (subscription_id) REFERENCES clean.subscriptions(subscription_id) ON DELETE CASCADE;


--
-- TOC entry 4536 (class 2606 OID 30510)
-- Name: subscriptions subscriptions_managed_by_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.subscriptions
    ADD CONSTRAINT subscriptions_managed_by_id_fkey FOREIGN KEY (managed_by_id) REFERENCES clean.students(student_id) ON DELETE SET NULL;


--
-- TOC entry 4537 (class 2606 OID 30505)
-- Name: subscriptions subscriptions_owner_student_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.subscriptions
    ADD CONSTRAINT subscriptions_owner_student_id_fkey FOREIGN KEY (owner_student_id) REFERENCES clean.students(student_id) ON DELETE RESTRICT;


--
-- TOC entry 4531 (class 2606 OID 30413)
-- Name: teacher_availability teacher_availability_teacher_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_availability
    ADD CONSTRAINT teacher_availability_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES clean.teachers(teacher_id) ON DELETE CASCADE;


--
-- TOC entry 4570 (class 2606 OID 30917)
-- Name: teacher_earning_analytics teacher_earning_analytics_class_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_earning_analytics
    ADD CONSTRAINT teacher_earning_analytics_class_id_fkey FOREIGN KEY (class_id) REFERENCES clean.classes(class_id) ON DELETE SET NULL;


--
-- TOC entry 4571 (class 2606 OID 30912)
-- Name: teacher_earning_analytics teacher_earning_analytics_teacher_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_earning_analytics
    ADD CONSTRAINT teacher_earning_analytics_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES clean.teachers(teacher_id) ON DELETE CASCADE;


--
-- TOC entry 4532 (class 2606 OID 30432)
-- Name: teacher_holidays teacher_holidays_teacher_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_holidays
    ADD CONSTRAINT teacher_holidays_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES clean.teachers(teacher_id) ON DELETE CASCADE;


--
-- TOC entry 4574 (class 2606 OID 30967)
-- Name: teacher_payout_transactions teacher_payout_transactions_payslip_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_payout_transactions
    ADD CONSTRAINT teacher_payout_transactions_payslip_id_fkey FOREIGN KEY (payslip_id) REFERENCES clean.teacher_payslips(payslip_id) ON DELETE RESTRICT;


--
-- TOC entry 4575 (class 2606 OID 30972)
-- Name: teacher_payout_transactions teacher_payout_transactions_teacher_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_payout_transactions
    ADD CONSTRAINT teacher_payout_transactions_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES clean.teachers(teacher_id) ON DELETE RESTRICT;


--
-- TOC entry 4572 (class 2606 OID 30948)
-- Name: teacher_payslips teacher_payslips_approved_by_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_payslips
    ADD CONSTRAINT teacher_payslips_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES clean.students(student_id) ON DELETE SET NULL;


--
-- TOC entry 4573 (class 2606 OID 30943)
-- Name: teacher_payslips teacher_payslips_teacher_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_payslips
    ADD CONSTRAINT teacher_payslips_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES clean.teachers(teacher_id) ON DELETE CASCADE;


--
-- TOC entry 4529 (class 2606 OID 30384)
-- Name: teacher_recommendations teacher_recommendations_questionnaire_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_recommendations
    ADD CONSTRAINT teacher_recommendations_questionnaire_id_fkey FOREIGN KEY (questionnaire_id) REFERENCES clean.questionnaire_responses(response_id) ON DELETE CASCADE;


--
-- TOC entry 4530 (class 2606 OID 30389)
-- Name: teacher_recommendations teacher_recommendations_teacher_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.teacher_recommendations
    ADD CONSTRAINT teacher_recommendations_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES clean.teachers(teacher_id) ON DELETE CASCADE;


--
-- TOC entry 4561 (class 2606 OID 30802)
-- Name: word_lists word_lists_student_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.word_lists
    ADD CONSTRAINT word_lists_student_id_fkey FOREIGN KEY (student_id) REFERENCES clean.students(student_id) ON DELETE CASCADE;


--
-- TOC entry 4563 (class 2606 OID 30841)
-- Name: word_practice_sessions word_practice_sessions_list_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.word_practice_sessions
    ADD CONSTRAINT word_practice_sessions_list_id_fkey FOREIGN KEY (list_id) REFERENCES clean.word_lists(list_id) ON DELETE CASCADE;


--
-- TOC entry 4564 (class 2606 OID 30846)
-- Name: word_practice_sessions word_practice_sessions_student_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.word_practice_sessions
    ADD CONSTRAINT word_practice_sessions_student_id_fkey FOREIGN KEY (student_id) REFERENCES clean.students(student_id) ON DELETE CASCADE;


--
-- TOC entry 4562 (class 2606 OID 30824)
-- Name: words words_list_id_fkey; Type: FK CONSTRAINT; Schema: clean; Owner: postgres
--

ALTER TABLE ONLY clean.words
    ADD CONSTRAINT words_list_id_fkey FOREIGN KEY (list_id) REFERENCES clean.word_lists(list_id) ON DELETE CASCADE;


--
-- TOC entry 4593 (class 2606 OID 31540)
-- Name: llm_requests llm_requests_class_id_fkey; Type: FK CONSTRAINT; Schema: raw; Owner: postgres
--

ALTER TABLE ONLY raw.llm_requests
    ADD CONSTRAINT llm_requests_class_id_fkey FOREIGN KEY (class_id) REFERENCES clean.classes(class_id) ON DELETE SET NULL;


--
-- TOC entry 4596 (class 2606 OID 31518)
-- Name: student_ai_profile student_ai_profile_student_id_fkey; Type: FK CONSTRAINT; Schema: serve; Owner: postgres
--

ALTER TABLE ONLY serve.student_ai_profile
    ADD CONSTRAINT student_ai_profile_student_id_fkey FOREIGN KEY (student_id) REFERENCES clean.students(student_id) ON DELETE CASCADE;


--
-- TOC entry 4590 (class 2606 OID 31157)
-- Name: student_gamification_profile student_gamification_profile_student_id_fkey; Type: FK CONSTRAINT; Schema: serve; Owner: postgres
--

ALTER TABLE ONLY serve.student_gamification_profile
    ADD CONSTRAINT student_gamification_profile_student_id_fkey FOREIGN KEY (student_id) REFERENCES clean.students(student_id) ON DELETE CASCADE;


--
-- TOC entry 4591 (class 2606 OID 31173)
-- Name: student_health_monetization student_health_monetization_student_id_fkey; Type: FK CONSTRAINT; Schema: serve; Owner: postgres
--

ALTER TABLE ONLY serve.student_health_monetization
    ADD CONSTRAINT student_health_monetization_student_id_fkey FOREIGN KEY (student_id) REFERENCES clean.students(student_id) ON DELETE CASCADE;


--
-- TOC entry 4589 (class 2606 OID 31139)
-- Name: student_mastery_profile student_mastery_profile_student_id_fkey; Type: FK CONSTRAINT; Schema: serve; Owner: postgres
--

ALTER TABLE ONLY serve.student_mastery_profile
    ADD CONSTRAINT student_mastery_profile_student_id_fkey FOREIGN KEY (student_id) REFERENCES clean.students(student_id) ON DELETE CASCADE;


--
-- TOC entry 4592 (class 2606 OID 31192)
-- Name: teacher_performance_profile teacher_performance_profile_teacher_id_fkey; Type: FK CONSTRAINT; Schema: serve; Owner: postgres
--

ALTER TABLE ONLY serve.teacher_performance_profile
    ADD CONSTRAINT teacher_performance_profile_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES clean.teachers(teacher_id) ON DELETE CASCADE;


--
-- TOC entry 4747 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


-- Completed on 2026-03-12 18:00:31

--
-- PostgreSQL database dump complete
--

