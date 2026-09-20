-- tests/module0_foundation.sql
-- M0 Fondation — 16 checks (M0-1 .. M0-16). Doit renvoyer M0_RESULT 16/16 GREEN.
-- Exécuté par scripts/run_m0.sh sur une DB fraîche (migrations 001..007 + seed + _auth_sim).
-- Recorder SECURITY DEFINER : inscriptible quel que soit le rôle courant (RLS/GRANT tests).

\set ECHO none
\pset pager off

-- Table de résultats (permanente, owner postgres) + recorder upsert.
CREATE TABLE public.m0_results(idx int PRIMARY KEY, test text, ok boolean);

CREATE OR REPLACE FUNCTION public._m0_record(p_idx int, p_test text, p_ok boolean)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  INSERT INTO public.m0_results VALUES (p_idx, p_test, p_ok)
  ON CONFLICT (idx) DO UPDATE SET test = EXCLUDED.test, ok = EXCLUDED.ok;
$$;
GRANT EXECUTE ON FUNCTION public._m0_record(int,text,boolean) TO public;

-- ===================== M0-1 : pgcrypto =====================
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname='pgcrypto') THEN
    RAISE EXCEPTION 'pgcrypto manquant';
  END IF;
  PERFORM public._m0_record(1, 'M0-1 pgcrypto', true);
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m0_record(1, 'M0-1 pgcrypto', false);
  RAISE NOTICE 'FAIL M0-1: %', SQLERRM;
END $$;

-- ===================== M0-2 : rôles Supabase =====================
DO $$ BEGIN
  IF NOT (EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated')
      AND EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon')
      AND EXISTS(SELECT 1 FROM pg_roles WHERE rolname='service_role')) THEN
    RAISE EXCEPTION 'rôle Supabase manquant';
  END IF;
  PERFORM public._m0_record(2, 'M0-2 roles supabase', true);
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m0_record(2, 'M0-2 roles supabase', false);
  RAISE NOTICE 'FAIL M0-2: %', SQLERRM;
END $$;

-- ===================== M0-3 : foods colonnes (11) =====================
DO $$
DECLARE c int;
BEGIN
  SELECT count(*) INTO c FROM information_schema.columns
  WHERE table_schema='public' AND table_name='foods'
    AND column_name IN ('id','name','source','kcal_per_100g','protein_g','carbs_g',
                        'fat_g','fiber_g','halal','lactose_free','dairy_free');
  IF c <> 11 THEN RAISE EXCEPTION 'foods: %/11 colonnes attendues', c; END IF;
  PERFORM public._m0_record(3, 'M0-3 foods colonnes', true);
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m0_record(3, 'M0-3 foods colonnes', false);
  RAISE NOTICE 'FAIL M0-3: %', SQLERRM;
END $$;

-- ===================== M0-4 : foods.name UNIQUE =====================
DO $$
DECLARE v text := '__m0_dup_name__';
BEGIN
  INSERT INTO public.foods(name, source, kcal_per_100g, protein_g, carbs_g, fat_g)
  VALUES (v, 'TEST', 10, 0, 0, 0);
  BEGIN
    INSERT INTO public.foods(name, source, kcal_per_100g, protein_g, carbs_g, fat_g)
    VALUES (v, 'TEST', 20, 0, 0, 0);
    RAISE EXCEPTION 'UNIQUE foods.name non enforce';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  PERFORM public._m0_record(4, 'M0-4 foods name unique', true);
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m0_record(4, 'M0-4 foods name unique', false);
  RAISE NOTICE 'FAIL M0-4: %', SQLERRM;
END $$;

