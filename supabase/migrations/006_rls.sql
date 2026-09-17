-- 006_rls.sql
-- M0 Fondation — Row Level Security + helper d'identité utilisateur.
-- Décision B : en production, le user_id vient du claim JWT Supabase (request.jwt.claims.sub).
-- En tests, le harnais _auth_sim (tests/_auth_sim.sql, AUCUN secret) injecte un claim simulé.
-- Même mécanisme (lecture de request.jwt.claims), pas de remplacement du JWT prod.

-- Helper : renvoie l'id utilisateur courant (sub du claim JWT) ou NULL si absent/malformé.
-- Échec fermé (fail closed) -> NULL = aucun accès.
CREATE OR REPLACE FUNCTION public.current_user_id()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  c text;
  v text;
BEGIN
  c := current_setting('request.jwt.claims', true);
  IF c IS NULL OR c = '' THEN
    RETURN NULL;
  END IF;
  BEGIN
    v := c::jsonb ->> 'sub';
  EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
  END;
  RETURN NULLIF(v, '')::uuid;
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;
END;
$$;

ALTER TABLE public.menu_days   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meals       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_items  ENABLE ROW LEVEL SECURITY;

-- foods : lecture publique (pas de RLS nécessaire ; accès contrôlé par GRANT).

CREATE POLICY menu_days_owner ON public.menu_days
  FOR ALL TO authenticated
  USING      (user_id = public.current_user_id())
  WITH CHECK (user_id = public.current_user_id());

CREATE POLICY meals_owner ON public.meals
  FOR ALL TO authenticated
  USING      (EXISTS (SELECT 1 FROM public.menu_days md
                      WHERE md.id = menu_day_id
                        AND md.user_id = public.current_user_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.menu_days md
                       WHERE md.id = menu_day_id
                         AND md.user_id = public.current_user_id()));

CREATE POLICY meal_items_owner ON public.meal_items
  FOR ALL TO authenticated
  USING      (EXISTS (SELECT 1 FROM public.meals m
                      JOIN public.menu_days md ON md.id = m.menu_day_id
                      WHERE m.id = meal_id
                        AND md.user_id = public.current_user_id()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.meals m
                       JOIN public.menu_days md ON md.id = m.menu_day_id
                       WHERE m.id = meal_id
                         AND md.user_id = public.current_user_id()));
