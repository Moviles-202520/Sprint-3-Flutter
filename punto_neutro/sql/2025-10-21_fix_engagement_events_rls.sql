-- Fix RLS policies for engagement_events table
-- Allows authenticated users to insert/select engagement events

BEGIN;

-- Habilitar RLS si no está habilitado
ALTER TABLE public.engagement_events ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "insert_engagement_events" ON public.engagement_events;
DROP POLICY IF EXISTS "select_engagement_events" ON public.engagement_events;

-- Policy: Allow INSERT for authenticated users
-- Verifica que el user_session_id pertenezca al usuario autenticado
CREATE POLICY "insert_engagement_events" 
ON public.engagement_events 
FOR INSERT 
TO authenticated
WITH CHECK (
  -- Permitir insert si:
  -- 1. No hay user_session_id (null es OK para algunos eventos)
  -- 2. O el user_session_id pertenece a una sesión del usuario autenticado
  user_session_id IS NULL 
  OR EXISTS (
    SELECT 1 
    FROM public.user_sessions us
    JOIN public.user_profiles up ON us.user_profile_id = up.user_profile_id
    WHERE us.user_session_id = engagement_events.user_session_id
      AND up.user_auth_id = auth.uid()::text
  )
);

-- Policy: Allow SELECT for authenticated users
-- Permite ver solo eventos de sesiones propias
CREATE POLICY "select_engagement_events" 
ON public.engagement_events 
FOR SELECT 
TO authenticated
USING (
  user_session_id IS NULL 
  OR EXISTS (
    SELECT 1 
    FROM public.user_sessions us
    JOIN public.user_profiles up ON us.user_profile_id = up.user_profile_id
    WHERE us.user_session_id = engagement_events.user_session_id
      AND up.user_auth_id = auth.uid()::text
  )
);

COMMIT;
