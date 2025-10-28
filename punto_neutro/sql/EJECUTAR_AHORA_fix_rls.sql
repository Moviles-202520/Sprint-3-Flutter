-- 🔴 EJECUTAR ESTE SCRIPT EN SUPABASE SQL EDITOR AHORA
-- Este script permite que el dashboard vea TODOS los datos para analytics

BEGIN;

-- 1) ENGAGEMENT_EVENTS: Ver todos los eventos
DROP POLICY IF EXISTS "select_engagement_events" ON public.engagement_events;
DROP POLICY IF EXISTS "select_engagement_events_analytics" ON public.engagement_events;
CREATE POLICY "select_engagement_events_analytics"
ON public.engagement_events
FOR SELECT
TO authenticated
USING (true);

-- 2) USER_SESSIONS: Ver todas las sesiones
DROP POLICY IF EXISTS "Allow select for authenticated user" ON public.user_sessions;
DROP POLICY IF EXISTS "select_user_sessions_analytics" ON public.user_sessions;
CREATE POLICY "select_user_sessions_analytics"
ON public.user_sessions
FOR SELECT
TO authenticated
USING (true);

-- 3) RATING_ITEMS: Ver todos los ratings
DROP POLICY IF EXISTS "select_rating_items_analytics" ON public.rating_items;
CREATE POLICY "select_rating_items_analytics"
ON public.rating_items
FOR SELECT
TO authenticated
USING (true);

-- 4) COMMENTS: Ver todos los comentarios
DROP POLICY IF EXISTS "select_comments_analytics" ON public.comments;
CREATE POLICY "select_comments_analytics"
ON public.comments
FOR SELECT
TO authenticated
USING (true);

-- 5) NEWS_ITEMS: Ver todas las noticias
DROP POLICY IF EXISTS "select_news_items_analytics" ON public.news_items;
CREATE POLICY "select_news_items_analytics"
ON public.news_items
FOR SELECT
TO authenticated
USING (true);

-- 6) CATEGORIES: Ver todas las categorías
DROP POLICY IF EXISTS "select_categories_analytics" ON public.categories;
CREATE POLICY "select_categories_analytics"
ON public.categories
FOR SELECT
TO authenticated
USING (true);

-- 7) VIEWED_CATEGORIES: Ver todas las categorías vistas
DROP POLICY IF EXISTS "select_viewed_categories_analytics" ON public.viewed_categories;
CREATE POLICY "select_viewed_categories_analytics"
ON public.viewed_categories
FOR SELECT
TO authenticated
USING (true);

COMMIT;

-- ✅ Después de ejecutar esto, recarga tu app y vuelve a entrar al dashboard
