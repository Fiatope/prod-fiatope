\restrict XcY9LmBB2rMjblDdmnNBiu0DpHc1HRusLvL7NbMNypdNnc96aJjUA6xC8fXMClF

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

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

--
-- Name: hstore; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;


--
-- Name: EXTENSION hstore; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION hstore IS 'data type for storing sets of (key, value) pairs';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: EXTENSION unaccent; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: contributions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contributions (
    id integer NOT NULL,
    project_id integer NOT NULL,
    user_id integer NOT NULL,
    reward_id integer,
    value numeric NOT NULL,
    confirmed_at timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    anonymous boolean DEFAULT false,
    key text,
    credits boolean DEFAULT false,
    notified_finish boolean DEFAULT false,
    payment_method text,
    payment_token text,
    payment_id character varying(255),
    payer_name text,
    payer_email text,
    payer_document text,
    address_street text,
    address_number text,
    address_complement text,
    address_neighborhood text,
    address_zip_code text,
    address_city text,
    address_state text,
    address_phone_number text,
    payment_choice text,
    payment_service_fee numeric DEFAULT 0 NOT NULL,
    state character varying(255),
    short_note text,
    referral_url text,
    payment_service_fee_paid_by_user boolean DEFAULT false,
    matching_id integer,
    cfa_value numeric,
    response_code character varying(255),
    transaction_number character varying(255),
    response_message character varying(255),
    stripe_transferred boolean DEFAULT false,
    stripe_transfer_id character varying,
    stripe_refunded boolean DEFAULT false,
    stripe_refund_id character varying,
    stripe_charge_id character varying,
    CONSTRAINT backers_value_positive CHECK ((value >= (0)::numeric))
);


--
-- Name: can_cancel(public.contributions); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_cancel(public.contributions) RETURNS boolean
    LANGUAGE sql
    AS $_$
        select
          $1.state = 'waiting_confirmation' and
          (
            (
              select count(1) as total_of_days
              from generate_series($1.created_at::date, current_date, '1 day') day
              WHERE extract(dow from day) not in (0,1)
            )  > 6
          )
      $_$;


--
-- Name: can_refund(public.contributions); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_refund(public.contributions) RETURNS boolean
    LANGUAGE sql
    AS $_$
        select
          $1.state IN('confirmed', 'requested_refund', 'refunded') AND
          NOT $1.credits AND
          EXISTS(
            SELECT true
              FROM projects p
              WHERE p.id = $1.project_id and p.state = 'failed'
          )
      $_$;


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id integer NOT NULL,
    name text NOT NULL,
    user_id integer NOT NULL,
    category_id integer NOT NULL,
    goal numeric NOT NULL,
    about text NOT NULL,
    headline text NOT NULL,
    video_url text,
    short_url text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    about_html text,
    recommended boolean DEFAULT false,
    home_page_comment text,
    permalink text NOT NULL,
    video_thumbnail text,
    state character varying(255),
    online_days integer DEFAULT 0,
    online_date timestamp with time zone,
    how_know text,
    more_urls text,
    first_contributions text,
    uploaded_image character varying(255),
    video_embed_url character varying(255),
    budget text,
    budget_html text,
    terms text,
    terms_html text,
    site character varying(255),
    hash_tag character varying(255),
    address_city character varying(255),
    address_state character varying(255),
    address_zip_code character varying(255),
    address_neighborhood character varying(255),
    foundation_widget boolean DEFAULT false,
    campaign_type text,
    featured boolean DEFAULT false,
    home_page boolean,
    about_textile text,
    budget_textile text,
    terms_textile text,
    latitude double precision,
    longitude double precision,
    referral_url text,
    hero_image character varying(255),
    sent_to_analysis_at timestamp without time zone,
    organization_type character varying(255),
    street_address character varying(255),
    currency character varying(255) DEFAULT 'EUR'::character varying NOT NULL,
    challenge integer,
    partner_id integer,
    donation_can_issue_tax_receipt boolean DEFAULT false,
    english_textile text,
    english text,
    english_html text,
    presale boolean DEFAULT false,
    presale_goal integer,
    numero_ifu character varying,
    numero_rccm character varying,
    show_on_homepage boolean DEFAULT false,
    stripe_account_id character varying,
    use_stripe boolean DEFAULT true,
    stripe_transfer_id character varying,
    stripe_settled_at timestamp without time zone,
    stripe_settlement_type character varying,
    CONSTRAINT projects_about_not_blank CHECK ((length(btrim(about)) > 0)),
    CONSTRAINT projects_headline_length_within CHECK (((length(headline) >= 1) AND (length(headline) <= 140))),
    CONSTRAINT projects_headline_not_blank CHECK ((length(btrim(headline)) > 0))
);


--
-- Name: expires_at(public.projects); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.expires_at(public.projects) RETURNS timestamp with time zone
    LANGUAGE sql
    AS $_$
         SELECT ((($1.online_date AT TIME ZONE 'Europe/Paris' + ($1.online_days || ' days')::interval)::date::text || ' 23:59:59')::timestamp AT TIME ZONE 'Europe/Paris')
        $_$;


