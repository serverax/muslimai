-- PHASE 2: user bookmarks (login required, user-isolated).
BEGIN;

CREATE TABLE IF NOT EXISTS sakina_ai.bookmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    item_type TEXT NOT NULL,           -- 'dua' | 'prayer' | 'answer' | 'ayah'
    item_ref TEXT NOT NULL,            -- id or reference of the bookmarked item
    label TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, item_type, item_ref)
);

CREATE INDEX IF NOT EXISTS idx_bookmarks_user_id ON sakina_ai.bookmarks (user_id);

ALTER TABLE sakina_ai.bookmarks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS bookmarks_self ON sakina_ai.bookmarks;
CREATE POLICY bookmarks_self ON sakina_ai.bookmarks
    FOR ALL USING (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role())
    WITH CHECK (user_id = sakina_ai.current_user_id() OR sakina_ai.rls_service_role());

COMMIT;
