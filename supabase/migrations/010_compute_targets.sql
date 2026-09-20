-- 010_compute_targets.sql
-- M2 Profils nutritionnels — règles de calcul des cibles (BMR, TDEE, kcal cible, macros).
-- Décisions validées (M2 v2) :
--   M2-B : BMR = Mifflin-St Jeor (formule choisie pour Macaron, NON vérité médicale universelle).
--   M2-C : 5 niveaux PAL (FAO/OMS).
--   M2-D : ajustement objectif en pourcentage (loss -20%, maintain 0%, gain +15%).
--   M2-E : FLOOR = max(BMR, 1200F/1500M) — CONTRAINTE PRODUIT (non médicale) : garantir un domaine
--          où le générateur M1 produit un menu sensé (quantity_g>0, carbs>=0, optimisation ±5% viable).
--   M2-F/N : facteurs macros isolés dans un bloc de constantes nommées (facilement modifiables).
--   M2-M : m2_calc_version() = source unique du string de version ('m2_v1').
--   M2-J : validations d'entrée CHECK + RAISE + fail closed.
--   M2-H : generate_menu_from_profile lit le profil et délègue à generate_menu (M1, filtre halal+lactose_free).

-- ====== Source unique du versioning des règles ======
CREATE OR REPLACE FUNCTION public.m2_calc_version()
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT 'm2_v1'::text;
$$;
COMMENT ON FUNCTION public.m2_calc_version() IS
  'M2 : version des règles de calcul des cibles (source unique du string).';
GRANT EXECUTE ON FUNCTION public.m2_calc_version() TO authenticated;

-- ====== Calcul pur des cibles (BMR, TDEE, target_kcal, macros) ======
-- IMMUTABLE : fonction pure des paramètres (aucun accès table, aucun effet de bord).
-- Ordre des colonnes retournées : bmr_kcal, tdee_kcal, target_kcal, target_protein_g, target_carbs_g, target_fat_g.
CREATE OR REPLACE FUNCTION public.compute_targets(
  p_sex            text,
  p_age            int,
  p_height_cm      numeric,
  p_weight_kg      numeric,
  p_activity_level text,
  p_goal           text
) RETURNS TABLE (
  bmr_kcal         numeric,
  tdee_kcal        numeric,
  target_kcal      numeric,
  target_protein_g numeric,
  target_carbs_g   numeric,
  target_fat_g     numeric
)
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  -- ====== RÈGLES (M2 v1) — facteurs isolés, facilement modifiables ======
  -- BMR (Mifflin-St Jeor)
  c_bmr_w    numeric := 10;    -- × weight_kg
  c_bmr_h    numeric := 6.25;  -- × height_cm
  c_bmr_age  numeric := 5;     -- × age
  c_male_adj numeric := 5;     -- soustraction hommes
  c_fem_adj  numeric := 161;   -- soustraction femmes
  -- Macros
  c_protein_g_per_kg numeric := 1.8;
  c_fat_g_per_kg    numeric := 1.0;
  -- FLOOR (CONTRAINTE PRODUIT, non médicale)
  c_floor_abs_female numeric := 1200;
  c_floor_abs_male   numeric := 1500;
  -- variables
  v_pal    numeric;
  v_goal_f numeric;
  v_floor  numeric;
  v_bmr    numeric(8,2);
  v_tdee   numeric(10,2);
  v_tkcal  numeric(7,2);
  v_p      numeric(7,2);
  v_f      numeric(7,2);
  v_c      numeric(7,2);