-- ===================== M0-5 : foods CHECK kcal >= 0 =====================
DO $$ BEGIN
  BEGIN
    INSERT INTO public.foods(name, source, kcal_per_100g, protein_g, carbs_g, fat_g)
    VALUES ('__m0_neg__', 'TEST', -1, 0, 0, 0);
    RAISE EXCEPTION 'CHECK kcal>=0 non enforce';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM public._m0_record(5, 'M0-5 foods CHECK kcal>=0', true);
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m0_record(5, 'M0-5 foods CHECK kcal>=0', false);
  RAISE NOTICE 'FAIL M0-5: %', SQLERRM;
END $$;

-- ===================== M0-6 : menu_days UNIQUE(user_id, day) =====================
DO $$
BEGIN
  INSERT INTO public.menu_days(user_id, day)
  VALUES ('66666666-6666-6666-6666-666666666666','2026-07-07');
  BEGIN
    INSERT INTO public.menu_days(user_id, day)
    VALUES ('66666666-6666-6666-6666-666666666666','2026-07-07');
    RAISE EXCEPTION 'UNIQUE(user_id,day) non enforce';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  PERFORM public._m0_record(6, 'M0-6 menu_days unique(user,day)', true);
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m0_record(6, 'M0-6 menu_days unique(user,day)', false);
  RAISE NOTICE 'FAIL M0-6: %', SQLERRM;
END $$;

-- ===================== M0-7 : menu_days UNE SEULE PK (garde double-PK) =====================
DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM pg_constraint
  WHERE conrelid = 'public.menu_days'::regclass AND contype = 'p';
  IF n <> 1 THEN RAISE EXCEPTION 'menu_days a % PK (attendu 1, bug double-PK)', n; END IF;
  PERFORM public._m0_record(7, 'M0-7 menu_days single PK', true);
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m0_record(7, 'M0-7 menu_days single PK', false);
  RAISE NOTICE 'FAIL M0-7: %', SQLERRM;
END $$;

-- ===================== M0-8 : meals CHECK meal_type + UNIQUE + FK CASCADE =====================
DO $$
DECLARE v_md uuid; v_ml uuid;
BEGIN
  INSERT INTO public.menu_days(user_id, day)
  VALUES ('44444444-4444-4444-4444-444444444444','2026-05-05') RETURNING id INTO v_md;
  BEGIN
    INSERT INTO public.meals(menu_day_id, meal_type) VALUES (v_md, 'brunch');
    RAISE EXCEPTION 'meal_type CHECK non enforce (brunch accepté)';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  INSERT INTO public.meals(menu_day_id, meal_type) VALUES (v_md, 'breakfast') RETURNING id INTO v_ml;
  BEGIN
    INSERT INTO public.meals(menu_day_id, meal_type) VALUES (v_md, 'breakfast');
    RAISE EXCEPTION 'UNIQUE(menu_day_id,meal_type) non enforce';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  DELETE FROM public.menu_days WHERE id = v_md;
  IF EXISTS (SELECT 1 FROM public.meals WHERE id = v_ml) THEN
    RAISE EXCEPTION 'FK CASCADE non effectif';
  END IF;
  PERFORM public._m0_record(8, 'M0-8 meals CHECK+UNIQUE+CASCADE', true);
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m0_record(8, 'M0-8 meals CHECK+UNIQUE+CASCADE', false);
  RAISE NOTICE 'FAIL M0-8: %', SQLERRM;
END $$;

