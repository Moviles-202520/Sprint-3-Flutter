-- Final migration: add started/completed timestamps and make is_completed generated for comments.
-- Also add started_at/completed_at to rating_items and backfill using rating_date.

BEGIN;

-- COMMENTS: add started/completed timestamps
ALTER TABLE public.comments
  ADD COLUMN IF NOT EXISTS started_at timestamptz,
  ADD COLUMN IF NOT EXISTS completed_at timestamptz;

-- Backfill from existing "timestamp" column (creation time) when nulls
UPDATE public.comments
SET started_at = COALESCE(started_at, "timestamp"),
    completed_at = COALESCE(completed_at, "timestamp")
WHERE (started_at IS NULL OR completed_at IS NULL);

-- Ensure is_completed exists as a plain boolean and sync values from completed_at (no drops to keep compatibility)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'comments' AND column_name = 'is_completed'
  ) THEN
    ALTER TABLE public.comments ADD COLUMN is_completed boolean;
  END IF;
END $$;

-- Set is_completed based on completed_at
UPDATE public.comments
SET is_completed = (completed_at IS NOT NULL)
WHERE is_completed IS DISTINCT FROM (completed_at IS NOT NULL);

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_comments_started_at ON public.comments (started_at);
CREATE INDEX IF NOT EXISTS idx_comments_completed_at ON public.comments (completed_at);
CREATE INDEX IF NOT EXISTS idx_comments_news_item_id ON public.comments (news_item_id);

-- RATING_ITEMS: add started/completed timestamps (keep existing is_completed)
ALTER TABLE public.rating_items
  ADD COLUMN IF NOT EXISTS started_at timestamptz,
  ADD COLUMN IF NOT EXISTS completed_at timestamptz;

-- Backfill completed_at = rating_date when is_completed=true; started_at defaults to rating_date too
UPDATE public.rating_items
SET completed_at = COALESCE(completed_at, rating_date),
    started_at = COALESCE(started_at, rating_date)
WHERE is_completed = true;

-- For not completed, set started_at from rating_date and leave completed_at NULL
UPDATE public.rating_items
SET started_at = COALESCE(started_at, rating_date)
WHERE is_completed = false;

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_rating_items_started_at ON public.rating_items (started_at);
CREATE INDEX IF NOT EXISTS idx_rating_items_completed_at ON public.rating_items (completed_at);
CREATE INDEX IF NOT EXISTS idx_rating_items_rating_date ON public.rating_items (rating_date);
CREATE INDEX IF NOT EXISTS idx_rating_items_news_item_id ON public.rating_items (news_item_id);

COMMIT;
