-- ============================================================================
-- APPROACH 1: Full-Text Search with COLLATION
-- ============================================================================
-- Purpose: Handle multilingual author search using collation
--          with proper accent/umlaut handling and case-insensitive matching
-- ============================================================================
-- ============================================================================
-- Extensions required for this approach
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS unaccent;
-- ============================================================================
-- Step 1: Create collation
CREATE COLLATION IF NOT EXISTS cit_aut_col (
    locale = 'C.UTF-8',
    deterministic = true
);

-- Step 2: Add new column with appropriate collation
ALTER TABLE m_fltxt.citation
ADD COLUMN IF NOT EXISTS authors_fts_col TEXT COLLATE cit_aut_col;

-- Step 3: Migrate data from existing authors column to new column
-- This preserves existing data while enabling new functionality
UPDATE m_fltxt.citation
SET authors_fts_col = authors
WHERE authors IS NOT NULL AND authors_fts_col IS NULL;

--Wrapping unaccent in a function that you manually mark as IMMUTABLE.

CREATE OR REPLACE FUNCTION immutable_unaccent(text)
  RETURNS text AS
$func$
  SELECT public.unaccent('public.unaccent', $1); 
$func$
LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT; 


-- Step 4: Create a full-text search index using tsvector
-- This provides more sophisticated linguistic search capabilities
-- Useful for ranking and relevance scoring
CREATE INDEX idx_authors_fts_ger
ON m_fltxt.citation USING GIN (to_tsvector('german', immutable_unaccent(authors_fts_col)));

CREATE INDEX idx_authors_fts_frn
ON m_fltxt.citation USING GIN (to_tsvector('french', immutable_unaccent(authors_fts_col)));
 