-- ===================== M0-9 : meal_items CHECK qty>0 + UNIQUE + FK =====================
DO $$
DECLARE v_fd uuid; v_md uuid; v_ml uuid;
BEGIN
  SELECT id INTO v_fd FROM public.foods LIMIT 1;
  INSERT INTO public.menu_days(user_id, day)
  VALUES ('55555555-5555-5555-5555-555555555555','2026-06-06') RETURNING id INTO v_md;
  INSERT INTO public.meals(menu_day_id, meal_type) VALUES (v_md, 'lunch') RETURNING id INTO v_ml;
  BEGIN
    INSERT INTO public.meal_items(meal_id, food_id, quantity_g) VALUES (v_ml, v_fd, 0);
    RAISE EXCEPTION 'quantity_g>0 non enforce';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  INSERT INTO public.meal_items(meal_id, food_id, quantity_g) VALUES (v_ml, v_fd, 100);
  BEGIN
    INSERT INTO public.meal_items(meal_id, food_id, quantity_g) VALUES (v_ml, v_fd, 50);
    RAISE EXCEPTION 'UNIQUE(meal_id,food_id) non enforce';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO public.meal_items(meal_id, food_id, quantity_g)
    VALUES (v_ml, '99999999-9999-9999-9999-999999999999', 10);
    RAISE EXCEPTION 'FK food non enforce';
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;
  PERFORM public._m0_record(9, 'M0-9 meal_items CHECK+UNIQUE+FK', true);
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m0_record(9, 'M0-9 meal_items CHECK+UNIQUE+FK', false);
  RAISE NOTICE 'FAIL M0-9: %', SQLERRM;
END $$;

-- ===================== M0-10 : RLS active sur les 3 tables user =====================
DO $$ BEGIN
  IF NOT (EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                WHERE n.nspname='public' AND c.relname='menu_days'  AND c.relrowsecurity)
      AND EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                WHERE n.nspname='public' AND c.relname='meals'      AND c.relrowsecurity)
      AND EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                WHERE n.nspname='public' AND c.relname='meal_items' AND c.relrowsecurity)) THEN
    RAISE EXCEPTION 'RLS non active sur les 3 tables user';
  END IF;
  PERFORM public._m0_record(10, 'M0-10 RLS active', true);
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m0_record(10, 'M0-10 RLS active', false);
  RAISE NOTICE 'FAIL M0-10: %', SQLERRM;
END $$;

-- ===================== M0-11 : current_user_id NULL sans claims =====================
SELECT public._auth_clear();
DO $$ BEGIN
  IF public.current_user_id() IS NOT NULL THEN
    RAISE EXCEPTION 'current_user_id devrait être NULL sans claims';
  END IF;
  PERFORM public._m0_record(11, 'M0-11 current_user_id NULL sans claims', true);
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m0_record(11, 'M0-11 current_user_id NULL sans claims', false);
  RAISE NOTICE 'FAIL M0-11: %', SQLERRM;
END $$;

-- ===================== M0-12 : current_user_id via _auth_sim =====================
SELECT public._auth_sim('33333333-3333-3333-3333-333333333333');
DO $$ BEGIN
  IF public.current_user_id() <> '33333333-3333-3333-3333-333333333333'::uuid THEN
    RAISE EXCEPTION 'current_user_id != sub après _auth_sim';
  END IF;
  PERFORM public._m0_record(12, 'M0-12 current_user_id via _auth_sim', true);
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m0_record(12, 'M0-12 current_user_id via _auth_sim', false);
  RAISE NOTICE 'FAIL M0-12: %', SQLERRM;
END $$;
SELECT public._auth_clear();

-- ===================== M0-14 : RLS owner + WITH CHECK =====================
SET ROLE authenticated;
SELECT public._auth_sim('11111111-1111-1111-1111-111111111111');  -- userA
DO $$ BEGIN
  INSERT INTO public.menu_days(user_id, day)
  VALUES ('11111111-1111-1111-1111-111111111111','2026-02-02');
  BEGIN
    INSERT INTO public.menu_days(user_id, day)
    VALUES ('22222222-2222-2222-2222-222222222222','2026-02-03');
    RAISE EXCEPTION 'WITH CHECK non enforce (insert userB réussi en tant que userA)';
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  PERFORM 1 FROM public.menu_days WHERE user_id='11111111-1111-1111-1111-111111111111';
  IF NOT FOUND THEN RAISE EXCEPTION 'owner ne voit pas sa menu_day'; END IF;
  PERFORM public._m0_record(14, 'M0-14 RLS owner + WITH CHECK', true);
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m0_record(14, 'M0-14 RLS owner + WITH CHECK', false);
  RAISE NOTICE 'FAIL M0-14: %', SQLERRM;