BEGIN
  -- Validations d'entrée (fail closed)
  IF p_sex IS NULL OR p_sex NOT IN ('male','female') THEN
    RAISE EXCEPTION 'compute_targets: sex invalide: %', p_sex;
  END IF;
  IF p_age IS NULL OR p_age < 18 OR p_age > 100 THEN
    RAISE EXCEPTION 'compute_targets: age hors plage [18,100]: %', p_age;
  END IF;
  IF p_height_cm IS NULL OR p_height_cm < 120 OR p_height_cm > 250 THEN
    RAISE EXCEPTION 'compute_targets: height_cm hors plage [120,250]: %', p_height_cm;
  END IF;
  IF p_weight_kg IS NULL OR p_weight_kg < 30 OR p_weight_kg > 300 THEN
    RAISE EXCEPTION 'compute_targets: weight_kg hors plage [30,300]: %', p_weight_kg;
  END IF;
  IF p_activity_level IS NULL OR p_activity_level NOT IN ('sedentary','light','moderate','active','very_active') THEN
    RAISE EXCEPTION 'compute_targets: activity_level invalide: %', p_activity_level;
  END IF;
  IF p_goal IS NULL OR p_goal NOT IN ('loss','maintain','gain') THEN
    RAISE EXCEPTION 'compute_targets: goal invalide: %', p_goal;
  END IF;

  -- PAL
  v_pal := CASE p_activity_level
    WHEN 'sedentary'   THEN 1.2
    WHEN 'light'       THEN 1.375
    WHEN 'moderate'    THEN 1.55
    WHEN 'active'      THEN 1.725
    WHEN 'very_active' THEN 1.9
  END;

  -- BMR (Mifflin-St Jeor)
  v_bmr := c_bmr_w * p_weight_kg + c_bmr_h * p_height_cm - c_bmr_age * p_age
           - CASE WHEN p_sex = 'male' THEN c_male_adj ELSE c_fem_adj END;

  -- TDEE
  v_tdee := v_bmr * v_pal;

  -- Ajustement d'objectif
  v_goal_f := CASE p_goal WHEN 'loss' THEN 0.80 WHEN 'maintain' THEN 1.00 WHEN 'gain' THEN 1.15 END;

  -- FLOOR (contrainte produit) : jamais sous BMR ni sous le plancher absolu sexe-dépendant.
  v_floor := GREATEST(v_bmr, CASE WHEN p_sex = 'male' THEN c_floor_abs_male ELSE c_floor_abs_female END);

  -- Cible kcal brute -> plancher -> arrondi entier.
  v_tkcal := GREATEST(v_tdee * v_goal_f, v_floor);
  v_tkcal := round(v_tkcal);

  -- Macros : protéines et lipides fixes (g/kg), glucides = reste.
  v_p := round(c_protein_g_per_kg * p_weight_kg);
  v_f := round(c_fat_g_per_kg * p_weight_kg);
  v_c := round((v_tkcal - v_p * 4 - v_f * 9) / 4);

  IF v_c < 0 THEN
    RAISE EXCEPTION 'compute_targets: cibles impossibles (déficit trop bas pour ce profil): carbs_g=%', v_c;
  END IF;

  -- RETURNS TABLE = paramètres OUT : on assigne les colonnes puis RETURN NEXT sans arguments.
  bmr_kcal := v_bmr;
  tdee_kcal := v_tdee;
  target_kcal := v_tkcal;
  target_protein_g := v_p;
  target_carbs_g := v_c;
  target_fat_g := v_f;
  RETURN NEXT;
END;
$$;
COMMENT ON FUNCTION public.compute_targets(text,int,numeric,numeric,text,text) IS
  'M2 : calcule BMR (Mifflin-St Jeor), TDEE (×PAL), target_kcal (objectif + FLOOR produit) et macros (1.8g/kg P, 1.0g/kg L, glucides=reste). IMMUTABLE, pur. Facteurs isolés dans le bloc RÈGLES.';
GRANT EXECUTE ON FUNCTION public.compute_targets(text,int,numeric,numeric,text,text) TO authenticated;

