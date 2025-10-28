-- Política RLS para permitir INSERT en user_sessions solo si el usuario autenticado
-- es dueño del user_profile_id (consultando la tabla user_profiles)

-- Primero, eliminar política existente si la hay
DROP POLICY IF EXISTS "Allow insert for authenticated user" ON user_sessions;

-- Crear la política correcta
CREATE POLICY "Allow insert for authenticated user"
ON user_sessions
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_profiles.user_profile_id = user_sessions.user_profile_id
  AND user_profiles.user_auth_id = auth.uid()
  )
);

-- Política para permitir UPDATE en user_sessions solo si el usuario es dueño
DROP POLICY IF EXISTS "Allow update for authenticated user" ON user_sessions;

CREATE POLICY "Allow update for authenticated user"
ON user_sessions
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_profiles.user_profile_id = user_sessions.user_profile_id
  AND user_profiles.user_auth_id = auth.uid()
  )
);

-- Política para permitir SELECT en user_sessions solo si el usuario es dueño
DROP POLICY IF EXISTS "Allow select for authenticated user" ON user_sessions;

CREATE POLICY "Allow select for authenticated user"
ON user_sessions
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_profiles.user_profile_id = user_sessions.user_profile_id
  AND user_profiles.user_auth_id = auth.uid()
  )
);
