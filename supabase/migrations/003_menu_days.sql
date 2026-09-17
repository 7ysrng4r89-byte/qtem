-- 003_menu_days.sql
-- M0 Fondation — jours de menu par utilisateur.
-- Décision C : cibles macro optionnelles (NULL autorisé).

CREATE TABLE IF NOT EXISTS public.menu_days (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL,
  day              date NOT NULL,
  target_kcal      numeric(7,2),
  target_protein_g numeric(7,2),
  target_carbs_g   numeric(7,2),
  target_fat_g     numeric(7,2),
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, day)
);

COMMENT ON TABLE public.menu_days IS
  'Jours de menu par utilisateur. Cibles macro optionnelles (NULL = pas encore défini).';