END $$;

-- ===================== M0-13 : RLS isolation (userB ne voit pas userA) =====================
SELECT public._auth_sim('22222222-2222-2222-2222-222222222222');  -- userB
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.menu_days
             WHERE user_id='11111111-1111-1111-1111-111111111111') THEN
    RAISE EXCEPTION 'isolation RLS : userB voit les rows de userA';
  END IF;
  PERFORM public._m0_record(13, 'M0-13 RLS isolation', true);
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m0_record(13, 'M0-13 RLS isolation', false);
  RAISE NOTICE 'FAIL M0-13: %', SQLERRM;
END $$;
RESET ROLE;
SELECT public._auth_clear();

-- ===================== M0-15 : GRANTs (anon SELECT ok / INSERT refusé ; auth SELECT ok) =====================
SET ROLE anon;
DO $$
DECLARE ok boolean := true;
BEGIN
  BEGIN PERFORM count(*) FROM public.foods; EXCEPTION WHEN OTHERS THEN ok := false; END;
  BEGIN
    INSERT INTO public.foods(name, source, kcal_per_100g, protein_g, carbs_g, fat_g)
    VALUES ('__anon_no__', 'TEST', 1, 0, 0, 0);
    ok := false;  -- aurait dû être refusé
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM public._m0_record(15, 'M0-15 grants (anon SELECT ok / INSERT refuse + auth SELECT ok)', ok);
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m0_record(15, 'M0-15 grants (anon SELECT ok / INSERT refuse + auth SELECT ok)', false);
  RAISE NOTICE 'FAIL M0-15 anon: %', SQLERRM;
END $$;
RESET ROLE;
SET ROLE authenticated;
DO $$ BEGIN
  PERFORM count(*) FROM public.foods;  -- authenticated SELECT foods OK
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m0_record(15, 'M0-15 grants (auth SELECT foods)', false);
  RAISE NOTICE 'FAIL M0-15 authenticated SELECT foods: %', SQLERRM;
END $$;
RESET ROLE;

-- ===================== M0-16 : seed snapshot (21 foods, flags, 4 tables) =====================
DO $$
DECLARE nf int; nt int; bad int;
BEGIN
  SELECT count(*) INTO nf FROM public.foods
  WHERE source = 'USDA FoodData Central (vérifié)';
  IF nf <> 21 THEN RAISE EXCEPTION 'seed: % foods (attendu 21)', nf; END IF;
  SELECT count(*) INTO bad FROM public.foods
  WHERE source = 'USDA FoodData Central (vérifié)'
    AND (halal IS DISTINCT FROM TRUE OR lactose_free IS DISTINCT FROM TRUE);
  IF bad <> 0 THEN RAISE EXCEPTION 'seed: % aliments non conformes (halal/lactose_free)', bad; END IF;
  SELECT count(*) INTO nt FROM information_schema.tables
  WHERE table_schema='public' AND table_name IN ('foods','menu_days','meals','meal_items');
  IF nt <> 4 THEN RAISE EXCEPTION 'snapshot: % tables (attendu 4)', nt; END IF;
  PERFORM public._m0_record(16, 'M0-16 seed snapshot (21 foods, flags, 4 tables)', true);
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m0_record(16, 'M0-16 seed snapshot (21 foods, flags, 4 tables)', false);
  RAISE NOTICE 'FAIL M0-16: %', SQLERRM;
END $$;

-- ===================== Résultat final =====================
\echo '==== M0 RESULT ===='
SELECT idx, test, ok FROM public.m0_results ORDER BY idx;
\pset tuples_only on
\pset format unaligned
SELECT 'M0_RESULT ' || count(*) FILTER (WHERE ok) || '/' || count(*) || ' ' ||
       CASE WHEN bool_and(ok) THEN 'GREEN' ELSE 'RED' END
FROM public.m0_results;
