-- tests/module2_profiles.sql
-- M2 Profils nutritionnels — 12 checks (M2-1 .. M2-12). Doit renvoyer M2_RESULT 12/12 GREEN.
-- Exécuté par scripts/run_m2.sh sur une DB fraîche (mig 001-010 + seed + _auth_sim) APRÈS M0 16/16 + M1 8/8.
-- Décisions M2 v2 : A (serveur), B (Mifflin), C (5 PAL), D (%), E (FLOOR produit), F/N (macros isolés),
--                   G/L (cache bmr/tdee + cibles), H (generate_menu_from_profile), J (CHECK+RAISE), M (m2_calc_version).
-- userA = aaaaa... ; userB = bbbbb... .

\set ECHO none
\pset pager off

CREATE TABLE public.m2_results(idx int PRIMARY KEY, test text, ok boolean);

CREATE OR REPLACE FUNCTION public._m2_record(p_idx int, p_test text, p_ok boolean)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  INSERT INTO public.m2_results VALUES (p_idx, p_test, p_ok)
  ON CONFLICT (idx) DO UPDATE SET test = EXCLUDED.test, ok = EXCLUDED.ok;
$$;
GRANT EXECUTE ON FUNCTION public._m2_record(int,text,boolean) TO public;

-- ===================== M2-1 : set_profile crée 1 ligne (owner + biometrics) =====================
SELECT public._auth_clear();
DO $$
DECLARE v_id uuid; n int;
BEGIN
  PERFORM public._auth_sim('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
  v_id := public.set_profile('male', 30, 180, 80, 'moderate', 'maintain');
  SELECT count(*) INTO n FROM public.user_profiles
   WHERE id = v_id AND user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
     AND sex='male' AND age=30 AND height_cm=180 AND weight_kg=80
     AND activity_level='moderate' AND goal='maintain';
  PERFORM public._m2_record(1, 'M2-1 set_profile crée 1 ligne', n = 1);
  IF n <> 1 THEN RAISE NOTICE 'FAIL M2-1 n=% id=%', n, v_id; END IF;
  PERFORM public._auth_clear();
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m2_record(1, 'M2-1 set_profile crée 1 ligne', false);
  RAISE NOTICE 'FAIL M2-1: %', SQLERRM;
END $$;

-- ===================== M2-2 : BMR exact (Mifflin-St Jeor) =====================
DO $$
DECLARE v_bmr numeric;
BEGIN
  PERFORM public._auth_sim('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
  SELECT bmr_kcal INTO v_bmr FROM public.user_profiles WHERE user_id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  -- attendu : 10*80 + 6.25*180 - 5*30 - 5 = 1770
  PERFORM public._m2_record(2, 'M2-2 BMR exact', v_bmr = 1770);
  IF v_bmr <> 1770 THEN RAISE NOTICE 'FAIL M2-2 bmr=%', v_bmr; END IF;
  PERFORM public._auth_clear();
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m2_record(2, 'M2-2 BMR exact', false);
  RAISE NOTICE 'FAIL M2-2: %', SQLERRM;
END $$;

-- ===================== M2-3 : TDEE exact (BMR × PAL) =====================
DO $$
DECLARE v_tdee numeric;
BEGIN
  PERFORM public._auth_sim('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
  SELECT tdee_kcal INTO v_tdee FROM public.user_profiles WHERE user_id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  -- attendu : 1770 × 1.55 = 2743.5
  PERFORM public._m2_record(3, 'M2-3 TDEE exact', v_tdee = 2743.5);
  IF v_tdee <> 2743.5 THEN RAISE NOTICE 'FAIL M2-3 tdee=%', v_tdee; END IF;
  PERFORM public._auth_clear();
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m2_record(3, 'M2-3 TDEE exact', false);
  RAISE NOTICE 'FAIL M2-3: %', SQLERRM;
END $$;

-- ===================== M2-4 : target_kcal par objectif + FLOOR (contrainte produit) =====================
DO $$
DECLARE v_m numeric; v_l numeric; v_g numeric; v_floor numeric;
BEGIN
  PERFORM public._auth_sim('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
  SELECT target_kcal INTO v_m FROM public.user_profiles WHERE user_id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; -- maintain
  PERFORM public.set_profile('male',30,180,80,'moderate','loss');
  SELECT target_kcal INTO v_l FROM public.user_profiles WHERE user_id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  PERFORM public.set_profile('male',30,180,80,'moderate','gain');
  SELECT target_kcal INTO v_g FROM public.user_profiles WHERE user_id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  PERFORM public.set_profile('male',30,180,80,'moderate','maintain'); -- restore
  PERFORM public._auth_clear();

  -- FLOOR : userB female 60/160/50 sedentary loss -> cible = 1200 (plancher FLOOR)
  PERFORM public._auth_sim('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
  PERFORM public.set_profile('female',60,160,50,'sedentary','loss');
  SELECT target_kcal INTO v_floor FROM public.user_profiles WHERE user_id='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  PERFORM public._auth_clear();

  PERFORM public._m2_record(4, 'M2-4 target_kcal objectif+FLOOR',
    v_l=2195 AND v_m=2744 AND v_g=3155 AND v_l<v_m AND v_m<v_g AND v_floor=1200);
  IF NOT (v_l=2195 AND v_m=2744 AND v_g=3155 AND v_l<v_m AND v_m<v_g AND v_floor=1200) THEN
    RAISE NOTICE 'FAIL M2-4 l=% m=% g=% floor=%', v_l, v_m, v_g, v_floor;
  END IF;
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m2_record(4, 'M2-4 target_kcal objectif+FLOOR', false);
  RAISE NOTICE 'FAIL M2-4: %', SQLERRM;
END $$;

-- ===================== M2-5 : macros (protein/fat/carbs) =====================
DO $$
DECLARE v_p numeric; v_f numeric; v_c numeric;
BEGIN
  PERFORM public._auth_sim('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
  SELECT target_protein_g, target_fat_g, target_carbs_g INTO v_p, v_f, v_c
   FROM public.user_profiles WHERE user_id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  -- maintain : protein 144, fat 80, carbs 362
  PERFORM public._m2_record(5, 'M2-5 macros', v_p=144 AND v_f=80 AND v_c=362);
  IF NOT (v_p=144 AND v_f=80 AND v_c=362) THEN RAISE NOTICE 'FAIL M2-5 p=% f=% c=%', v_p,v_f,v_c; END IF;
  PERFORM public._auth_clear();
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m2_record(5, 'M2-5 macros', false);
  RAISE NOTICE 'FAIL M2-5: %', SQLERRM;
END $$;

-- ===================== M2-6 : calculation_version =====================
DO $$
DECLARE v_ver text;
BEGIN
  PERFORM public._auth_sim('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
  SELECT calculation_version INTO v_ver FROM public.user_profiles WHERE user_id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  PERFORM public._m2_record(6, 'M2-6 calculation_version', v_ver = 'm2_v1' AND v_ver = public.m2_calc_version());
  IF NOT (v_ver = 'm2_v1' AND v_ver = public.m2_calc_version()) THEN RAISE NOTICE 'FAIL M2-6 ver=%', v_ver; END IF;
  PERFORM public._auth_clear();
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m2_record(6, 'M2-6 calculation_version', false);
  RAISE NOTICE 'FAIL M2-6: %', SQLERRM;
END $$;

-- ===================== M2-7 : idempotence (set_profile x2) =====================
DO $$
DECLARE v1 uuid; v2 uuid; n int;
        bmr1 numeric; tdee1 numeric; tk1 numeric; p1 numeric; c1 numeric; f1 numeric;
        bmr2 numeric; tdee2 numeric; tk2 numeric; p2 numeric; c2 numeric; f2 numeric;
BEGIN
  PERFORM public._auth_sim('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
  v1 := public.set_profile('male',30,180,80,'moderate','maintain');
  SELECT count(*) INTO n FROM public.user_profiles WHERE user_id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  SELECT bmr_kcal, tdee_kcal, target_kcal, target_protein_g, target_carbs_g, target_fat_g
    INTO bmr1, tdee1, tk1, p1, c1, f1
  FROM public.user_profiles WHERE user_id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  v2 := public.set_profile('male',30,180,80,'moderate','maintain');
  SELECT bmr_kcal, tdee_kcal, target_kcal, target_protein_g, target_carbs_g, target_fat_g
    INTO bmr2, tdee2, tk2, p2, c2, f2
  FROM public.user_profiles WHERE user_id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  PERFORM public._m2_record(7, 'M2-7 idempotence',
    v1=v2 AND n=1 AND bmr1=bmr2 AND tdee1=tdee2 AND tk1=tk2 AND p1=p2 AND c1=c2 AND f1=f2);
  IF NOT (v1=v2 AND n=1 AND bmr1=bmr2 AND tdee1=tdee2 AND tk1=tk2 AND p1=p2 AND c1=c2 AND f1=f2) THEN
    RAISE NOTICE 'FAIL M2-7 v1=% v2=% n=%', v1, v2, n;
  END IF;
  PERFORM public._auth_clear();
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m2_record(7, 'M2-7 idempotence', false);
  RAISE NOTICE 'FAIL M2-7: %', SQLERRM;
END $$;

-- ===================== M2-8 : validations d'entrée (CHECK + RAISE) =====================
DO $$
DECLARE ok boolean := true;
BEGIN
  PERFORM public._auth_sim('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
  BEGIN PERFORM public.set_profile('other',30,180,80,'moderate','maintain'); ok:=false; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN PERFORM public.set_profile('male',5,180,80,'moderate','maintain');   ok:=false; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN PERFORM public.set_profile('male',30,180,10,'moderate','maintain');  ok:=false; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN PERFORM public.set_profile('male',30,50,80,'moderate','maintain');    ok:=false; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN PERFORM public.set_profile('male',30,180,80,'couch','maintain');      ok:=false; EXCEPTION WHEN OTHERS THEN NULL; END;
  BEGIN PERFORM public.set_profile('male',30,180,80,'moderate','bulk');       ok:=false; EXCEPTION WHEN OTHERS THEN NULL; END;
  PERFORM public._m2_record(8, 'M2-8 validations entrée', ok);
  IF NOT ok THEN RAISE NOTICE 'FAIL M2-8 une validation non levée'; END IF;
  PERFORM public._auth_clear();
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m2_record(8, 'M2-8 validations entrée', false);
  RAISE NOTICE 'FAIL M2-8: %', SQLERRM;
END $$;

-- ===================== M2-9 : RLS isolation (userB ne voit pas userA) =====================
SELECT public._auth_clear();
SET ROLE authenticated;
SELECT public._auth_sim('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
DO $$
DECLARE nAvis int; nB int; ok boolean;
BEGIN
  SELECT count(*) INTO nAvis FROM public.user_profiles WHERE user_id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  SELECT count(*) INTO nB FROM public.user_profiles WHERE user_id='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  ok := (nAvis = 0 AND nB = 1);
  PERFORM public._m2_record(9, 'M2-9 RLS isolation', ok);
  IF NOT ok THEN RAISE NOTICE 'FAIL M2-9 Avis=% B=%', nAvis, nB; END IF;
END $$;
RESET ROLE;
SELECT public._auth_clear();

-- ===================== M2-10 : no-claim fail closed =====================
DO $$
BEGIN
  PERFORM public._auth_clear();
  PERFORM public.set_profile('male',30,180,80,'moderate','maintain');  -- doit RAISE
  PERFORM public._m2_record(10, 'M2-10 no-claim fail closed', false);
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m2_record(10, 'M2-10 no-claim fail closed', true);
END $$;

-- ===================== M2-11 : generate_menu_from_profile (intégration M1) =====================
DO $$
DECLARE
  v_md uuid; v_md2 uuid;
  n_meals int; n_meals2 int; n_items int; n_items2 int; bad int;
  kcal_total numeric; lo numeric; hi numeric;
  t_md_kcal numeric; t_md_p numeric; t_md_c numeric; t_md_f numeric;
  t_prof_kcal numeric; t_prof_p numeric; t_prof_c numeric; t_prof_f numeric;
  ok boolean;
BEGIN
  PERFORM public._auth_sim('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
  SELECT target_kcal, target_protein_g, target_carbs_g, target_fat_g
    INTO t_prof_kcal, t_prof_p, t_prof_c, t_prof_f
  FROM public.user_profiles WHERE user_id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

  v_md := public.generate_menu_from_profile('2026-09-22'::date);

  SELECT target_kcal, target_protein_g, target_carbs_g, target_fat_g
    INTO t_md_kcal, t_md_p, t_md_c, t_md_f
  FROM public.menu_days WHERE id = v_md;
  SELECT count(*) INTO n_meals FROM public.meals WHERE menu_day_id = v_md;
  SELECT count(*) INTO bad
    FROM public.meal_items mi JOIN public.meals m ON m.id=mi.meal_id JOIN public.foods f ON f.id=mi.food_id
   WHERE m.menu_day_id=v_md AND (f.halal IS DISTINCT FROM TRUE OR f.lactose_free IS DISTINCT FROM TRUE);
  SELECT COALESCE(SUM(mi.quantity_g * f.kcal_per_100g/100.0),0) INTO kcal_total
    FROM public.meal_items mi JOIN public.meals m ON m.id=mi.meal_id JOIN public.foods f ON f.id=mi.food_id
   WHERE m.menu_day_id=v_md;
  SELECT count(*) INTO n_items
    FROM public.meal_items mi JOIN public.meals m ON m.id=mi.meal_id WHERE m.menu_day_id=v_md;
  lo := t_md_kcal * 0.95; hi := t_md_kcal * 1.05;

  -- idempotence : régénération -> même menu_day, même structure.
  v_md2 := public.generate_menu_from_profile('2026-09-22'::date);
  SELECT count(*) INTO n_meals2 FROM public.meals WHERE menu_day_id = v_md2;
  SELECT count(*) INTO n_items2
    FROM public.meal_items mi JOIN public.meals m ON m.id=mi.meal_id WHERE m.menu_day_id=v_md2;

  ok := v_md = v_md2
    AND n_meals = 4 AND n_meals2 = 4 AND n_items = 12 AND n_items2 = 12
    AND bad = 0
    AND (kcal_total BETWEEN lo AND hi)
    AND t_md_kcal = t_prof_kcal AND t_md_p = t_prof_p AND t_md_c = t_prof_c AND t_md_f = t_prof_f;
  PERFORM public._m2_record(11, 'M2-11 generate_menu_from_profile', ok);
  IF NOT ok THEN
    RAISE NOTICE 'FAIL M2-11 md=% md2=% meals=%/% items=%/% bad=% kcal=% lo=% hi=% mdK=% pfK=%',
      v_md, v_md2, n_meals, n_meals2, n_items, n_items2, bad, kcal_total, lo, hi, t_md_kcal, t_prof_kcal;
  END IF;
  PERFORM public._auth_clear();
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m2_record(11, 'M2-11 generate_menu_from_profile', false);
  RAISE NOTICE 'FAIL M2-11: %', SQLERRM;
END $$;

-- ===================== M2-12 : carbs non-négativité (profil extrême -> RAISE) =====================
DO $$
DECLARE n int;
BEGIN
  PERFORM public._auth_sim('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
  -- male 30 / 175 / 300 / sedentary / loss : protéines+lipides (540*4 + 300*9 = 4860) dépassent la cible
  -- (FLOOR=BMR≈3939) -> carbs < 0 -> compute_targets RAISE avant INSERT.
  PERFORM public.set_profile('male', 30, 175, 300, 'sedentary', 'loss');  -- doit RAISE
  PERFORM public._m2_record(12, 'M2-12 carbs non-negativite', false);
EXCEPTION WHEN OTHERS THEN
  SELECT count(*) INTO n FROM public.user_profiles
   WHERE user_id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' AND weight_kg=300;
  PERFORM public._m2_record(12, 'M2-12 carbs non-negativite', n = 0);
  IF n <> 0 THEN RAISE NOTICE 'FAIL M2-12 row créée n=%', n; END IF;
  PERFORM public._auth_clear();
END $$;

-- ===================== Résultat final =====================
\echo '==== M2 RESULT ===='
SELECT idx, test, ok FROM public.m2_results ORDER BY idx;
\pset tuples_only on
\pset format unaligned
SELECT 'M2_RESULT ' || count(*) FILTER (WHERE ok) || '/' || count(*) || ' ' ||
       CASE WHEN bool_and(ok) THEN 'GREEN' ELSE 'RED' END
FROM public.m2_results;
