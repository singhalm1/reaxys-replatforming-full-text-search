-- ============================================================================
-- APPROACH 3: Full-Text Search with COLLATION and TRIGRAM
-- ============================================================================
-- Purpose: Handle multilingual author search using collation and trigram
--          with proper accent/umlaut handling and case-insensitive matching
-- ============================================================================
-- ============================================================================
-- Extensions required for this approach
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- Step 1: Create collation for German with accent handling
-- This collation supports German umlauts (ä, ö, ü) and is case-insensitive
-- Using de_DE.UTF-8 locale for UTF8 database encoding compatibility
CREATE COLLATION IF NOT EXISTS de_de_case_insensitive (
    locale = 'de_DE.UTF-8',
    deterministic = true
);

-- Step 2: Add new column with appropriate collation
ALTER TABLE m_fltxt.citation
ADD COLUMN IF NOT EXISTS authors_fts_collation TEXT COLLATE de_de_case_insensitive;

-- Step 3: Migrate data from existing authors column to new column
-- This preserves existing data while enabling new functionality
UPDATE m_fltxt.citation
SET authors_fts_collation = authors
WHERE authors IS NOT NULL AND authors_fts_collation IS NULL;

-- Step 4: Create trigram GIN index for flexible substring matching
-- GIN (Generalized Inverted Index) is best for trigram text search
-- Supports ILIKE, %, and similarity operators efficiently
-- Note: GiST index removed due to 8KB row size limitation with large author fields
CREATE INDEX IF NOT EXISTS idx_citation_authors_fts_collation_trigram
ON m_fltxt.citation USING gin (authors_fts_collation gin_trgm_ops);

-- Step 5: Create a full-text search index using tsvector
-- This provides more sophisticated linguistic search capabilities
-- Useful for ranking and relevance scoring
CREATE INDEX IF NOT EXISTS idx_citation_authors_fts_col_ger_vector
ON m_fltxt.citation USING gin (to_tsvector('german', authors_fts_collation));

CREATE INDEX IF NOT EXISTS idx_citation_authors_fts_col_frn_vector
ON m_fltxt.citation USING gin (to_tsvector('french', authors_fts_collation));

--Creation of normalized column 

ALTER TABLE m_fltxt.citation
ADD COLUMN authors_normalized TEXT GENERATED ALWAYS AS (
    REPLACE(
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(authors, 'ß', 'ss'), -- Added sharp S replacement
                        'ü', 'ue'), 
                    'ö', 'oe'), 
                'ä', 'ae'), 
            'Ü', '	Ue'), 
        'Ö', 'Oe'), 
    'Ä', 'Ae')
) STORED;

--Creating GIN Index and Trigram on the normalized column
CREATE INDEX IF NOT EXISTS idx_normalized_data ON m_fltxt.citation USING gin (authors_normalized gin_trgm_ops);

