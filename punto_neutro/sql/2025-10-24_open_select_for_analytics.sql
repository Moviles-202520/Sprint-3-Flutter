-- Expand SELECT visibility for analytics dashboards (aggregated, non-PII).
-- This keeps INSERT/UPDATE restricted while allowing authenticated clients
-- to read all rows needed for global charts.

BEGIN;

-- Ensure RLS is enabled
ALTER TABLE public.engagement_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rating_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.news_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.viewed_categories ENABLE ROW LEVEL SECURITY;

-- Engagement events: allow SELECT for all authenticated (analytics)
DROP POLICY IF EXISTS "select_engagement_events_analytics" ON public.engagement_events;
CREATE POLICY "select_engagement_events_analytics"
ON public.engagement_events
FOR SELECT
TO authenticated
USING (true);

-- User sessions: allow SELECT for all authenticated (analytics)
DROP POLICY IF EXISTS "select_user_sessions_analytics" ON public.user_sessions;
CREATE POLICY "select_user_sessions_analytics"
ON public.user_sessions
FOR SELECT
TO authenticated
USING (true);

-- Rating items: allow SELECT for all authenticated (analytics)
DROP POLICY IF EXISTS "select_rating_items_analytics" ON public.rating_items;
CREATE POLICY "select_rating_items_analytics"
ON public.rating_items
FOR SELECT
TO authenticated
USING (true);

-- Comments: allow SELECT for all authenticated (analytics)
DROP POLICY IF EXISTS "select_comments_analytics" ON public.comments;
CREATE POLICY "select_comments_analytics"
ON public.comments
FOR SELECT
TO authenticated
USING (true);

-- Reference data used in joins
DROP POLICY IF EXISTS "select_news_items_analytics" ON public.news_items;
CREATE POLICY "select_news_items_analytics"
ON public.news_items
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "select_categories_analytics" ON public.categories;
CREATE POLICY "select_categories_analytics"
ON public.categories
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "select_viewed_categories_analytics" ON public.viewed_categories;
CREATE POLICY "select_viewed_categories_analytics"
ON public.viewed_categories
FOR SELECT
TO authenticated
USING (true);

COMMIT;