-- ====== Persistance du profil + cache des cibles (upsert idempotent) ======
CREATE OR REPLACE FUNCTION public.set_profile(
  p_sex            text,
  p_age            int,
  p_height_cm      numeric,
  p_weight_kg      numeric,
  p_activity_level text,
  p_goal           text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user uuid := public.current_user_id();
  v_bmr  numeric; v_tdee numeric; v_tkcal numeric;
  v_p    numeric; v_c    numeric; v_f     numeric;
  v_id   uuid;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'set_profile: utilisateur courant indéfini (claim JWT absent)';
  END IF;

  -- compute_targets valide les entrées et RAISE si cibles impossibles (avant tout INSERT).
  SELECT c.bmr_kcal, c.tdee_kcal, c.target_kcal,
         c.target_protein_g, c.target_carbs_g, c.target_fat_g
    INTO v_bmr, v_tdee, v_tkcal, v_p, v_c, v_f
  FROM public.compute_targets(p_sex, p_age, p_height_cm, p_weight_kg, p_activity_level, p_goal) AS c;

  INSERT INTO public.user_profiles
    (user_id, sex, age, height_cm, weight_kg, activity_level, goal,
     bmr_kcal, tdee_kcal, target_kcal, target_protein_g, target_carbs_g, target_fat_g,
     calculation_version, updated_at)
  VALUES (v_user, p_sex, p_age, p_height_cm, p_weight_kg, p_activity_level, p_goal,
          v_bmr, v_tdee, v_tkcal, v_p, v_c, v_f,
          public.m2_calc_version(), now())
  ON CONFLICT (user_id) DO UPDATE SET
    sex                 = EXCLUDED.sex,
    age                 = EXCLUDED.age,
    height_cm           = EXCLUDED.height_cm,
    weight_kg           = EXCLUDED.weight_kg,
    activity_level      = EXCLUDED.activity_level,
    goal                = EXCLUDED.goal,
    bmr_kcal            = EXCLUDED.bmr_kcal,
    tdee_kcal           = EXCLUDED.tdee_kcal,
    target_kcal         = EXCLUDED.target_kcal,
    target_protein_g    = EXCLUDED.target_protein_g,
    target_carbs_g      = EXCLUDED.target_carbs_g,
    target_fat_g        = EXCLUDED.target_fat_g,
    calculation_version = EXCLUDED.calculation_version,
    updated_at          = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;
COMMENT ON FUNCTION public.set_profile(text,int,numeric,numeric,text,text) IS
  'M2 : crée/met à jour le profil de current_user_id() et cache BMR/TDEE/cibles + calculation_version. SECURITY DEFINER, fail closed, idempotent (upsert).';
GRANT EXECUTE ON FUNCTION public.set_profile(text,int,numeric,numeric,text,text) TO authenticated;

-- ====== Intégration : génère le menu d'un jour à partir du profil ======
CREATE OR REPLACE FUNCTION public.generate_menu_from_profile(p_day date)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user  uuid := public.current_user_id();
  v_tkcal numeric; v_p numeric; v_c numeric; v_f numeric;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'generate_menu_from_profile: utilisateur courant indéfini (claim JWT absent)';
  END IF;

  SELECT target_kcal, target_protein_g, target_carbs_g, target_fat_g
    INTO v_tkcal, v_p, v_c, v_f
  FROM public.user_profiles WHERE user_id = v_user;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'generate_menu_from_profile: aucun profil pour l''utilisateur courant';
  END IF;
  IF v_tkcal IS NULL OR v_tkcal <= 0 THEN
    RAISE EXCEPTION 'generate_menu_from_profile: profil sans cible kcal exploitable';
  END IF;

  -- Délègue à M1 (generate_menu) : filtre halal+lactose_free conservé, régénération atomique, sans duplication.
  RETURN public.generate_menu(p_day, v_tkcal, v_p, v_c, v_f);
END;
$$;
COMMENT ON FUNCTION public.generate_menu_from_profile(date) IS
  'M2 : génère le menu de p_day pour current_user_id() à partir de son profil. Délègue à generate_menu (M1) — filtre halal+lactose_free conservé, sans duplication. SECURITY DEFINER, fail closed.';
GRANT EXECUTE ON FUNCTION public.generate_menu_from_profile(date) TO authenticated;
