-- tests/module1_menu_generation.sql
-- M1 Génération de menus — 8 checks (M1-1 .. M1-8). Doit renvoyer M1_RESULT 8/8 GREEN.
-- Exécuté par scripts/run_m1.sh sur une DB fraîche (mig 001-008 + seed + _auth_sim) APRÈS M0 16/16.
-- Décisions : M1-A DEFINER fail closed, M1-B upsert cibles, M1-C déterministe kcal ±5%, M1-D halal+lactose_free, M1-E idempotent.
-- userA = aaaaa... ; userB = bbbbb... ; day = 2026-09-20.

\set ECHO none
\pset pager off

CREATE TABLE public.m1_results(idx int PRIMARY KEY, test text, ok boolean);

CREATE OR REPLACE FUNCTION public._m1_record(p_idx int, p_test text, p_ok boolean)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  INSERT INTO public.m1_results VALUES (p_idx, p_test, p_ok)
  ON CONFLICT (idx) DO UPDATE SET test = EXCLUDED.test, ok = EXCLUDED.ok;
$$;
GRANT EXECUTE ON FUNCTION public._m1_record(int,text,boolean) TO public;

-- ===================== M1-1 : generate_menu crée menu_day + 4 cibles =====================
SELECT public._auth_clear();
DO $$
DECLARE v_md uuid; nf int;
BEGIN
  PERFORM public._auth_sim('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
  v_md := public.generate_menu('2026-09-20'::date, 2000, 150, 250, 70);
  SELECT count(*) INTO nf FROM public.menu_days
   WHERE id = v_md AND user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
     AND day = '2026-09-20'::date
     AND target_kcal = 2000 AND target_protein_g = 150
     AND target_carbs_g = 250 AND target_fat_g = 70;
  PERFORM public._m1_record(1, 'M1-1 menu_day + cibles', nf = 1);
  IF nf <> 1 THEN RAISE NOTICE 'FAIL M1-1 nf=% md=%', nf, v_md; END IF;
  PERFORM public._auth_clear();
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m1_record(1, 'M1-1 menu_day + cibles', false);
  RAISE NOTICE 'FAIL M1-1: %', SQLERRM;
END $$;

-- ===================== M1-2 : 4 meals (breakfast/lunch/dinner/snack) =====================
DO $$
DECLARE n int; v_md uuid;
BEGIN
  SELECT id INTO v_md FROM public.menu_days
   WHERE user_id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' AND day='2026-09-20'::date;
  SELECT count(*) INTO n FROM public.meals WHERE menu_day_id = v_md;
  IF n = 4
     AND EXISTS (SELECT 1 FROM public.meals WHERE menu_day_id=v_md AND meal_type='breakfast')
     AND EXISTS (SELECT 1 FROM public.meals WHERE menu_day_id=v_md AND meal_type='lunch')
     AND EXISTS (SELECT 1 FROM public.meals WHERE menu_day_id=v_md AND meal_type='dinner')
     AND EXISTS (SELECT 1 FROM public.meals WHERE menu_day_id=v_md AND meal_type='snack')
  THEN PERFORM public._m1_record(2, 'M1-2 4 meals (types)', true);
  ELSE PERFORM public._m1_record(2, 'M1-2 4 meals (types)', false); RAISE NOTICE 'FAIL M1-2 n=%', n; END IF;
END $$;

-- ===================== M1-3 : conformité chaque food (halal + lactose_free) =====================
DO $$
DECLARE bad int;
BEGIN
  SELECT count(*) INTO bad
  FROM public.meal_items mi
  JOIN public.meals m ON m.id = mi.meal_id
  JOIN public.menu_days md ON md.id = m.menu_day_id
  JOIN public.foods f ON f.id = mi.food_id
  WHERE md.user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' AND md.day = '2026-09-20'::date
    AND (f.halal IS DISTINCT FROM TRUE OR f.lactose_free IS DISTINCT FROM TRUE);
  PERFORM public._m1_record(3, 'M1-3 conformité foods (halal+lactose_free)', bad = 0);
  IF bad <> 0 THEN RAISE NOTICE 'FAIL M1-3 bad=%', bad; END IF;
END $$;

-- ===================== M1-4 : kcal total ≈ cible (±5%) =====================
DO $$
DECLARE total numeric(12,2); target numeric(12,2) := 2000; lo numeric; hi numeric;
BEGIN
  SELECT COALESCE(SUM(mi.quantity_g * f.kcal_per_100g / 100.0), 0) INTO total
  FROM public.meal_items mi
  JOIN public.meals m ON m.id = mi.meal_id
  JOIN public.menu_days md ON md.id = m.menu_day_id
  JOIN public.foods f ON f.id = mi.food_id
  WHERE md.user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' AND md.day = '2026-09-20'::date;
  lo := target * 0.95; hi := target * 1.05;
  PERFORM public._m1_record(4, 'M1-4 kcal total ±5%', total BETWEEN lo AND hi);
  IF NOT (total BETWEEN lo AND hi) THEN RAISE NOTICE 'FAIL M1-4 total=% target=%', total, target; END IF;
END $$;

-- ===================== M1-5 : quantity_g > 0 pour tout item =====================
DO $$
DECLARE bad int;
BEGIN
  SELECT count(*) INTO bad
  FROM public.meal_items mi
  JOIN public.meals m ON m.id = mi.meal_id
  JOIN public.menu_days md ON md.id = m.menu_day_id
  WHERE md.user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' AND md.day = '2026-09-20'::date
    AND mi.quantity_g <= 0;
  PERFORM public._m1_record(5, 'M1-5 quantity_g > 0', bad = 0);
  IF bad <> 0 THEN RAISE NOTICE 'FAIL M1-5 bad=%', bad; END IF;
END $$;

-- ===================== M1-6 : idempotence (régénération) =====================
DO $$
DECLARE v1 uuid; v2 uuid; nmeals int; nitems int; kcal1 numeric(12,2); kcal2 numeric(12,2);
BEGIN
  PERFORM public._auth_sim('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
  v1 := public.generate_menu('2026-09-20'::date, 2000, 150, 250, 70);
  SELECT count(*) INTO nmeals FROM public.meals WHERE menu_day_id = v1;
  SELECT count(*) INTO nitems FROM public.meal_items WHERE meal_id IN (SELECT id FROM public.meals WHERE menu_day_id = v1);
  SELECT COALESCE(SUM(mi.quantity_g * f.kcal_per_100g / 100.0),0) INTO kcal1
    FROM public.meal_items mi JOIN public.meals m ON m.id=mi.meal_id JOIN public.foods f ON f.id=mi.food_id
    WHERE m.menu_day_id = v1;
  v2 := public.generate_menu('2026-09-20'::date, 2000, 150, 250, 70);
  SELECT count(*) INTO nmeals FROM public.meals WHERE menu_day_id = v2;
  SELECT count(*) INTO nitems FROM public.meal_items WHERE meal_id IN (SELECT id FROM public.meals WHERE menu_day_id = v2);
  SELECT COALESCE(SUM(mi.quantity_g * f.kcal_per_100g / 100.0),0) INTO kcal2
    FROM public.meal_items mi JOIN public.meals m ON m.id=mi.meal_id JOIN public.foods f ON f.id=mi.food_id
    WHERE m.menu_day_id = v2;
  PERFORM public._m1_record(6, 'M1-6 idempotence', v1 = v2 AND nmeals = 4 AND nitems = 12 AND kcal1 = kcal2);
  IF NOT (v1 = v2 AND nmeals = 4 AND nitems = 12 AND kcal1 = kcal2) THEN
    RAISE NOTICE 'FAIL M1-6 v1=% v2=% meals=% items=% kcal1=% kcal2=%', v1, v2, nmeals, nitems, kcal1, kcal2;
  END IF;
  PERFORM public._auth_clear();
END $$;

-- ===================== M1-7 : isolation userA / userB =====================
DO $$
DECLARE vA uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
        vB uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
        nAmd int; nAmeals int; nBmd int; nBmeals int; ok boolean;
BEGIN
  PERFORM public._auth_sim(vB);
  PERFORM public.generate_menu('2026-09-20'::date, 1800, 120, 200, 60);  -- userB génère pour le même jour
  SELECT count(*) INTO nAmd    FROM public.menu_days WHERE user_id = vA AND day='2026-09-20'::date;
  SELECT count(*) INTO nAmeals FROM public.meals m JOIN public.menu_days md ON md.id=m.menu_day_id
                                WHERE md.user_id=vA AND md.day='2026-09-20'::date;
  SELECT count(*) INTO nBmd    FROM public.menu_days WHERE user_id = vB AND day='2026-09-20'::date;
  SELECT count(*) INTO nBmeals FROM public.meals m JOIN public.menu_days md ON md.id=m.menu_day_id
                                WHERE md.user_id=vB AND md.day='2026-09-20'::date;
  ok := (nAmd = 1 AND nAmeals = 4 AND nBmd = 1 AND nBmeals = 4);
  PERFORM public._m1_record(7, 'M1-7 isolation userA/userB', ok);
  PERFORM public._auth_clear();
  IF NOT ok THEN RAISE NOTICE 'FAIL M1-7 Amd=% Ameals=% Bmd=% Bmeals=%', nAmd, nAmeals, nBmd, nBmeals; END IF;
END $$;

-- ===================== M1-8 : no-claim -> fail closed =====================
DO $$
BEGIN
  PERFORM public._auth_clear();
  PERFORM public.generate_menu('2026-09-21'::date, 2000, 150, 250, 70);  -- doit RAISE
  PERFORM public._m1_record(8, 'M1-8 no-claim fail closed', false);
EXCEPTION WHEN OTHERS THEN
  PERFORM public._m1_record(8, 'M1-8 no-claim fail closed', true);
END $$;

-- ===================== Résultat final =====================
\echo '==== M1 RESULT ===='
SELECT idx, test, ok FROM public.m1_results ORDER BY idx;
\pset tuples_only on
\pset format unaligned
SELECT 'M1_RESULT ' || count(*) FILTER (WHERE ok) || '/' || count(*) || ' ' ||
       CASE WHEN bool_and(ok) THEN 'GREEN' ELSE 'RED' END
FROM public.m1_results;
