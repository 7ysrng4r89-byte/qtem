-- tests/_auth_sim.sql
-- HARNÉS DE TEST UNIQUEMENT — N'EST PAS UNE MIGRATION DE PRODUCTION.
-- Injecte un claim JWT simulé (request.jwt.claims) pour les tests locaux.
-- AUCUN secret réel : juste un sub uuid fictif. Ne remplace pas le mécanisme JWT de prod
-- (en production, Supabase positionne request.jwt.claims avec un JWT réel signé).
-- Décision B : même mécanisme que la prod (lecture de request.jwt.claims via current_user_id()).

CREATE OR REPLACE FUNCTION public._auth_sim(p_user_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT set_config('request.jwt.claims',
                    jsonb_build_object('sub', p_user_id, 'role', 'authenticated')::text,
                    false);  -- is_local=false -> niveau session (persiste pour la session de test)
$$;

CREATE OR REPLACE FUNCTION public._auth_clear()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT set_config('request.jwt.claims', '', false);
$$;

-- En tests, les rôles applicatifs doivent pouvoir appeler le harnais.
GRANT EXECUTE ON FUNCTION public._auth_sim(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public._auth_clear()   TO authenticated;
