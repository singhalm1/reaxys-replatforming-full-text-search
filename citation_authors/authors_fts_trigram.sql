-- ============================================================================
-- APPROACH 2: Full-Text Search with TRIGRAM
-- ============================================================================
-- Purpose: Handle multilingual author search using trigram similarity
--          with accent/umlaut normalization via unaccent function
-- ============================================================================

-- ============================================================================
-- Extensions required for this approach
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- Step 1: Add new column for authors data (no special collation needed)
-- This column will hold the authors data as-is
ALTER TABLE m_fltxt.citation
ADD COLUMN IF NOT EXISTS authors_fts_trigram TEXT;

-- Step 2: Migrate data from existing authors column to new column
-- This preserves existing data while enabling new functionality
UPDATE m_fltxt.citation
SET authors_fts_trigram = authors
WHERE authors IS NOT NULL AND authors_fts_trigram IS NULL;

-- Step 4: Create trigram GIN index for substring matching
-- GIN index optimizes for searching with trigram operators
-- Works efficiently with ILIKE and % operators
CREATE INDEX IF NOT EXISTS idx_citation_authors_fts_trigram_gin
ON m_fltxt.citation USING gin (authors_fts_trigram gin_trgm_ops);


-- ============================================================================
-- Create helper function for accent/umlaut-insensitive search
-- ============================================================================
CREATE OR REPLACE FUNCTION normalize_author_name(p_text TEXT)
RETURNS TEXT AS $$
BEGIN
   
    RETURN LOWER(unaccent('NFKD', p_text));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Create index on normalized author names
-- This accelerates queries using the normalize function
CREATE INDEX IF NOT EXISTS idx_citation_authors_fts_trigram_normalized
ON m_fltxt.citation USING gin (
    normalize_author_name(authors_fts_trigram) gin_trgm_ops
);
