-- 007_grants.sql
-- M0 Fondation — privilèges explicites aux rôles Supabase.
-- Bug historique 007 corrigé : GRANTs nécessaires présents.

GRANT USAGE ON SCHEMA public TO anon, authenticated;

-- foods : lecture publique (anon + authenticated). Pas d'écriture pour les rôles applicatifs.
GRANT SELECT ON public.foods TO anon, authenticated;

-- user tables : CRUD pour authenticated.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.menu_days  TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.meals      TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.meal_items TO authenticated;

-- helper d'identité.
GRANT EXECUTE ON FUNCTION public.current_user_id() TO anon, authenticated;
