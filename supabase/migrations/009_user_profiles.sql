-- 009_user_profiles.sql
-- M2 Profils nutritionnels — table du profil utilisateur (une ligne par utilisateur).
-- Décisions validées (M2 v2) :
--   M2-A : calcul serveur (PL/pgSQL), source unique des cibles.
--   M2-G/L : cibles + intermédiaires (bmr_kcal, tdee_kcal) cachés dans la table.
--   M2-M : calculation_version versionne les règles de calcul (source = m2_calc_version()).
--   M2-E : FLOOR = contrainte produit (non médicale), appliquée dans compute_targets (010).
--   RLS owner-only (même pattern que menu_days). SECURITY DEFINER dans set_profile/generate_menu_from_profile (010).
-- Ne modifie aucune table M0/M1 (foods, menu_days, meals, meal_items).

CREATE TABLE IF NOT EXISTS public.user_profiles (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL UNIQUE,
  sex              text NOT NULL CHECK (sex IN ('male','female')),
  age              int  NOT NULL CHECK (age BETWEEN 18 AND 100),
  height_cm        numeric(5,2) NOT NULL CHECK (height_cm BETWEEN 120 AND 250),
  weight_kg        numeric(5,2) NOT NULL CHECK (weight_kg BETWEEN 30 AND 300),
  activity_level   text NOT NULL CHECK (activity_level IN ('sedentary','light','moderate','active','very_active')),
  goal             text NOT NULL CHECK (goal IN ('loss','maintain','gain')),
  -- Valeurs calculées (cached, NULLABLE : renseignées uniquement par set_profile).
  bmr_kcal         numeric(7,2),
  tdee_kcal        numeric(7,2),
  target_kcal      numeric(7,2),
  target_protein_g numeric(7,2),
  target_carbs_g   numeric(7,2),
  target_fat_g     numeric(7,2),
  calculation_version text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.user_profiles IS
  'M2 : profil nutritionnel utilisateur (une ligne/user). Biometrics + cibles calculées cachées (BMR, TDEE, kcal/macros) + calculation_version. RLS owner-only.';

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_profiles_owner ON public.user_profiles
  FOR ALL TO authenticated
  USING      (user_id = public.current_user_id())
  WITH CHECK (user_id = public.current_user_id());

-- Profil privé : CRUD pour authenticated uniquement (RLS restreint à l'owner). Rien pour anon.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_profiles TO authenticated;
