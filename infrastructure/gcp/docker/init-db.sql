-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create auth schema for GoTrue
CREATE SCHEMA IF NOT EXISTS auth;

-- Grant privileges
GRANT ALL ON SCHEMA auth TO appflowy;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO appflowy;
GRANT ALL ON ALL SEQUENCES IN SCHEMA auth TO appflowy;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA auth TO appflowy;

-- Create appflowy schema
CREATE SCHEMA IF NOT EXISTS public;

-- Grant privileges
GRANT ALL ON SCHEMA public TO appflowy;
GRANT ALL ON ALL TABLES IN SCHEMA public TO appflowy;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO appflowy;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO appflowy;

-- Set search_path for appflowy user
ALTER USER appflowy SET search_path TO public, auth;