--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying NOT NULL,
    created_at timestamp without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: api_access_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_access_tokens (
    id integer NOT NULL,
    code character varying(255) NOT NULL,
    expired boolean DEFAULT false NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: api_access_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.api_access_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: api_access_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.api_access_tokens_id_seq OWNED BY public.api_access_tokens.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: article_orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.article_orders (
    id bigint NOT NULL,
    contribution_id bigint,
    article_id bigint
);


--
-- Name: article_orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.article_orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: article_orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.article_orders_id_seq OWNED BY public.article_orders.id;


--
-- Name: articles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.articles (
    id bigint NOT NULL,
    title character varying,
    description text,
    uploaded_image character varying,
    reward_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: articles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.articles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: articles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.articles_id_seq OWNED BY public.articles.id;


--
-- Name: authorizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.authorizations (
    id integer NOT NULL,
    oauth_provider_id integer NOT NULL,
    user_id integer NOT NULL,
    uid text NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    access_token character varying(255),
    access_token_secret character varying(255),
    access_token_expires_at timestamp without time zone
);


--
-- Name: authorizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.authorizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: authorizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.authorizations_id_seq OWNED BY public.authorizations.id;


--
-- Name: balanced_contributors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.balanced_contributors (
    id integer NOT NULL,
    user_id integer,
    href character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    bank_account_href character varying(255)
);


--
-- Name: balanced_contributors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.balanced_contributors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: balanced_contributors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.balanced_contributors_id_seq OWNED BY public.balanced_contributors.id;


--
-- Name: bank_informations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bank_informations (
    id integer NOT NULL,
    user_id integer NOT NULL,
    iban character varying(255),
    bic character varying(255),
    key character varying(255),
    us_account_number character varying,
    us_account_aba character varying,
    ca_account_type character varying,
    ca_institution_number character varying,
    ca_account_number character varying,
    ca_branch_code character varying,
    ca_bank_name character varying,
    fr_key character varying,
    us_key character varying,
    ca_key character varying,
    other_key character varying,
    other_account_number character varying,
    other_bic character varying,
    other_country character varying,
    owner_city character varying,
    owner_region character varying,
    owner_postal_code character varying,
    owner_address character varying
);


--
-- Name: bank_informations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bank_informations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bank_informations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bank_informations_id_seq OWNED BY public.bank_informations.id;


--
-- Name: banners; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.banners (
    id bigint NOT NULL,
    type character varying,
    name character varying,
    attachment character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: banners_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.banners_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: banners_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.banners_id_seq OWNED BY public.banners.id;


--
-- Name: blogo_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blogo_posts (
    id integer NOT NULL,
    user_id integer NOT NULL,
    permalink character varying(255) NOT NULL,
    title character varying(255) NOT NULL,
    published boolean NOT NULL,
    published_at timestamp without time zone NOT NULL,
    markup_lang character varying(255) NOT NULL,
    raw_content text NOT NULL,
    html_content text NOT NULL,
    html_overview text,
    tags_string character varying(255),
    meta_description character varying(255) NOT NULL,
    meta_image character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: blogo_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.blogo_posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blogo_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.blogo_posts_id_seq OWNED BY public.blogo_posts.id;


--
-- Name: blogo_taggings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blogo_taggings (
    id integer NOT NULL,
    post_id integer NOT NULL,
    tag_id integer NOT NULL
);


--
-- Name: blogo_taggings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.blogo_taggings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blogo_taggings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.blogo_taggings_id_seq OWNED BY public.blogo_taggings.id;


--
-- Name: blogo_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blogo_tags (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: blogo_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.blogo_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blogo_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.blogo_tags_id_seq OWNED BY public.blogo_tags.id;


--
-- Name: blogo_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blogo_users (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    password_digest character varying(255) NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: blogo_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.blogo_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blogo_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.blogo_users_id_seq OWNED BY public.blogo_users.id;


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id integer NOT NULL,
    name_pt text NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    name_en character varying(255),
    name_fr character varying(255),
    CONSTRAINT categories_name_not_blank CHECK ((length(btrim(name_pt)) > 0))
);


--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: channel_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.channel_members (
    id integer NOT NULL,
    channel_id integer,
    user_id integer,
    admin boolean DEFAULT false,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: channel_members_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.channel_members_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: channel_members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.channel_members_id_seq OWNED BY public.channel_members.id;


--
-- Name: channels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.channels (
    id integer NOT NULL,
    name text NOT NULL,
    description text NOT NULL,
    permalink text NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    image text,
    video_url text,
    video_embed_url character varying(255),
    how_it_works text,
    how_it_works_html text,
    terms_url character varying(255),
    state text DEFAULT 'draft'::text,
    user_id integer,
    accepts_projects boolean DEFAULT true,
    submit_your_project_text text,
    submit_your_project_text_html text,
    start_content public.hstore,
    start_hero_image character varying(255),
    success_content public.hstore,
    application_url character varying(255)
);


--
-- Name: channels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.channels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: channels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.channels_id_seq OWNED BY public.channels.id;


--
-- Name: channels_projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.channels_projects (
    id integer NOT NULL,
    channel_id integer,
    project_id integer
);


--
-- Name: channels_projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.channels_projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: channels_projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.channels_projects_id_seq OWNED BY public.channels_projects.id;


--
-- Name: channels_subscribers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.channels_subscribers (
    id integer NOT NULL,
    user_id integer NOT NULL,
    channel_id integer NOT NULL
);


--
-- Name: channels_subscribers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.channels_subscribers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: channels_subscribers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.channels_subscribers_id_seq OWNED BY public.channels_subscribers.id;


--
-- Name: contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contacts (
    id integer NOT NULL,
    first_name character varying(255) NOT NULL,
    last_name character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    phone character varying(255),
    organization_name character varying(255) NOT NULL,
    organization_website character varying(255),
    message text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: contacts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.contacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contacts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.contacts_id_seq OWNED BY public.contacts.id;


--
-- Name: contribution_rewards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contribution_rewards (
    id bigint NOT NULL,
    contribution_id bigint,
    reward_id bigint,
    quantity integer
);


--
-- Name: contribution_rewards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.contribution_rewards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contribution_rewards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.contribution_rewards_id_seq OWNED BY public.contribution_rewards.id;


--
-- Name: contributions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.contributions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contributions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.contributions_id_seq OWNED BY public.contributions.id;


--
-- Name: follows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.follows (
    id integer NOT NULL,
    follower_type character varying(255),
    followerid integer,
    followable_type character varying(255),
    followableid integer,
    created_at timestamp without time zone
);


--
-- Name: follows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.follows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: follows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.follows_id_seq OWNED BY public.follows.id;


--
-- Name: funding_raised_per_project_reports; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.funding_raised_per_project_reports AS
SELECT
    NULL::integer AS project_id,
    NULL::text AS project_name,
    NULL::numeric AS total_raised,
    NULL::bigint AS total_backs,
    NULL::bigint AS total_backers;


--
-- Name: images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.images (
    id integer NOT NULL,
    file character varying(255) NOT NULL,
    user_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: images_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.images_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.images_id_seq OWNED BY public.images.id;


--
-- Name: investment_prospects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.investment_prospects (
    id integer NOT NULL,
    user_id integer,
    value double precision DEFAULT 0,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: investment_prospects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.investment_prospects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: investment_prospects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.investment_prospects_id_seq OWNED BY public.investment_prospects.id;


--
-- Name: kyc_files; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.kyc_files (
    id integer NOT NULL,
    user_id integer NOT NULL,
    uploaded_image character varying(255),
    proof_type character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    document_key character varying(255)
);


--
-- Name: kyc_files_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.kyc_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: kyc_files_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.kyc_files_id_seq OWNED BY public.kyc_files.id;


--
-- Name: likes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.likes (
    id integer NOT NULL,
    liker_type character varying(255),
    likerid integer,
    likeable_type character varying(255),
    likeableid integer,
    created_at timestamp without time zone
);


--
-- Name: likes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.likes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: likes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.likes_id_seq OWNED BY public.likes.id;


--
-- Name: mangopay_contributors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mangopay_contributors (
    id integer NOT NULL,
    user_id integer,
    organization_id integer,
    key character varying(255) NOT NULL,
    href character varying(255),
    wallet_key character varying(255),
    verification_level character varying(255) DEFAULT 'light'::character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: mangopay_contributors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mangopay_contributors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mangopay_contributors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mangopay_contributors_id_seq OWNED BY public.mangopay_contributors.id;


--
-- Name: mangopay_registered_cards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mangopay_registered_cards (
    id integer NOT NULL,
    user_id integer NOT NULL,
    currency character varying(255) DEFAULT 'EUR'::character varying NOT NULL,
    key character varying(255) NOT NULL
);


--
-- Name: mangopay_registered_cards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mangopay_registered_cards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mangopay_registered_cards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mangopay_registered_cards_id_seq OWNED BY public.mangopay_registered_cards.id;


--
-- Name: mangopay_wallet_handlers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mangopay_wallet_handlers (
    id integer NOT NULL,
    project_id integer,
    wallet_key character varying(255) NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: mangopay_wallet_handlers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mangopay_wallet_handlers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mangopay_wallet_handlers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mangopay_wallet_handlers_id_seq OWNED BY public.mangopay_wallet_handlers.id;


--
-- Name: matches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.matches (
    id integer NOT NULL,
    project_id integer NOT NULL,
    user_id integer,
    starts_at date NOT NULL,
    finishes_at date NOT NULL,
    value_unit numeric NOT NULL,
    value numeric,
    completed boolean DEFAULT false NOT NULL,
    payment_id character varying(255),
    payment_choice text,
    payment_method text,
    payment_token text,
    payment_service_fee numeric DEFAULT 0.0,
    payment_service_fee_paid_by_user boolean DEFAULT true,
    state character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    key character varying(255),
    confirmed_at timestamp without time zone
);


--
-- Name: matches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.matches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: matches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.matches_id_seq OWNED BY public.matches.id;


--
-- Name: matchings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.matchings (
    id integer NOT NULL,
    match_id integer,
    contribution_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: matchings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.matchings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: matchings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.matchings_id_seq OWNED BY public.matchings.id;


--
-- Name: neighborly_admin_banners; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.neighborly_admin_banners (
    id bigint NOT NULL,
    type character varying,
    name character varying,
    attachment character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: neighborly_admin_banners_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.neighborly_admin_banners_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: neighborly_admin_banners_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.neighborly_admin_banners_id_seq OWNED BY public.neighborly_admin_banners.id;


--
-- Name: neighborly_admin_funding_raised_per_project_reports; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.neighborly_admin_funding_raised_per_project_reports AS
SELECT
    NULL::integer AS project_id,
    NULL::text AS project_name,
    NULL::numeric AS total_raised,
    NULL::bigint AS total_backs,
    NULL::bigint AS total_backers;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id integer NOT NULL,
    email text,
    name text,
    nickname text,
    bio text,
    image_url text,
    newsletter boolean DEFAULT false,
    project_updates boolean DEFAULT false,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    admin boolean DEFAULT false,
    full_name text,
    address_street text,
    address_number text,
    address_complement text,
    address_neighborhood text,
    address_city text,
    address_state text,
    address_zip_code text,
    phone_number text,
    locale text DEFAULT 'pt'::text NOT NULL,
    encrypted_password character varying(128) DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying(255),
    reset_password_sent_at timestamp without time zone,
    remember_created_at timestamp without time zone,
    sign_in_count integer DEFAULT 0,
    current_sign_in_at timestamp without time zone,
    last_sign_in_at timestamp without time zone,
    current_sign_in_ip character varying(255),
    last_sign_in_ip character varying(255),
    twitter_url character varying(255),
    facebook_url character varying(255),
    other_url character varying(255),
    uploaded_image text,
    state_inscription character varying(255),
    profile_type character varying(255),
    linkedin_url character varying(255),
    confirmation_token character varying(255),
    confirmed_at timestamp without time zone,
    confirmation_sent_at timestamp without time zone,
    unconfirmed_email character varying(255),
    new_project boolean DEFAULT false,
    latitude double precision,
    longitude double precision,
    completeness_progress integer DEFAULT 0,
    birthday date,
    nationality character varying(255),
    residence_country character varying(255),
    partner_id integer,
    mobile_phone character varying(255),
    stripe_customer_id character varying,
    stripe_connect_account_id character varying,
    stripe_onboarding_complete boolean DEFAULT false,
    CONSTRAINT users_bio_length_within CHECK (((length(bio) >= 0) AND (length(bio) <= 140)))
);


--
-- Name: neighborly_admin_statistics; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.neighborly_admin_statistics AS
 SELECT ( SELECT count(*) AS count
           FROM public.users) AS total_users,
    ( SELECT count(*) AS count
           FROM public.users
          WHERE ((users.profile_type)::text = 'organization'::text)) AS total_organization_users,
    ( SELECT count(*) AS count
           FROM public.users
          WHERE ((users.profile_type)::text = 'personal'::text)) AS total_personal_users,
    ( SELECT count(*) AS count
           FROM public.users
          WHERE ((users.profile_type)::text = 'channel'::text)) AS total_channel_users,
    ( SELECT count(*) AS count
           FROM ( SELECT DISTINCT projects.address_city,
                    projects.address_state
                   FROM public.projects) count) AS total_communities,
    contributions_totals.total_contributions,
    contributions_totals.total_contributors,
    contributions_totals.total_contributed,
    projects_totals.total_projects,
    projects_totals.total_projects_success,
    projects_totals.total_projects_online,
    projects_totals.total_projects_draft,
    projects_totals.total_projects_soon
   FROM ( SELECT count(*) AS total_contributions,
            count(DISTINCT contributions.user_id) AS total_contributors,
            sum(contributions.value) AS total_contributed
           FROM public.contributions
          WHERE ((contributions.state)::text <> ALL (ARRAY[('waiting_confirmation'::character varying)::text, ('pending'::character varying)::text, ('canceled'::character varying)::text, 'deleted'::text]))) contributions_totals,
    ( SELECT count(*) AS total_projects,
            count(
                CASE
                    WHEN ((projects.state)::text = 'draft'::text) THEN 1
                    ELSE NULL::integer
                END) AS total_projects_draft,
            count(
                CASE
                    WHEN ((projects.state)::text = 'soon'::text) THEN 1
                    ELSE NULL::integer
                END) AS total_projects_soon,
            count(
                CASE
                    WHEN ((projects.state)::text = 'successful'::text) THEN 1
                    ELSE NULL::integer
                END) AS total_projects_success,
            count(
                CASE
                    WHEN ((projects.state)::text = 'online'::text) THEN 1
                    ELSE NULL::integer
                END) AS total_projects_online
           FROM public.projects
          WHERE ((projects.state)::text <> ALL (ARRAY[('deleted'::character varying)::text, ('rejected'::character varying)::text]))) projects_totals;


--
-- Name: neighborly_balanced_orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.neighborly_balanced_orders (
    id integer NOT NULL,
    project_id integer NOT NULL,
    href character varying(255) NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: neighborly_balanced_orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.neighborly_balanced_orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: neighborly_balanced_orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.neighborly_balanced_orders_id_seq OWNED BY public.neighborly_balanced_orders.id;


--
-- Name: neighborly_mangopay_orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.neighborly_mangopay_orders (
    id integer NOT NULL,
    project_id integer NOT NULL,
    contribution_id integer NOT NULL,
    user_id integer NOT NULL,
    order_key character varying(255) NOT NULL,
    refund_key character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: neighborly_mangopay_orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.neighborly_mangopay_orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: neighborly_mangopay_orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.neighborly_mangopay_orders_id_seq OWNED BY public.neighborly_mangopay_orders.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id integer NOT NULL,
    user_id integer NOT NULL,
    project_id integer,
    dismissed boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    contribution_id integer,
    update_id integer,
    origin_email text NOT NULL,
    origin_name text NOT NULL,
    template_name text NOT NULL,
    locale text NOT NULL,
    channel_id integer,
    contact_id integer,
    bcc character varying(255),
    match_id integer
);


--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- Name: oauth_providers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oauth_providers (
    id integer NOT NULL,
    name text NOT NULL,
    key text NOT NULL,
    secret text NOT NULL,
    scope text,
    "order" integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    strategy text,
    path text,
    CONSTRAINT oauth_providers_key_not_blank CHECK ((length(btrim(key)) > 0)),
    CONSTRAINT oauth_providers_name_not_blank CHECK ((length(btrim(name)) > 0)),
    CONSTRAINT oauth_providers_secret_not_blank CHECK ((length(btrim(secret)) > 0))
);


--
-- Name: oauth_providers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oauth_providers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_providers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oauth_providers_id_seq OWNED BY public.oauth_providers.id;


--
-- Name: orange_money_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orange_money_transactions (
    id integer NOT NULL,
    contribution_id integer,
    order_id_string character varying(255),
    reference character varying(255),
    lang character varying(255),
    pay_token text,
    status_string character varying(255),
    payment_url text,
    notif_token text,
    txnid character varying(255)
);


--
-- Name: orange_money_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.orange_money_transactions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: orange_money_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.orange_money_transactions_id_seq OWNED BY public.orange_money_transactions.id;


--
-- Name: organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organizations (
    id integer NOT NULL,
    name character varying(255),
    image character varying(255),
    user_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: organizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.organizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.organizations_id_seq OWNED BY public.organizations.id;


--
-- Name: partners; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.partners (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    headline character varying(255) NOT NULL,
    permalink character varying(255) NOT NULL,
    about text,
    uploaded_image character varying(255),
    hero_image character varying(255),
    primary_theme_color character varying(255),
    email character varying,
    about_html text
);


--
-- Name: partners_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.partners_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: partners_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.partners_id_seq OWNED BY public.partners.id;


--
-- Name: pay_plus_africa_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pay_plus_africa_transactions (
    id integer NOT NULL,
    contribution_id integer,
    order_id_string character varying(255),
    reference character varying(255),
    status_string character varying(255),
    invoice_number character varying(255),
    payment_url text,
    notif_token text
);


--
-- Name: pay_plus_africa_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pay_plus_africa_transactions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pay_plus_africa_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pay_plus_africa_transactions_id_seq OWNED BY public.pay_plus_africa_transactions.id;


--
-- Name: payment_notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_notifications (
    id integer NOT NULL,
    contribution_id integer NOT NULL,
    extra_data text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    match_id integer
);


--
-- Name: payment_notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payment_notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment_notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payment_notifications_id_seq OWNED BY public.payment_notifications.id;


--
-- Name: payouts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payouts (
    id integer NOT NULL,
    payment_service character varying(255),
    project_id integer NOT NULL,
    user_id integer,
    value numeric NOT NULL,
    manual boolean DEFAULT false,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: payouts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payouts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payouts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payouts_id_seq OWNED BY public.payouts.id;


--
-- Name: press_assets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.press_assets (
    id integer NOT NULL,
    title character varying(255),
    image text,
    url character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: press_assets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.press_assets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: press_assets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.press_assets_id_seq OWNED BY public.press_assets.id;


--
-- Name: project_documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_documents (
    id integer NOT NULL,
    document text,
    project_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    name character varying(255)
);


--
-- Name: project_documents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.project_documents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_documents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.project_documents_id_seq OWNED BY public.project_documents.id;


--
-- Name: project_faqs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_faqs (
    id integer NOT NULL,
    answer text,
    title text,
    project_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: project_faqs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.project_faqs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_faqs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.project_faqs_id_seq OWNED BY public.project_faqs.id;


--
-- Name: project_totals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_totals (
    id integer NOT NULL,
    project_id integer,
    net_amount numeric DEFAULT 0,
    platform_fee numeric DEFAULT 0,
    pledged numeric DEFAULT 0,
    progress integer DEFAULT 0,
    total_contributions integer DEFAULT 0,
    total_contributions_without_matches integer DEFAULT 0,
    total_payment_service_fee numeric DEFAULT 0,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: project_totals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.project_totals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_totals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.project_totals_id_seq OWNED BY public.project_totals.id;


--
-- Name: projects_for_home; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.projects_for_home AS
 WITH featured_projects AS (
         SELECT 'featured'::text AS origin,
            featureds.id,
            featureds.name,
            featureds.user_id,
            featureds.category_id,
            featureds.goal,
            featureds.about,
            featureds.headline,
            featureds.video_url,
            featureds.short_url,
            featureds.created_at,
            featureds.updated_at,
            featureds.about_html,
            featureds.recommended,
            featureds.home_page_comment,
            featureds.permalink,
            featureds.video_thumbnail,
            featureds.state,
            featureds.online_days,
            featureds.online_date,
            featureds.how_know,
            featureds.more_urls AS more_links,
            featureds.first_contributions,
            featureds.uploaded_image,
            featureds.video_embed_url,
            featureds.budget,
            featureds.budget_html,
            featureds.terms,
            featureds.terms_html,
            featureds.site,
            featureds.hash_tag,
            featureds.address_city,
            featureds.address_state,
            featureds.address_zip_code,
            featureds.address_neighborhood,
            featureds.foundation_widget,
            featureds.campaign_type,
            featureds.featured,
            featureds.home_page,
            featureds.about_textile,
            featureds.budget_textile,
            featureds.terms_textile,
            featureds.latitude,
            featureds.longitude,
            featureds.referral_url AS referal_link,
            featureds.hero_image,
            featureds.sent_to_analysis_at,
            featureds.organization_type,
            featureds.street_address
           FROM public.projects featureds
          WHERE (featureds.featured AND ((featureds.state)::text = 'online'::text))
         LIMIT 1
        ), recommended_projects AS (
         SELECT 'recommended'::text AS origin,
            recommends.id,
            recommends.name,
            recommends.user_id,
            recommends.category_id,
            recommends.goal,
            recommends.about,
            recommends.headline,
            recommends.video_url,
            recommends.short_url,
            recommends.created_at,
            recommends.updated_at,
            recommends.about_html,
            recommends.recommended,
            recommends.home_page_comment,
            recommends.permalink,
            recommends.video_thumbnail,
            recommends.state,
            recommends.online_days,
            recommends.online_date,
            recommends.how_know,
            recommends.more_urls AS more_links,
            recommends.first_contributions,
            recommends.uploaded_image,
            recommends.video_embed_url,
            recommends.budget,
            recommends.budget_html,
            recommends.terms,
            recommends.terms_html,
            recommends.site,
            recommends.hash_tag,
            recommends.address_city,
            recommends.address_state,
            recommends.address_zip_code,
            recommends.address_neighborhood,
            recommends.foundation_widget,
            recommends.campaign_type,
            recommends.featured,
            recommends.home_page,
            recommends.about_textile,
            recommends.budget_textile,
            recommends.terms_textile,
            recommends.latitude,
            recommends.longitude,
            recommends.referral_url AS referal_link,
            recommends.hero_image,
            recommends.sent_to_analysis_at,
            recommends.organization_type,
            recommends.street_address
           FROM public.projects recommends
          WHERE (recommends.recommended AND ((recommends.state)::text = 'online'::text) AND recommends.home_page AND (NOT (recommends.id IN ( SELECT featureds.id
                   FROM featured_projects featureds))))
          ORDER BY (random())
         LIMIT 5
        ), expiring_projects AS (
         SELECT 'expiring'::text AS origin,
            expiring.id,
            expiring.name,
            expiring.user_id,
            expiring.category_id,
            expiring.goal,
            expiring.about,
            expiring.headline,
            expiring.video_url,
            expiring.short_url,
            expiring.created_at,
            expiring.updated_at,
            expiring.about_html,
            expiring.recommended,
            expiring.home_page_comment,
            expiring.permalink,
            expiring.video_thumbnail,
            expiring.state,
            expiring.online_days,
            expiring.online_date,
            expiring.how_know,
            expiring.more_urls AS more_links,
            expiring.first_contributions,
            expiring.uploaded_image,
            expiring.video_embed_url,
            expiring.budget,
            expiring.budget_html,
            expiring.terms,
            expiring.terms_html,
            expiring.site,
            expiring.hash_tag,
            expiring.address_city,
            expiring.address_state,
            expiring.address_zip_code,
            expiring.address_neighborhood,
            expiring.foundation_widget,
            expiring.campaign_type,
            expiring.featured,
            expiring.home_page,
            expiring.about_textile,
            expiring.budget_textile,
            expiring.terms_textile,
            expiring.latitude,
            expiring.longitude,
            expiring.referral_url AS referal_link,
            expiring.hero_image,
            expiring.sent_to_analysis_at,
            expiring.organization_type,
            expiring.street_address
           FROM public.projects expiring
          WHERE (((expiring.state)::text = 'online'::text) AND (public.expires_at(expiring.*) <= (now() + '14 days'::interval)) AND expiring.home_page AND (NOT (expiring.id IN ( SELECT recommends.id
                   FROM recommended_projects recommends
                UNION
                 SELECT featureds.id
                   FROM featured_projects featureds))))
          ORDER BY (random())
         LIMIT 4
        ), soon_projects AS (
         SELECT 'soon'::text AS origin,
            soon.id,
            soon.name,
            soon.user_id,
            soon.category_id,
            soon.goal,
            soon.about,
            soon.headline,
            soon.video_url,
            soon.short_url,
            soon.created_at,
            soon.updated_at,
            soon.about_html,
            soon.recommended,
            soon.home_page_comment,
            soon.permalink,
            soon.video_thumbnail,
            soon.state,
            soon.online_days,
            soon.online_date,
            soon.how_know,
            soon.more_urls AS more_links,
            soon.first_contributions,
            soon.uploaded_image,
            soon.video_embed_url,
            soon.budget,
            soon.budget_html,
            soon.terms,
            soon.terms_html,
            soon.site,
            soon.hash_tag,
            soon.address_city,
            soon.address_state,
            soon.address_zip_code,
            soon.address_neighborhood,
            soon.foundation_widget,
            soon.campaign_type,
            soon.featured,
            soon.home_page,
            soon.about_textile,
            soon.budget_textile,
            soon.terms_textile,
            soon.latitude,
            soon.longitude,
            soon.referral_url AS referal_link,
            soon.hero_image,
            soon.sent_to_analysis_at,
            soon.organization_type,
            soon.street_address
           FROM public.projects soon
          WHERE (((soon.state)::text = 'soon'::text) AND soon.home_page AND (soon.uploaded_image IS NOT NULL))
          ORDER BY (random())
         LIMIT 4
        ), successful_projects AS (
         SELECT 'successful'::text AS origin,
            successful.id,
            successful.name,
            successful.user_id,
            successful.category_id,
            successful.goal,
            successful.about,
            successful.headline,
            successful.video_url,
            successful.short_url,
            successful.created_at,
            successful.updated_at,
            successful.about_html,
            successful.recommended,
            successful.home_page_comment,
            successful.permalink,
            successful.video_thumbnail,
            successful.state,
            successful.online_days,
            successful.online_date,
            successful.how_know,
            successful.more_urls AS more_links,
            successful.first_contributions,
            successful.uploaded_image,
            successful.video_embed_url,
            successful.budget,
            successful.budget_html,
            successful.terms,
            successful.terms_html,
            successful.site,
            successful.hash_tag,
            successful.address_city,
            successful.address_state,
            successful.address_zip_code,
            successful.address_neighborhood,
            successful.foundation_widget,
            successful.campaign_type,
            successful.featured,
            successful.home_page,
            successful.about_textile,
            successful.budget_textile,
            successful.terms_textile,
            successful.latitude,
            successful.longitude,
            successful.referral_url AS referal_link,
            successful.hero_image,
            successful.sent_to_analysis_at,
            successful.organization_type,
            successful.street_address
           FROM public.projects successful
          WHERE (((successful.state)::text = 'successful'::text) AND successful.home_page)
          ORDER BY (random())
         LIMIT 4
        )
 SELECT featured_projects.origin,
    featured_projects.id,
    featured_projects.name,
    featured_projects.user_id,
    featured_projects.category_id,
    featured_projects.goal,
    featured_projects.about,
    featured_projects.headline,
    featured_projects.video_url,
    featured_projects.short_url,
    featured_projects.created_at,
    featured_projects.updated_at,
    featured_projects.about_html,
    featured_projects.recommended,
    featured_projects.home_page_comment,
    featured_projects.permalink,
    featured_projects.video_thumbnail,
    featured_projects.state,
    featured_projects.online_days,
    featured_projects.online_date,
    featured_projects.how_know,
    featured_projects.more_links,
    featured_projects.first_contributions,
    featured_projects.uploaded_image,
    featured_projects.video_embed_url,
    featured_projects.budget,
    featured_projects.budget_html,
    featured_projects.terms,
    featured_projects.terms_html,
    featured_projects.site,
    featured_projects.hash_tag,
    featured_projects.address_city,
    featured_projects.address_state,
    featured_projects.address_zip_code,
    featured_projects.address_neighborhood,
    featured_projects.foundation_widget,
    featured_projects.campaign_type,
    featured_projects.featured,
    featured_projects.home_page,
    featured_projects.about_textile,
    featured_projects.budget_textile,
    featured_projects.terms_textile,
    featured_projects.latitude,
    featured_projects.longitude,
    featured_projects.referal_link,
    featured_projects.hero_image,
    featured_projects.sent_to_analysis_at,
    featured_projects.organization_type,
    featured_projects.street_address
   FROM featured_projects
UNION
 SELECT recommended_projects.origin,
    recommended_projects.id,
    recommended_projects.name,
    recommended_projects.user_id,
    recommended_projects.category_id,
    recommended_projects.goal,
    recommended_projects.about,
    recommended_projects.headline,
    recommended_projects.video_url,
    recommended_projects.short_url,
    recommended_projects.created_at,
    recommended_projects.updated_at,
    recommended_projects.about_html,
    recommended_projects.recommended,
    recommended_projects.home_page_comment,
    recommended_projects.permalink,
    recommended_projects.video_thumbnail,
    recommended_projects.state,
    recommended_projects.online_days,
    recommended_projects.online_date,
    recommended_projects.how_know,
    recommended_projects.more_links,
    recommended_projects.first_contributions,
    recommended_projects.uploaded_image,
    recommended_projects.video_embed_url,
    recommended_projects.budget,
    recommended_projects.budget_html,
    recommended_projects.terms,
    recommended_projects.terms_html,
    recommended_projects.site,
    recommended_projects.hash_tag,
    recommended_projects.address_city,
    recommended_projects.address_state,
    recommended_projects.address_zip_code,
    recommended_projects.address_neighborhood,
    recommended_projects.foundation_widget,
    recommended_projects.campaign_type,
    recommended_projects.featured,
    recommended_projects.home_page,
    recommended_projects.about_textile,
    recommended_projects.budget_textile,
    recommended_projects.terms_textile,
    recommended_projects.latitude,
    recommended_projects.longitude,
    recommended_projects.referal_link,
    recommended_projects.hero_image,
    recommended_projects.sent_to_analysis_at,
    recommended_projects.organization_type,
    recommended_projects.street_address
   FROM recommended_projects
UNION
 SELECT expiring_projects.origin,
    expiring_projects.id,
    expiring_projects.name,
    expiring_projects.user_id,
    expiring_projects.category_id,
    expiring_projects.goal,
    expiring_projects.about,
    expiring_projects.headline,
    expiring_projects.video_url,
    expiring_projects.short_url,
    expiring_projects.created_at,
    expiring_projects.updated_at,
    expiring_projects.about_html,
    expiring_projects.recommended,
    expiring_projects.home_page_comment,
    expiring_projects.permalink,
    expiring_projects.video_thumbnail,
    expiring_projects.state,
    expiring_projects.online_days,
    expiring_projects.online_date,
    expiring_projects.how_know,
    expiring_projects.more_links,
    expiring_projects.first_contributions,
    expiring_projects.uploaded_image,
    expiring_projects.video_embed_url,
    expiring_projects.budget,
    expiring_projects.budget_html,
    expiring_projects.terms,
    expiring_projects.terms_html,
    expiring_projects.site,
    expiring_projects.hash_tag,
    expiring_projects.address_city,
    expiring_projects.address_state,
    expiring_projects.address_zip_code,
    expiring_projects.address_neighborhood,
    expiring_projects.foundation_widget,
    expiring_projects.campaign_type,
    expiring_projects.featured,
    expiring_projects.home_page,
    expiring_projects.about_textile,
    expiring_projects.budget_textile,
    expiring_projects.terms_textile,
    expiring_projects.latitude,
    expiring_projects.longitude,
    expiring_projects.referal_link,
    expiring_projects.hero_image,
    expiring_projects.sent_to_analysis_at,
    expiring_projects.organization_type,
    expiring_projects.street_address
   FROM expiring_projects
UNION
 SELECT soon_projects.origin,
    soon_projects.id,
    soon_projects.name,
    soon_projects.user_id,
    soon_projects.category_id,
    soon_projects.goal,
    soon_projects.about,
    soon_projects.headline,
    soon_projects.video_url,
    soon_projects.short_url,
    soon_projects.created_at,
    soon_projects.updated_at,
    soon_projects.about_html,
    soon_projects.recommended,
    soon_projects.home_page_comment,
    soon_projects.permalink,
    soon_projects.video_thumbnail,
    soon_projects.state,
    soon_projects.online_days,
    soon_projects.online_date,
    soon_projects.how_know,
    soon_projects.more_links,
    soon_projects.first_contributions,
    soon_projects.uploaded_image,
    soon_projects.video_embed_url,
    soon_projects.budget,
    soon_projects.budget_html,
    soon_projects.terms,
    soon_projects.terms_html,
    soon_projects.site,
    soon_projects.hash_tag,
    soon_projects.address_city,
    soon_projects.address_state,
    soon_projects.address_zip_code,
    soon_projects.address_neighborhood,
    soon_projects.foundation_widget,
    soon_projects.campaign_type,
    soon_projects.featured,
    soon_projects.home_page,
    soon_projects.about_textile,
    soon_projects.budget_textile,
    soon_projects.terms_textile,
    soon_projects.latitude,
    soon_projects.longitude,
    soon_projects.referal_link,
    soon_projects.hero_image,
    soon_projects.sent_to_analysis_at,
    soon_projects.organization_type,
    soon_projects.street_address
   FROM soon_projects
UNION
 SELECT successful_projects.origin,
    successful_projects.id,
    successful_projects.name,
    successful_projects.user_id,
    successful_projects.category_id,
    successful_projects.goal,
    successful_projects.about,
    successful_projects.headline,
    successful_projects.video_url,
    successful_projects.short_url,
    successful_projects.created_at,
    successful_projects.updated_at,
    successful_projects.about_html,
    successful_projects.recommended,
    successful_projects.home_page_comment,
    successful_projects.permalink,
    successful_projects.video_thumbnail,
    successful_projects.state,
    successful_projects.online_days,
    successful_projects.online_date,
    successful_projects.how_know,
    successful_projects.more_links,
    successful_projects.first_contributions,
    successful_projects.uploaded_image,
    successful_projects.video_embed_url,
    successful_projects.budget,
    successful_projects.budget_html,
    successful_projects.terms,
    successful_projects.terms_html,
    successful_projects.site,
    successful_projects.hash_tag,
    successful_projects.address_city,
    successful_projects.address_state,
    successful_projects.address_zip_code,
    successful_projects.address_neighborhood,
    successful_projects.foundation_widget,
    successful_projects.campaign_type,
    successful_projects.featured,
    successful_projects.home_page,
    successful_projects.about_textile,
    successful_projects.budget_textile,
    successful_projects.terms_textile,
    successful_projects.latitude,
    successful_projects.longitude,
    successful_projects.referal_link,
    successful_projects.hero_image,
    successful_projects.sent_to_analysis_at,
    successful_projects.organization_type,
    successful_projects.street_address
   FROM successful_projects;


--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.projects_id_seq OWNED BY public.projects.id;


--
-- Name: recommendations; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.recommendations AS
 SELECT user_id,
    project_id,
    (sum(count))::bigint AS count
   FROM ( SELECT b.user_id,
            recommendations_1.id AS project_id,
            count(DISTINCT recommenders.user_id) AS count
           FROM ((((public.contributions b
             JOIN public.projects p ON ((p.id = b.project_id)))
             JOIN public.contributions backers_same_projects ON ((p.id = backers_same_projects.project_id)))
             JOIN public.contributions recommenders ON ((recommenders.user_id = backers_same_projects.user_id)))
             JOIN public.projects recommendations_1 ON ((recommendations_1.id = recommenders.project_id)))
          WHERE (((b.state)::text = 'confirmed'::text) AND ((backers_same_projects.state)::text = 'confirmed'::text) AND ((recommenders.state)::text = 'confirmed'::text) AND (b.user_id <> backers_same_projects.user_id) AND (recommendations_1.id <> b.project_id) AND ((recommendations_1.state)::text = 'online'::text) AND (NOT (EXISTS ( SELECT true AS bool
                   FROM public.contributions b2
                  WHERE (((b2.state)::text = 'confirmed'::text) AND (b2.user_id = b.user_id) AND (b2.project_id = recommendations_1.id))))))
          GROUP BY b.user_id, recommendations_1.id
        UNION
         SELECT b.user_id,
            recommendations_1.id AS project_id,
            0 AS count
           FROM ((public.contributions b
             JOIN public.projects p ON ((b.project_id = p.id)))
             JOIN public.projects recommendations_1 ON ((recommendations_1.category_id = p.category_id)))
          WHERE (((b.state)::text = 'confirmed'::text) AND ((recommendations_1.state)::text = 'online'::text))) recommendations
  WHERE (NOT (EXISTS ( SELECT true AS bool
           FROM public.contributions b2
          WHERE (((b2.state)::text = 'confirmed'::text) AND (b2.user_id = recommendations.user_id) AND (b2.project_id = recommendations.project_id)))))
  GROUP BY user_id, project_id
  ORDER BY ((sum(count))::bigint) DESC;


--
-- Name: rewards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rewards (
    id integer NOT NULL,
    project_id integer NOT NULL,
    minimum_value numeric NOT NULL,
    maximum_contributions integer,
    description text NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    reindex_versions timestamp without time zone,
    row_order integer,
    days_to_delivery integer,
    soon boolean DEFAULT false,
    title character varying(255) DEFAULT ''::character varying NOT NULL,
    uploaded_image character varying,
    maximum_articles integer,
    CONSTRAINT rewards_maximum_backers_positive CHECK ((maximum_contributions >= 0)),
    CONSTRAINT rewards_minimum_value_positive CHECK ((minimum_value >= (0)::numeric))
);


--
-- Name: rewards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rewards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rewards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rewards_id_seq OWNED BY public.rewards.id;


--
-- Name: routing_numbers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.routing_numbers (
    id integer NOT NULL,
    number character varying(255),
    bank_name character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: routing_numbers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.routing_numbers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: routing_numbers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.routing_numbers_id_seq OWNED BY public.routing_numbers.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.states (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    acronym character varying(255) NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    CONSTRAINT states_acronym_not_blank CHECK ((length(btrim((acronym)::text)) > 0)),
    CONSTRAINT states_name_not_blank CHECK ((length(btrim((name)::text)) > 0))
);


--
-- Name: states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.states_id_seq OWNED BY public.states.id;


--
-- Name: stripe_orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stripe_orders (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    project_id bigint NOT NULL,
    contribution_id bigint,
    stripe_payment_intent_id character varying,
    stripe_checkout_session_id character varying,
    stripe_charge_id character varying,
    stripe_transfer_id character varying,
    amount_cents integer NOT NULL,
    currency character varying DEFAULT 'eur'::character varying,
    platform_fee_cents integer,
    status character varying,
    metadata text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: stripe_orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.stripe_orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stripe_orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.stripe_orders_id_seq OWNED BY public.stripe_orders.id;


--
-- Name: subscriber_reports; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.subscriber_reports AS
 SELECT u.id,
    cs.channel_id,
    u.name,
    u.email
   FROM (public.users u
     JOIN public.channels_subscribers cs ON ((cs.user_id = u.id)));


--
-- Name: taggings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.taggings (
    id integer NOT NULL,
    tag_id integer NOT NULL,
    project_id integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: taggings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.taggings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: taggings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.taggings_id_seq OWNED BY public.taggings.id;


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    visible boolean DEFAULT false
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tags_id_seq OWNED BY public.tags.id;


--
-- Name: total_backed_ranges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.total_backed_ranges (
    name text NOT NULL,
    lower numeric,
    upper numeric
);


--
-- Name: unsubscribes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.unsubscribes (
    id integer NOT NULL,
    user_id integer NOT NULL,
    project_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: unsubscribes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.unsubscribes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: unsubscribes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.unsubscribes_id_seq OWNED BY public.unsubscribes.id;


--
-- Name: updates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.updates (
    id integer NOT NULL,
    user_id integer NOT NULL,
    project_id integer NOT NULL,
    title text,
    comment text NOT NULL,
    comment_html text NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    exclusive boolean DEFAULT false,
    comment_textile text
);


--
-- Name: updates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.updates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: updates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.updates_id_seq OWNED BY public.updates.id;


--
-- Name: user_totals; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.user_totals AS
 SELECT b.user_id AS id,
    b.user_id,
    count(DISTINCT b.project_id) AS total_contributed_projects,
    sum(b.value) AS sum,
    count(*) AS count,
    sum(
        CASE
            WHEN (((p.state)::text <> 'failed'::text) AND (NOT b.credits)) THEN (0)::numeric
            WHEN (((p.state)::text = 'failed'::text) AND b.credits) THEN (0)::numeric
            WHEN (((p.state)::text = 'failed'::text) AND ((((b.state)::text = ANY (ARRAY[('requested_refund'::character varying)::text, ('refunded'::character varying)::text])) AND (NOT b.credits)) OR (b.credits AND (NOT ((b.state)::text = ANY (ARRAY[('requested_refund'::character varying)::text, ('refunded'::character varying)::text])))))) THEN (0)::numeric
            WHEN (((p.state)::text = 'failed'::text) AND (NOT b.credits) AND ((b.state)::text = 'confirmed'::text)) THEN b.value
            ELSE (b.value * ('-1'::integer)::numeric)
        END) AS credits
   FROM (public.contributions b
     JOIN public.projects p ON ((b.project_id = p.id)))
  WHERE ((b.state)::text = ANY (ARRAY[('confirmed'::character varying)::text, ('requested_refund'::character varying)::text, ('refunded'::character varying)::text]))
  GROUP BY b.user_id;


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: vendor_oauth_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vendor_oauth_tokens (
    id integer NOT NULL,
    provider_name character varying(255) NOT NULL,
    access_token text NOT NULL,
    expires_at timestamp without time zone NOT NULL,
    token_type character varying(255) NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: vendor_oauth_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.vendor_oauth_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: vendor_oauth_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.vendor_oauth_tokens_id_seq OWNED BY public.vendor_oauth_tokens.id;


--
-- Name: webhook_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webhook_events (
    id integer NOT NULL,
    serialized_record public.hstore,
    kind character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: webhook_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.webhook_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: webhook_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.webhook_events_id_seq OWNED BY public.webhook_events.id;


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: api_access_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_access_tokens ALTER COLUMN id SET DEFAULT nextval('public.api_access_tokens_id_seq'::regclass);


--
-- Name: article_orders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_orders ALTER COLUMN id SET DEFAULT nextval('public.article_orders_id_seq'::regclass);


--
-- Name: articles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles ALTER COLUMN id SET DEFAULT nextval('public.articles_id_seq'::regclass);


--
-- Name: authorizations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authorizations ALTER COLUMN id SET DEFAULT nextval('public.authorizations_id_seq'::regclass);


--
-- Name: balanced_contributors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.balanced_contributors ALTER COLUMN id SET DEFAULT nextval('public.balanced_contributors_id_seq'::regclass);


--
-- Name: bank_informations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bank_informations ALTER COLUMN id SET DEFAULT nextval('public.bank_informations_id_seq'::regclass);


--
-- Name: banners id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.banners ALTER COLUMN id SET DEFAULT nextval('public.banners_id_seq'::regclass);


--
-- Name: blogo_posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blogo_posts ALTER COLUMN id SET DEFAULT nextval('public.blogo_posts_id_seq'::regclass);


--
-- Name: blogo_taggings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blogo_taggings ALTER COLUMN id SET DEFAULT nextval('public.blogo_taggings_id_seq'::regclass);


--
-- Name: blogo_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blogo_tags ALTER COLUMN id SET DEFAULT nextval('public.blogo_tags_id_seq'::regclass);


--
-- Name: blogo_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blogo_users ALTER COLUMN id SET DEFAULT nextval('public.blogo_users_id_seq'::regclass);


--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: channel_members id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channel_members ALTER COLUMN id SET DEFAULT nextval('public.channel_members_id_seq'::regclass);


--
-- Name: channels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels ALTER COLUMN id SET DEFAULT nextval('public.channels_id_seq'::regclass);


--
-- Name: channels_projects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels_projects ALTER COLUMN id SET DEFAULT nextval('public.channels_projects_id_seq'::regclass);


--
-- Name: channels_subscribers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels_subscribers ALTER COLUMN id SET DEFAULT nextval('public.channels_subscribers_id_seq'::regclass);


--
-- Name: contacts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts ALTER COLUMN id SET DEFAULT nextval('public.contacts_id_seq'::regclass);


--
-- Name: contribution_rewards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contribution_rewards ALTER COLUMN id SET DEFAULT nextval('public.contribution_rewards_id_seq'::regclass);


--
-- Name: contributions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contributions ALTER COLUMN id SET DEFAULT nextval('public.contributions_id_seq'::regclass);


--
-- Name: follows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.follows ALTER COLUMN id SET DEFAULT nextval('public.follows_id_seq'::regclass);


--
-- Name: images id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images ALTER COLUMN id SET DEFAULT nextval('public.images_id_seq'::regclass);


--
-- Name: investment_prospects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.investment_prospects ALTER COLUMN id SET DEFAULT nextval('public.investment_prospects_id_seq'::regclass);


--
-- Name: kyc_files id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kyc_files ALTER COLUMN id SET DEFAULT nextval('public.kyc_files_id_seq'::regclass);


--
-- Name: likes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.likes ALTER COLUMN id SET DEFAULT nextval('public.likes_id_seq'::regclass);


--
-- Name: mangopay_contributors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mangopay_contributors ALTER COLUMN id SET DEFAULT nextval('public.mangopay_contributors_id_seq'::regclass);


--
-- Name: mangopay_registered_cards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mangopay_registered_cards ALTER COLUMN id SET DEFAULT nextval('public.mangopay_registered_cards_id_seq'::regclass);


--
-- Name: mangopay_wallet_handlers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mangopay_wallet_handlers ALTER COLUMN id SET DEFAULT nextval('public.mangopay_wallet_handlers_id_seq'::regclass);


--
-- Name: matches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches ALTER COLUMN id SET DEFAULT nextval('public.matches_id_seq'::regclass);


--
-- Name: matchings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matchings ALTER COLUMN id SET DEFAULT nextval('public.matchings_id_seq'::regclass);


--
-- Name: neighborly_admin_banners id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.neighborly_admin_banners ALTER COLUMN id SET DEFAULT nextval('public.neighborly_admin_banners_id_seq'::regclass);


--
-- Name: neighborly_balanced_orders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.neighborly_balanced_orders ALTER COLUMN id SET DEFAULT nextval('public.neighborly_balanced_orders_id_seq'::regclass);


--
-- Name: neighborly_mangopay_orders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.neighborly_mangopay_orders ALTER COLUMN id SET DEFAULT nextval('public.neighborly_mangopay_orders_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- Name: oauth_providers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_providers ALTER COLUMN id SET DEFAULT nextval('public.oauth_providers_id_seq'::regclass);


--
-- Name: orange_money_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orange_money_transactions ALTER COLUMN id SET DEFAULT nextval('public.orange_money_transactions_id_seq'::regclass);


--
-- Name: organizations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations ALTER COLUMN id SET DEFAULT nextval('public.organizations_id_seq'::regclass);


--
-- Name: partners id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partners ALTER COLUMN id SET DEFAULT nextval('public.partners_id_seq'::regclass);


--
-- Name: pay_plus_africa_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pay_plus_africa_transactions ALTER COLUMN id SET DEFAULT nextval('public.pay_plus_africa_transactions_id_seq'::regclass);


--
-- Name: payment_notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_notifications ALTER COLUMN id SET DEFAULT nextval('public.payment_notifications_id_seq'::regclass);


--
-- Name: payouts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payouts ALTER COLUMN id SET DEFAULT nextval('public.payouts_id_seq'::regclass);


--
-- Name: press_assets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.press_assets ALTER COLUMN id SET DEFAULT nextval('public.press_assets_id_seq'::regclass);


--
-- Name: project_documents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_documents ALTER COLUMN id SET DEFAULT nextval('public.project_documents_id_seq'::regclass);


--
-- Name: project_faqs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_faqs ALTER COLUMN id SET DEFAULT nextval('public.project_faqs_id_seq'::regclass);


--
-- Name: project_totals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_totals ALTER COLUMN id SET DEFAULT nextval('public.project_totals_id_seq'::regclass);


--
-- Name: projects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects ALTER COLUMN id SET DEFAULT nextval('public.projects_id_seq'::regclass);


--
-- Name: rewards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rewards ALTER COLUMN id SET DEFAULT nextval('public.rewards_id_seq'::regclass);


--
-- Name: routing_numbers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routing_numbers ALTER COLUMN id SET DEFAULT nextval('public.routing_numbers_id_seq'::regclass);


--
-- Name: states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.states ALTER COLUMN id SET DEFAULT nextval('public.states_id_seq'::regclass);


--
-- Name: stripe_orders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stripe_orders ALTER COLUMN id SET DEFAULT nextval('public.stripe_orders_id_seq'::regclass);


--
-- Name: taggings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taggings ALTER COLUMN id SET DEFAULT nextval('public.taggings_id_seq'::regclass);


--
-- Name: tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags ALTER COLUMN id SET DEFAULT nextval('public.tags_id_seq'::regclass);


--
-- Name: unsubscribes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unsubscribes ALTER COLUMN id SET DEFAULT nextval('public.unsubscribes_id_seq'::regclass);


--
-- Name: updates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.updates ALTER COLUMN id SET DEFAULT nextval('public.updates_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: vendor_oauth_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_oauth_tokens ALTER COLUMN id SET DEFAULT nextval('public.vendor_oauth_tokens_id_seq'::regclass);


--
-- Name: webhook_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_events ALTER COLUMN id SET DEFAULT nextval('public.webhook_events_id_seq'::regclass);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: api_access_tokens api_access_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_access_tokens
    ADD CONSTRAINT api_access_tokens_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: article_orders article_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_orders
    ADD CONSTRAINT article_orders_pkey PRIMARY KEY (id);


--
-- Name: articles articles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_pkey PRIMARY KEY (id);


--
-- Name: authorizations authorizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authorizations
    ADD CONSTRAINT authorizations_pkey PRIMARY KEY (id);


--
-- Name: contributions backers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contributions
    ADD CONSTRAINT backers_pkey PRIMARY KEY (id);


--
-- Name: balanced_contributors balanced_contributors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.balanced_contributors
    ADD CONSTRAINT balanced_contributors_pkey PRIMARY KEY (id);


--
-- Name: bank_informations bank_informations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bank_informations
    ADD CONSTRAINT bank_informations_pkey PRIMARY KEY (id);


--
-- Name: banners banners_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.banners
    ADD CONSTRAINT banners_pkey PRIMARY KEY (id);


--
-- Name: blogo_posts blogo_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blogo_posts
    ADD CONSTRAINT blogo_posts_pkey PRIMARY KEY (id);


--
-- Name: blogo_taggings blogo_taggings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blogo_taggings
    ADD CONSTRAINT blogo_taggings_pkey PRIMARY KEY (id);


--
-- Name: blogo_tags blogo_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blogo_tags
    ADD CONSTRAINT blogo_tags_pkey PRIMARY KEY (id);


--
-- Name: blogo_users blogo_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blogo_users
    ADD CONSTRAINT blogo_users_pkey PRIMARY KEY (id);


--
-- Name: categories categories_name_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_name_unique UNIQUE (name_pt);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: channel_members channel_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channel_members
    ADD CONSTRAINT channel_members_pkey PRIMARY KEY (id);


--
-- Name: channels channel_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels
    ADD CONSTRAINT channel_profiles_pkey PRIMARY KEY (id);


--
-- Name: channels_projects channels_projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels_projects
    ADD CONSTRAINT channels_projects_pkey PRIMARY KEY (id);


--
-- Name: channels_subscribers channels_subscribers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels_subscribers
    ADD CONSTRAINT channels_subscribers_pkey PRIMARY KEY (id);


--
-- Name: contacts company_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts
    ADD CONSTRAINT company_contacts_pkey PRIMARY KEY (id);


--
-- Name: contribution_rewards contribution_rewards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contribution_rewards
    ADD CONSTRAINT contribution_rewards_pkey PRIMARY KEY (id);


--
-- Name: follows follows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT follows_pkey PRIMARY KEY (id);


--
-- Name: images images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images
    ADD CONSTRAINT images_pkey PRIMARY KEY (id);


--
-- Name: investment_prospects investment_prospects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.investment_prospects
    ADD CONSTRAINT investment_prospects_pkey PRIMARY KEY (id);


--
-- Name: kyc_files kyc_files_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kyc_files
    ADD CONSTRAINT kyc_files_pkey PRIMARY KEY (id);


--
-- Name: likes likes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_pkey PRIMARY KEY (id);


--
-- Name: mangopay_contributors mangopay_contributors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mangopay_contributors
    ADD CONSTRAINT mangopay_contributors_pkey PRIMARY KEY (id);


--
-- Name: mangopay_registered_cards mangopay_registered_cards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mangopay_registered_cards
    ADD CONSTRAINT mangopay_registered_cards_pkey PRIMARY KEY (id);


--
-- Name: mangopay_wallet_handlers mangopay_wallet_handlers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mangopay_wallet_handlers
    ADD CONSTRAINT mangopay_wallet_handlers_pkey PRIMARY KEY (id);


--
-- Name: matches matches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_pkey PRIMARY KEY (id);


--
-- Name: matchings matchings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matchings
    ADD CONSTRAINT matchings_pkey PRIMARY KEY (id);


--
-- Name: neighborly_admin_banners neighborly_admin_banners_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.neighborly_admin_banners
    ADD CONSTRAINT neighborly_admin_banners_pkey PRIMARY KEY (id);


--
-- Name: neighborly_balanced_orders neighborly_balanced_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.neighborly_balanced_orders
    ADD CONSTRAINT neighborly_balanced_orders_pkey PRIMARY KEY (id);


--
-- Name: neighborly_mangopay_orders neighborly_mangopay_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.neighborly_mangopay_orders
    ADD CONSTRAINT neighborly_mangopay_orders_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: oauth_providers oauth_providers_name_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_providers
    ADD CONSTRAINT oauth_providers_name_unique UNIQUE (name);


--
-- Name: oauth_providers oauth_providers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_providers
    ADD CONSTRAINT oauth_providers_pkey PRIMARY KEY (id);


--
-- Name: orange_money_transactions orange_money_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orange_money_transactions
    ADD CONSTRAINT orange_money_transactions_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: partners partners_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partners
    ADD CONSTRAINT partners_pkey PRIMARY KEY (id);


--
-- Name: pay_plus_africa_transactions pay_plus_africa_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pay_plus_africa_transactions
    ADD CONSTRAINT pay_plus_africa_transactions_pkey PRIMARY KEY (id);


--
-- Name: payment_notifications payment_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_notifications
    ADD CONSTRAINT payment_notifications_pkey PRIMARY KEY (id);


--
-- Name: payouts payouts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payouts
    ADD CONSTRAINT payouts_pkey PRIMARY KEY (id);


--
-- Name: press_assets press_assets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.press_assets
    ADD CONSTRAINT press_assets_pkey PRIMARY KEY (id);


--
-- Name: project_documents project_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_documents
    ADD CONSTRAINT project_documents_pkey PRIMARY KEY (id);


--
-- Name: project_faqs project_faqs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_faqs
    ADD CONSTRAINT project_faqs_pkey PRIMARY KEY (id);


--
-- Name: project_totals project_totals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_totals
    ADD CONSTRAINT project_totals_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: rewards rewards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rewards
    ADD CONSTRAINT rewards_pkey PRIMARY KEY (id);


--
-- Name: routing_numbers routing_numbers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routing_numbers
    ADD CONSTRAINT routing_numbers_pkey PRIMARY KEY (id);


--
-- Name: states states_acronym_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.states
    ADD CONSTRAINT states_acronym_unique UNIQUE (acronym);


--
-- Name: states states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.states
    ADD CONSTRAINT states_pkey PRIMARY KEY (id);


--
-- Name: stripe_orders stripe_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stripe_orders
    ADD CONSTRAINT stripe_orders_pkey PRIMARY KEY (id);


--
-- Name: taggings taggings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taggings
    ADD CONSTRAINT taggings_pkey PRIMARY KEY (id);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: total_backed_ranges total_backed_ranges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.total_backed_ranges
    ADD CONSTRAINT total_backed_ranges_pkey PRIMARY KEY (name);


--
-- Name: unsubscribes unsubscribes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unsubscribes
    ADD CONSTRAINT unsubscribes_pkey PRIMARY KEY (id);


--
-- Name: updates updates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.updates
    ADD CONSTRAINT updates_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: vendor_oauth_tokens vendor_oauth_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_oauth_tokens
    ADD CONSTRAINT vendor_oauth_tokens_pkey PRIMARY KEY (id);


--
-- Name: webhook_events webhook_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_events
    ADD CONSTRAINT webhook_events_pkey PRIMARY KEY (id);


--
-- Name: fk__authorizations_oauth_provider_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__authorizations_oauth_provider_id ON public.authorizations USING btree (oauth_provider_id);


--
-- Name: fk__authorizations_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__authorizations_user_id ON public.authorizations USING btree (user_id);


--
-- Name: fk__blogo_posts_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__blogo_posts_user_id ON public.blogo_posts USING btree (user_id);


--
-- Name: fk__blogo_taggings_blogo_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__blogo_taggings_blogo_post_id ON public.blogo_taggings USING btree (post_id);


--
-- Name: fk__blogo_taggings_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__blogo_taggings_tag_id ON public.blogo_taggings USING btree (tag_id);


--
-- Name: fk__channels_subscribers_channel_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__channels_subscribers_channel_id ON public.channels_subscribers USING btree (channel_id);


--
-- Name: fk__channels_subscribers_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__channels_subscribers_user_id ON public.channels_subscribers USING btree (user_id);


--
-- Name: fk__channels_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__channels_user_id ON public.channels USING btree (user_id);


--
-- Name: fk__mangopay_contributors_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__mangopay_contributors_organization_id ON public.mangopay_contributors USING btree (organization_id);


--
-- Name: fk__notifications_channel_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__notifications_channel_id ON public.notifications USING btree (channel_id);


--
-- Name: fk__notifications_company_contact_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk__notifications_company_contact_id ON public.notifications USING btree (contact_id);


--
-- Name: fk_followables; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk_followables ON public.follows USING btree (followableid, followable_type);


--
-- Name: fk_follows; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk_follows ON public.follows USING btree (followerid, follower_type);


--
-- Name: fk_likeables; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk_likeables ON public.likes USING btree (likeableid, likeable_type);


--
-- Name: fk_likes; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk_likes ON public.likes USING btree (likerid, liker_type);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_api_access_tokens_on_expired; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_api_access_tokens_on_expired ON public.api_access_tokens USING btree (expired);


--
-- Name: index_api_access_tokens_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_api_access_tokens_on_user_id ON public.api_access_tokens USING btree (user_id);


--
-- Name: index_article_orders_on_article_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_article_orders_on_article_id ON public.article_orders USING btree (article_id);


--
-- Name: index_article_orders_on_contribution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_article_orders_on_contribution_id ON public.article_orders USING btree (contribution_id);


--
-- Name: index_articles_on_reward_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_articles_on_reward_id ON public.articles USING btree (reward_id);


--
-- Name: index_authorizations_on_oauth_provider_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_authorizations_on_oauth_provider_id_and_user_id ON public.authorizations USING btree (oauth_provider_id, user_id);


--
-- Name: index_authorizations_on_uid_and_oauth_provider_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_authorizations_on_uid_and_oauth_provider_id ON public.authorizations USING btree (uid, oauth_provider_id);


--
-- Name: index_balanced_contributors_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_balanced_contributors_on_user_id ON public.balanced_contributors USING btree (user_id);


--
-- Name: index_bank_informations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bank_informations_on_user_id ON public.bank_informations USING btree (user_id);


--
-- Name: index_blogo_posts_on_permalink; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_blogo_posts_on_permalink ON public.blogo_posts USING btree (permalink);


--
-- Name: index_blogo_posts_on_published_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blogo_posts_on_published_at ON public.blogo_posts USING btree (published_at);


--
-- Name: index_blogo_posts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blogo_posts_on_user_id ON public.blogo_posts USING btree (user_id);


--
-- Name: index_blogo_taggings_on_tag_id_and_blogo_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_blogo_taggings_on_tag_id_and_blogo_post_id ON public.blogo_taggings USING btree (tag_id, post_id);


--
-- Name: index_blogo_tags_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_blogo_tags_on_name ON public.blogo_tags USING btree (name);


--
-- Name: index_blogo_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_blogo_users_on_email ON public.blogo_users USING btree (email);


--
-- Name: index_categories_on_name_pt; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_categories_on_name_pt ON public.categories USING btree (name_pt);


--
-- Name: index_channel_members_on_channel_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_channel_members_on_channel_id ON public.channel_members USING btree (channel_id);


--
-- Name: index_channel_members_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_channel_members_on_user_id ON public.channel_members USING btree (user_id);


--
-- Name: index_channels_on_permalink; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_channels_on_permalink ON public.channels USING btree (permalink);


--
-- Name: index_channels_projects_on_channel_id_and_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_channels_projects_on_channel_id_and_project_id ON public.channels_projects USING btree (channel_id, project_id);


--
-- Name: index_channels_projects_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_channels_projects_on_project_id ON public.channels_projects USING btree (project_id);


--
-- Name: index_channels_subscribers_on_user_id_and_channel_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_channels_subscribers_on_user_id_and_channel_id ON public.channels_subscribers USING btree (user_id, channel_id);


--
-- Name: index_contribution_rewards_on_contribution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contribution_rewards_on_contribution_id ON public.contribution_rewards USING btree (contribution_id);


--
-- Name: index_contribution_rewards_on_reward_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contribution_rewards_on_reward_id ON public.contribution_rewards USING btree (reward_id);


--
-- Name: index_contributions_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contributions_on_key ON public.contributions USING btree (key);


--
-- Name: index_contributions_on_matching_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contributions_on_matching_id ON public.contributions USING btree (matching_id);


--
-- Name: index_contributions_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contributions_on_project_id ON public.contributions USING btree (project_id);


--
-- Name: index_contributions_on_reward_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contributions_on_reward_id ON public.contributions USING btree (reward_id);


--
-- Name: index_contributions_on_stripe_refunded; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contributions_on_stripe_refunded ON public.contributions USING btree (stripe_refunded);


--
-- Name: index_contributions_on_stripe_transferred; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contributions_on_stripe_transferred ON public.contributions USING btree (stripe_transferred);


--
-- Name: index_contributions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contributions_on_user_id ON public.contributions USING btree (user_id);


--
-- Name: index_images_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_images_on_user_id ON public.images USING btree (user_id);


--
-- Name: index_investment_prospects_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_investment_prospects_on_user_id ON public.investment_prospects USING btree (user_id);


--
-- Name: index_kyc_files_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_kyc_files_on_user_id ON public.kyc_files USING btree (user_id);


--
-- Name: index_mangopay_contributors_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mangopay_contributors_on_user_id ON public.mangopay_contributors USING btree (user_id);


--
-- Name: index_mangopay_registered_cards_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mangopay_registered_cards_on_user_id ON public.mangopay_registered_cards USING btree (user_id);


--
-- Name: index_mangopay_wallet_handlers_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mangopay_wallet_handlers_on_project_id ON public.mangopay_wallet_handlers USING btree (project_id);


--
-- Name: index_matches_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_matches_on_project_id ON public.matches USING btree (project_id);


--
-- Name: index_matches_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_matches_on_user_id ON public.matches USING btree (user_id);


--
-- Name: index_matchings_on_contribution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_matchings_on_contribution_id ON public.matchings USING btree (contribution_id);


--
-- Name: index_matchings_on_match_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_matchings_on_match_id ON public.matchings USING btree (match_id);


--
-- Name: index_neighborly_balanced_orders_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_neighborly_balanced_orders_on_project_id ON public.neighborly_balanced_orders USING btree (project_id);


--
-- Name: index_neighborly_mangopay_orders_on_contribution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_neighborly_mangopay_orders_on_contribution_id ON public.neighborly_mangopay_orders USING btree (contribution_id);


--
-- Name: index_neighborly_mangopay_orders_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_neighborly_mangopay_orders_on_project_id ON public.neighborly_mangopay_orders USING btree (project_id);


--
-- Name: index_neighborly_mangopay_orders_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_neighborly_mangopay_orders_on_user_id ON public.neighborly_mangopay_orders USING btree (user_id);


--
-- Name: index_notifications_on_match_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_match_id ON public.notifications USING btree (match_id);


--
-- Name: index_notifications_on_update_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_update_id ON public.notifications USING btree (update_id);


--
-- Name: index_orange_money_transactions_on_contribution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orange_money_transactions_on_contribution_id ON public.orange_money_transactions USING btree (contribution_id);


--
-- Name: index_organizations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_organizations_on_user_id ON public.organizations USING btree (user_id);


--
-- Name: index_pay_plus_africa_transactions_on_contribution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pay_plus_africa_transactions_on_contribution_id ON public.pay_plus_africa_transactions USING btree (contribution_id);


--
-- Name: index_payment_notifications_on_contribution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_notifications_on_contribution_id ON public.payment_notifications USING btree (contribution_id);


--
-- Name: index_payment_notifications_on_match_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_notifications_on_match_id ON public.payment_notifications USING btree (match_id);


--
-- Name: index_payouts_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payouts_on_project_id ON public.payouts USING btree (project_id);


--
-- Name: index_payouts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payouts_on_user_id ON public.payouts USING btree (user_id);


--
-- Name: index_project_documents_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_documents_on_project_id ON public.project_documents USING btree (project_id);


--
-- Name: index_project_faqs_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_faqs_on_project_id ON public.project_faqs USING btree (project_id);


--
-- Name: index_project_totals_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_totals_on_project_id ON public.project_totals USING btree (project_id);


--
-- Name: index_projects_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_category_id ON public.projects USING btree (category_id);


--
-- Name: index_projects_on_latitude_and_longitude; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_latitude_and_longitude ON public.projects USING btree (latitude, longitude);


--
-- Name: index_projects_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_name ON public.projects USING btree (name);


--
-- Name: index_projects_on_partner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_partner_id ON public.projects USING btree (partner_id);


--
-- Name: index_projects_on_permalink; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_permalink ON public.projects USING btree (permalink);


--
-- Name: index_projects_on_stripe_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_stripe_account_id ON public.projects USING btree (stripe_account_id);


--
-- Name: index_projects_on_stripe_settled_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_stripe_settled_at ON public.projects USING btree (stripe_settled_at);


--
-- Name: index_projects_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_user_id ON public.projects USING btree (user_id);


--
-- Name: index_rewards_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rewards_on_project_id ON public.rewards USING btree (project_id);


--
-- Name: index_stripe_orders_on_contribution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stripe_orders_on_contribution_id ON public.stripe_orders USING btree (contribution_id);


--
-- Name: index_stripe_orders_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stripe_orders_on_project_id ON public.stripe_orders USING btree (project_id);


--
-- Name: index_stripe_orders_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stripe_orders_on_status ON public.stripe_orders USING btree (status);


--
-- Name: index_stripe_orders_on_stripe_checkout_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stripe_orders_on_stripe_checkout_session_id ON public.stripe_orders USING btree (stripe_checkout_session_id);


--
-- Name: index_stripe_orders_on_stripe_payment_intent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stripe_orders_on_stripe_payment_intent_id ON public.stripe_orders USING btree (stripe_payment_intent_id);


--
-- Name: index_stripe_orders_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stripe_orders_on_user_id ON public.stripe_orders USING btree (user_id);


--
-- Name: index_taggings_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taggings_on_project_id ON public.taggings USING btree (project_id);


--
-- Name: index_taggings_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taggings_on_tag_id ON public.taggings USING btree (tag_id);


--
-- Name: index_unsubscribes_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_unsubscribes_on_project_id ON public.unsubscribes USING btree (project_id);


--
-- Name: index_unsubscribes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_unsubscribes_on_user_id ON public.unsubscribes USING btree (user_id);


--
-- Name: index_updates_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_updates_on_project_id ON public.updates USING btree (project_id);


--
-- Name: index_users_on_confirmation_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_confirmation_token ON public.users USING btree (confirmation_token);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_latitude_and_longitude; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_latitude_and_longitude ON public.users USING btree (latitude, longitude);


--
-- Name: index_users_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_name ON public.users USING btree (name);


--
-- Name: index_users_on_partner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_partner_id ON public.users USING btree (partner_id);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: index_users_on_stripe_connect_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_stripe_connect_account_id ON public.users USING btree (stripe_connect_account_id);


--
-- Name: index_users_on_stripe_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_stripe_customer_id ON public.users USING btree (stripe_customer_id);


--
-- Name: index_vendor_oauth_tokens_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_vendor_oauth_tokens_on_expires_at ON public.vendor_oauth_tokens USING btree (expires_at);


--
-- Name: index_vendor_oauth_tokens_on_provider_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_vendor_oauth_tokens_on_provider_name ON public.vendor_oauth_tokens USING btree (provider_name);


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_schema_migrations ON public.schema_migrations USING btree (version);


--
-- Name: funding_raised_per_project_reports _RETURN; Type: RULE; Schema: public; Owner: -
--

CREATE OR REPLACE VIEW public.funding_raised_per_project_reports AS
 SELECT project.id AS project_id,
    project.name AS project_name,
    sum(contributions.value) AS total_raised,
    count(*) AS total_backs,
    count(DISTINCT contributions.user_id) AS total_backers
   FROM (public.contributions
     JOIN public.projects project ON ((project.id = contributions.project_id)))
  WHERE ((contributions.state)::text <> ALL (ARRAY[('waiting_confirmation'::character varying)::text, ('pending'::character varying)::text, ('canceled'::character varying)::text, 'deleted'::text]))
  GROUP BY project.id;


--
-- Name: neighborly_admin_funding_raised_per_project_reports _RETURN; Type: RULE; Schema: public; Owner: -
--

CREATE OR REPLACE VIEW public.neighborly_admin_funding_raised_per_project_reports AS
 SELECT project.id AS project_id,
    project.name AS project_name,
    sum(contributions.value) AS total_raised,
    count(*) AS total_backs,
    count(DISTINCT contributions.user_id) AS total_backers
   FROM (public.contributions
     JOIN public.projects project ON ((project.id = contributions.project_id)))
  WHERE ((contributions.state)::text <> ALL (ARRAY[('waiting_confirmation'::character varying)::text, ('pending'::character varying)::text, ('canceled'::character varying)::text, 'deleted'::text]))
  GROUP BY project.id;


--
-- Name: recommendations prevent_deletion_of_recommendations; Type: RULE; Schema: public; Owner: -
--

CREATE RULE prevent_deletion_of_recommendations AS
    ON DELETE TO public.recommendations DO INSTEAD NOTHING;


--
-- Name: contributions contributions_project_id_reference; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contributions
    ADD CONSTRAINT contributions_project_id_reference FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: contributions contributions_reward_id_reference; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contributions
    ADD CONSTRAINT contributions_reward_id_reference FOREIGN KEY (reward_id) REFERENCES public.rewards(id);


--
-- Name: contributions contributions_user_id_reference; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contributions
    ADD CONSTRAINT contributions_user_id_reference FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: api_access_tokens fk_api_access_tokens_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_access_tokens
    ADD CONSTRAINT fk_api_access_tokens_user_id FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: authorizations fk_authorizations_oauth_provider_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authorizations
    ADD CONSTRAINT fk_authorizations_oauth_provider_id FOREIGN KEY (oauth_provider_id) REFERENCES public.oauth_providers(id);


--
-- Name: authorizations fk_authorizations_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authorizations
    ADD CONSTRAINT fk_authorizations_user_id FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: balanced_contributors fk_balanced_contributors_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.balanced_contributors
    ADD CONSTRAINT fk_balanced_contributors_user_id FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: bank_informations fk_bank_informations_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bank_informations
    ADD CONSTRAINT fk_bank_informations_user_id FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: blogo_posts fk_blogo_posts_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blogo_posts
    ADD CONSTRAINT fk_blogo_posts_user_id FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: blogo_taggings fk_blogo_taggings_blogo_post_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blogo_taggings
    ADD CONSTRAINT fk_blogo_taggings_blogo_post_id FOREIGN KEY (post_id) REFERENCES public.blogo_posts(id);


--
-- Name: blogo_taggings fk_blogo_taggings_tag_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blogo_taggings
    ADD CONSTRAINT fk_blogo_taggings_tag_id FOREIGN KEY (tag_id) REFERENCES public.tags(id);


--
-- Name: channel_members fk_channel_members_channel_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channel_members
    ADD CONSTRAINT fk_channel_members_channel_id FOREIGN KEY (channel_id) REFERENCES public.channels(id);


--
-- Name: channel_members fk_channel_members_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channel_members
    ADD CONSTRAINT fk_channel_members_user_id FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: channels_projects fk_channels_projects_channel_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels_projects
    ADD CONSTRAINT fk_channels_projects_channel_id FOREIGN KEY (channel_id) REFERENCES public.channels(id);


--
-- Name: channels_projects fk_channels_projects_project_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels_projects
    ADD CONSTRAINT fk_channels_projects_project_id FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: channels_subscribers fk_channels_subscribers_channel_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels_subscribers
    ADD CONSTRAINT fk_channels_subscribers_channel_id FOREIGN KEY (channel_id) REFERENCES public.channels(id);


--
-- Name: channels_subscribers fk_channels_subscribers_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels_subscribers
    ADD CONSTRAINT fk_channels_subscribers_user_id FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: channels fk_channels_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels
    ADD CONSTRAINT fk_channels_user_id FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: contributions fk_contributions_matching_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contributions
    ADD CONSTRAINT fk_contributions_matching_id FOREIGN KEY (matching_id) REFERENCES public.matchings(id);


--
-- Name: images fk_images_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images
    ADD CONSTRAINT fk_images_user_id FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: investment_prospects fk_investment_prospects_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.investment_prospects
    ADD CONSTRAINT fk_investment_prospects_user_id FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: kyc_files fk_kyc_files_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kyc_files
    ADD CONSTRAINT fk_kyc_files_user_id FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: mangopay_contributors fk_mangopay_contributors_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mangopay_contributors
    ADD CONSTRAINT fk_mangopay_contributors_user_id FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: mangopay_registered_cards fk_mangopay_registered_cards_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mangopay_registered_cards
    ADD CONSTRAINT fk_mangopay_registered_cards_user_id FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: mangopay_wallet_handlers fk_mangopay_wallet_handlers_project_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mangopay_wallet_handlers
    ADD CONSTRAINT fk_mangopay_wallet_handlers_project_id FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: matches fk_matches_project_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT fk_matches_project_id FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: matches fk_matches_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT fk_matches_user_id FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: matchings fk_matchings_contribution_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matchings
    ADD CONSTRAINT fk_matchings_contribution_id FOREIGN KEY (contribution_id) REFERENCES public.contributions(id);


--
-- Name: matchings fk_matchings_match_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matchings
    ADD CONSTRAINT fk_matchings_match_id FOREIGN KEY (match_id) REFERENCES public.matches(id);


--
-- Name: neighborly_balanced_orders fk_neighborly_balanced_orders_project_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.neighborly_balanced_orders
    ADD CONSTRAINT fk_neighborly_balanced_orders_project_id FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: neighborly_mangopay_orders fk_neighborly_mangopay_orders_contribution_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.neighborly_mangopay_orders
    ADD CONSTRAINT fk_neighborly_mangopay_orders_contribution_id FOREIGN KEY (contribution_id) REFERENCES public.contributions(id);


--
-- Name: neighborly_mangopay_orders fk_neighborly_mangopay_orders_project_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.neighborly_mangopay_orders
    ADD CONSTRAINT fk_neighborly_mangopay_orders_project_id FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: neighborly_mangopay_orders fk_neighborly_mangopay_orders_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.neighborly_mangopay_orders
    ADD CONSTRAINT fk_neighborly_mangopay_orders_user_id FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: notifications fk_notifications_channel_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT fk_notifications_channel_id FOREIGN KEY (channel_id) REFERENCES public.channels(id);


--
-- Name: notifications fk_notifications_company_contact_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT fk_notifications_company_contact_id FOREIGN KEY (contact_id) REFERENCES public.contacts(id);


--
-- Name: notifications fk_notifications_match_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT fk_notifications_match_id FOREIGN KEY (match_id) REFERENCES public.matches(id);


--
-- Name: orange_money_transactions fk_orange_money_transactions_contribution_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orange_money_transactions
    ADD CONSTRAINT fk_orange_money_transactions_contribution_id FOREIGN KEY (contribution_id) REFERENCES public.contributions(id);


--
-- Name: organizations fk_organizations_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT fk_organizations_user_id FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: pay_plus_africa_transactions fk_pay_plus_africa_transactions_contribution_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pay_plus_africa_transactions
    ADD CONSTRAINT fk_pay_plus_africa_transactions_contribution_id FOREIGN KEY (contribution_id) REFERENCES public.contributions(id);


--
-- Name: payment_notifications fk_payment_notifications_match_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_notifications
    ADD CONSTRAINT fk_payment_notifications_match_id FOREIGN KEY (match_id) REFERENCES public.matches(id);


--
-- Name: payouts fk_payouts_project_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payouts
    ADD CONSTRAINT fk_payouts_project_id FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: payouts fk_payouts_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payouts
    ADD CONSTRAINT fk_payouts_user_id FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: project_documents fk_project_documents_project_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_documents
    ADD CONSTRAINT fk_project_documents_project_id FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: project_faqs fk_project_faqs_project_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_faqs
    ADD CONSTRAINT fk_project_faqs_project_id FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: project_totals fk_project_totals_project_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_totals
    ADD CONSTRAINT fk_project_totals_project_id FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: projects fk_projects_partner_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fk_projects_partner_id FOREIGN KEY (partner_id) REFERENCES public.partners(id);


--
-- Name: article_orders fk_rails_0be3f3dd9f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_orders
    ADD CONSTRAINT fk_rails_0be3f3dd9f FOREIGN KEY (contribution_id) REFERENCES public.contributions(id);


--
-- Name: stripe_orders fk_rails_3346390b5a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stripe_orders
    ADD CONSTRAINT fk_rails_3346390b5a FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: stripe_orders fk_rails_3931d11aee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stripe_orders
    ADD CONSTRAINT fk_rails_3931d11aee FOREIGN KEY (contribution_id) REFERENCES public.contributions(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: stripe_orders fk_rails_c3a2f46289; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stripe_orders
    ADD CONSTRAINT fk_rails_c3a2f46289 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: article_orders fk_rails_c677354e00; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_orders
    ADD CONSTRAINT fk_rails_c677354e00 FOREIGN KEY (article_id) REFERENCES public.articles(id);


--
-- Name: articles fk_rails_e6bb01b2d7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT fk_rails_e6bb01b2d7 FOREIGN KEY (reward_id) REFERENCES public.rewards(id);


--
-- Name: contribution_rewards fk_rails_eac8fce054; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contribution_rewards
    ADD CONSTRAINT fk_rails_eac8fce054 FOREIGN KEY (reward_id) REFERENCES public.rewards(id);


--
-- Name: contribution_rewards fk_rails_f479de45dd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contribution_rewards
    ADD CONSTRAINT fk_rails_f479de45dd FOREIGN KEY (contribution_id) REFERENCES public.contributions(id);


--
-- Name: taggings fk_taggings_project_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taggings
    ADD CONSTRAINT fk_taggings_project_id FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: taggings fk_taggings_tag_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taggings
    ADD CONSTRAINT fk_taggings_tag_id FOREIGN KEY (tag_id) REFERENCES public.tags(id);


--
-- Name: users fk_users_partner_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_users_partner_id FOREIGN KEY (partner_id) REFERENCES public.partners(id);


--
-- Name: notifications notifications_backer_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_backer_id_fk FOREIGN KEY (contribution_id) REFERENCES public.contributions(id);


--
-- Name: notifications notifications_project_id_reference; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_project_id_reference FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: notifications notifications_update_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_update_id_fk FOREIGN KEY (update_id) REFERENCES public.updates(id);


--
-- Name: notifications notifications_user_id_reference; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_reference FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: payment_notifications payment_notifications_backer_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_notifications
    ADD CONSTRAINT payment_notifications_backer_id_fk FOREIGN KEY (contribution_id) REFERENCES public.contributions(id);


--
-- Name: projects projects_category_id_reference; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_category_id_reference FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: projects projects_user_id_reference; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_user_id_reference FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: rewards rewards_project_id_reference; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rewards
    ADD CONSTRAINT rewards_project_id_reference FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: unsubscribes unsubscribes_project_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unsubscribes
    ADD CONSTRAINT unsubscribes_project_id_fk FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: unsubscribes unsubscribes_user_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unsubscribes
    ADD CONSTRAINT unsubscribes_user_id_fk FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: updates updates_project_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.updates
    ADD CONSTRAINT updates_project_id_fk FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: updates updates_user_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.updates
    ADD CONSTRAINT updates_user_id_fk FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict XcY9LmBB2rMjblDdmnNBiu0DpHc1HRusLvL7NbMNypdNnc96aJjUA6xC8fXMClF

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20121226120921'),
('20121227012003'),
('20121227012324'),
('20121230111351'),
('20130102180139'),
('20130104005632'),
('20130104104501'),
('20130105123546'),
('20130110191750'),
('20130117205659'),
('20130118193907'),
('20130121162447'),
('20130121204224'),
('20130121212325'),
('20130131121553'),
('20130201200604'),
('20130201202648'),
('20130201202829'),
('20130201205659'),
('20130204192704'),
('20130205143533'),
('20130206121758'),
('20130211174609'),
('20130212145115'),
('20130213184141'),
('20130218201312'),
('20130218201751'),
('20130221171018'),
('20130221172840'),
('20130221175717'),
('20130221184144'),
('20130221185532'),
('20130221201732'),
('20130222163633'),
('20130225135512'),
('20130225141802'),
('20130228141234'),
('20130304193806'),
('20130307074614'),
('20130307090153'),
('20130308200907'),
('20130311191444'),
('20130311192846'),
('20130312001021'),
('20130313032607'),
('20130313034356'),
('20130319131919'),
('20130410181958'),
('20130410190247'),
('20130410191240'),
('20130411193016'),
('20130419184530'),
('20130422071805'),
('20130422072051'),
('20130423162359'),
('20130424173128'),
('20130426204503'),
('20130429142823'),
('20130429144749'),
('20130429153115'),
('20130430203333'),
('20130502175814'),
('20130505013655'),
('20130506191243'),
('20130506191508'),
('20130514132519'),
('20130514185010'),
('20130514185116'),
('20130514185926'),
('20130515192404'),
('20130523144013'),
('20130523173609'),
('20130527204639'),
('20130529171845'),
('20130604171730'),
('20130604172253'),
('20130604175953'),
('20130604180503'),
('20130607222330'),
('20130617175402'),
('20130618175432'),
('20130626122439'),
('20130626124055'),
('20130702192659'),
('20130703171547'),
('20130705131825'),
('20130705184845'),
('20130710122804'),
('20130722222945'),
('20130730232043'),
('20130805230126'),
('20130812191450'),
('20130814174329'),
('20130815161926'),
('20130818015857'),
('20130819184232'),
('20130819204154'),
('20130819223216'),
('20130820110933'),
('20130820154632'),
('20130820161734'),
('20130820162240'),
('20130820170244'),
('20130820191030'),
('20130820192708'),
('20130820203742'),
('20130820221456'),
('20130820230214'),
('20130821150626'),
('20130821155342'),
('20130821155425'),
('20130821161021'),
('20130822050311'),
('20130822215532'),
('20130827184633'),
('20130827210414'),
('20130827220135'),
('20130828160026'),
('20130828174723'),
('20130829180232'),
('20130829221342'),
('20130902180813'),
('20130905153553'),
('20130911180657'),
('20130917192958'),
('20130917194540'),
('20130918191809'),
('20130924171524'),
('20130924224115'),
('20130925164743'),
('20130925191707'),
('20130925200737'),
('20130926185207'),
('20130930203850'),
('20131001202019'),
('20131008190648'),
('20131010193936'),
('20131010194006'),
('20131010194345'),
('20131010194500'),
('20131010194521'),
('20131014201229'),
('20131016193346'),
('20131016214955'),
('20131016231130'),
('20131018170211'),
('20131020215932'),
('20131021190108'),
('20131022154220'),
('20131023031539'),
('20131023032325'),
('20131107143439'),
('20131107143512'),
('20131107143537'),
('20131107143832'),
('20131107145351'),
('20131107161918'),
('20131107235621'),
('20131108011509'),
('20131112113608'),
('20131113145601'),
('20131114154112'),
('20131115161618'),
('20131115161712'),
('20131127132159'),
('20131203165406'),
('20131212220606'),
('20131221202026'),
('20131223211811'),
('20131224200147'),
('20131224210745'),
('20131224211151'),
('20131226220339'),
('20131226230842'),
('20131226231159'),
('20131227170938'),
('20140108165433'),
('20140108203826'),
('20140120195335'),
('20140120201216'),
('20140121114718'),
('20140121124230'),
('20140121124646'),
('20140121124840'),
('20140121125256'),
('20140121130341'),
('20140121171044'),
('20140121193929'),
('20140122165752'),
('20140128121507'),
('20140128122208'),
('20140130223126'),
('20140204131059'),
('20140210233516'),
('20140211184505'),
('20140212180711'),
('20140218181118'),
('20140220195747'),
('20140221000612'),
('20140221000924'),
('20140221023714'),
('20140221171650'),
('20140226191212'),
('20140228034409'),
('20140314202354'),
('20140324180104'),
('20140325123915'),
('20140328010428'),
('20140328120740'),
('20140401180011'),
('20140401181046'),
('20140403173849'),
('20140409195932'),
('20140410130510'),
('20140410200741'),
('20140411140737'),
('20140411153421'),
('20140415170308'),
('20140416171749'),
('20140423182227'),
('20140506164815'),
('20140506171311'),
('20140507191030'),
('20140509123001'),
('20140515185046'),
('20140516135956'),
('20140516181346'),
('20140527200930'),
('20140530224700'),
('20140530225038'),
('20140612230821'),
('20140626141415'),
('20140708123838'),
('20140721232244'),
('20140801185200'),
('20140806134524'),
('20140806135608'),
('20140806141600'),
('20140807215229'),
('20140808185831'),
('20140814170158'),
('20140815171319'),
('20140816212033'),
('20140822150920'),
('20140827181425'),
('20140829195912'),
('20141005185320'),
('20141005191635'),
('20141007210436'),
('20141014002211'),
('20141014002212'),
('20141101163142'),
('20141101165236'),
('20141115110054'),
('20141115111010'),
('20141115125302'),
('20141116170209'),
('20141117093252'),
('20141117135403'),
('20141118160942'),
('20141119140206'),
('20141123145239'),
('20160330195625'),
('20160330195626'),
('20160330195627'),
('20160330195628'),
('20170318064820'),
('20170318064821'),
('20171223093445'),
('20181712005615'),
('20190607103117'),
('20190607135806'),
('20190727111338'),
('20190814134037'),
('20190820194703'),
('20190930000615'),
('20190930235238'),
('20200619020518'),
('20201130093601'),
('20210812103559'),
('20210930141200'),
('20211003211149'),
('20211229050250'),
('20211229050956'),
('20211229122948'),
('20220513210007'),
('20220514163551'),
('20220516211357'),
('20220709102510'),
('20220717110039'),
('20220717110652'),
('20220717132136'),
('20230306120457'),
('20230323061850'),
('20230329105849'),
('20241227'),
('20251215120000'),
('20251215120100'),
('20251215120200'),
('20251223100000'),
('20251227080000'),
('20260116120000'),
('20260120213751'),
('20260122121145');


