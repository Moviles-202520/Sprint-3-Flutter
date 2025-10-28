-- 🔹 rating_items
DO $$
DECLARE
  seq_name text;
BEGIN
  SELECT pg_get_serial_sequence('rating_items', 'rating_item_id') INTO seq_name;
  IF seq_name IS NOT NULL THEN
    EXECUTE format(
      'SELECT setval(%L, COALESCE((SELECT MAX(rating_item_id) FROM rating_items), 0) + 1, false);',
      seq_name
    );
  END IF;
END$$;

-- 🔹 comments
DO $$
DECLARE
  seq_name text;
BEGIN
  SELECT pg_get_serial_sequence('comments', 'comment_id') INTO seq_name;
  IF seq_name IS NOT NULL THEN
    EXECUTE format(
      'SELECT setval(%L, COALESCE((SELECT MAX(comment_id) FROM comments), 0) + 1, false);',
      seq_name
    );
  END IF;
END$$;

-- 🔹 user_sessions
DO $$
DECLARE
  seq_name text;
BEGIN
  SELECT pg_get_serial_sequence('user_sessions', 'user_session_id') INTO seq_name;
  IF seq_name IS NOT NULL THEN
    EXECUTE format(
      'SELECT setval(%L, COALESCE((SELECT MAX(user_session_id) FROM user_sessions), 0) + 1, false);',
      seq_name
    );
  END IF;
END$$;

-- 🔹 engagement_events
DO $$
DECLARE
  seq_name text;
BEGIN
  SELECT pg_get_serial_sequence('engagement_events', 'event_id') INTO seq_name;
  IF seq_name IS NOT NULL THEN
    EXECUTE format(
      'SELECT setval(%L, COALESCE((SELECT MAX(event_id) FROM engagement_events), 0) + 1, false);',
      seq_name
    );
  END IF;
END$$;
