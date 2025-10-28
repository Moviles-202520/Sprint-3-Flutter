-- Supabase RLS policy for user_sessions
-- Permitir insertar sesiones a cualquier usuario autenticado
create policy "Allow insert for authenticated" on user_sessions
  for insert
  using (auth.role() = 'authenticated');
