-- 004_meals.sql
-- M0 Fondation — repas d'un jour de menu.
-- Bug historique corrigé : PAS de double PK sur menu_days. meals a sa propre PK (id)
-- et uniquement une FK vers menu_days (ON DELETE CASCADE).

CREATE TABLE IF NOT EXISTS public.meals (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_day_id uuid NOT NULL REFERENCES public.menu_days(id) ON DELETE CASCADE,
  meal_type   text NOT NULL CHECK (meal_type IN ('breakfast','lunch','dinner','snack')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (menu_day_id, meal_type)
);

COMMENT ON TABLE public.meals IS 'Repas d un jour de menu. meal_type : breakfast|lunch|dinner|snack.';
