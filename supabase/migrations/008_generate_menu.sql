-- 008_generate_menu.sql
-- M1 Génération de menus — fonction PL/pgSQL de génération/régénération d'un jour de menu.
-- Décisions validées :
--   M1-A : SECURITY DEFINER + search_path=public ; user_id = current_user_id() (pas de param) ; aucun accès cross-user, fail closed.
--   M1-B : 4 cibles passées en params, upsert dans menu_days (ON CONFLICT user_id,day) ; NULL stockée mais ignorée pour l'optimisation.
--   M1-C : déterministe, 4 repas (breakfast/lunch/dinner/snack), templates fixes ; optimise UNIQUEMENT les kcal (test vérifie ±5%).
--   M1-D : sélection exclusivement halal=true AND lactose_free=true.
--   M1-E : régénération idempotente et atomique (DELETE meals du jour puis réinsert ; menu_day upserté).

CREATE OR REPLACE FUNCTION public.generate_menu(
  p_day             date,
  p_target_kcal      numeric,
  p_target_protein_g numeric,
  p_target_carbs_g   numeric,
  p_target_fat_g     numeric
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user      uuid := public.current_user_id();
  v_md        uuid;
  v_meal_id   uuid;
  v_food_id   uuid;
  v_food_kcal numeric(8,2);
  v_meal_kcal numeric(8,2);
  v_qty       numeric(8,2);
  rec         record;
BEGIN
  -- M1-A : contrôle strict, fail closed (aucun utilisateur = refus).
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'generate_menu: utilisateur courant indéfini (claim JWT absent)';
  END IF;

  -- M1-C : le kcal cible est obligatoire (>0) ; les autres cibles peuvent être NULL (stockées, non optimisées).
  IF p_target_kcal IS NULL OR p_target_kcal <= 0 THEN
    RAISE EXCEPTION 'generate_menu: p_target_kcal doit être > 0';
  END IF;

  -- M1-B : upsert menu_day avec les 4 cibles (NULL stockées telles quelles).
  INSERT INTO public.menu_days (user_id, day, target_kcal, target_protein_g, target_carbs_g, target_fat_g)
  VALUES (v_user, p_day, p_target_kcal, p_target_protein_g, p_target_carbs_g, p_target_fat_g)
  ON CONFLICT (user_id, day) DO UPDATE
    SET target_kcal      = EXCLUDED.target_kcal,
        target_protein_g = EXCLUDED.target_protein_g,
        target_carbs_g   = EXCLUDED.target_carbs_g,
        target_fat_g     = EXCLUDED.target_fat_g
  RETURNING id INTO v_md;

  -- M1-E : régénération atomique — on supprime les repas existants (cascade sur meal_items).
  DELETE FROM public.meals WHERE menu_day_id = v_md;

  -- Création des 4 repas (un par meal_type).
  INSERT INTO public.meals (menu_day_id, meal_type)
  SELECT v_md, m.meal_type
  FROM (VALUES ('breakfast'), ('lunch'), ('dinner'), ('snack')) AS m(meal_type)
  ON CONFLICT DO NOTHING;

  -- M1-C/D : templates fixes ; quantités calées sur les kcal cibles par repas.
  -- split : breakfast 0.25, lunch 0.35, dinner 0.30, snack 0.10.
  FOR rec IN
    SELECT t.meal_type, t.food_name, t.proportion::numeric AS proportion, t.split::numeric AS split
    FROM (VALUES
      ('breakfast', 'Flocons d''avoine', 0.55, 0.25),
      ('breakfast', 'Œuf entier cuit',  0.35, 0.25),
      ('breakfast', 'Tomate crue',       0.10, 0.25),
      ('lunch',     'Poulet blanc cuit', 0.40, 0.35),
      ('lunch',     'Riz blanc cuit',    0.35, 0.35),
      ('lunch',     'Brocoli cuit',      0.10, 0.35),
      ('lunch',     'Huile d''olive',    0.15, 0.35),
      ('dinner',    'Thon cuit',         0.40, 0.30),
      ('dinner',    'Lentilles cuites',  0.35, 0.30),
      ('dinner',    'Épinards cuits',    0.10, 0.30),
      ('dinner',    'Huile d''olive',    0.15, 0.30),
      ('snack',     'Amande',            1.00, 0.10)
    ) AS t(meal_type, food_name, proportion, split)
  LOOP
    -- M1-D : aliment conforme uniquement (halal + lactose_free).
    SELECT id, kcal_per_100g INTO v_food_id, v_food_kcal
    FROM public.foods
    WHERE name = rec.food_name AND halal IS TRUE AND lactose_free IS TRUE;

    IF v_food_id IS NULL THEN
      RAISE EXCEPTION 'generate_menu: aliment absent ou non conforme (halal/lactose_free): %', rec.food_name;
    END IF;

    v_meal_kcal := p_target_kcal * rec.split;
    v_qty := round((v_meal_kcal * rec.proportion * 100.0 / v_food_kcal)::numeric, 2);

    IF v_qty <= 0 THEN
      RAISE EXCEPTION 'generate_menu: quantity_g <= 0 pour %', rec.food_name;
    END IF;

    SELECT id INTO v_meal_id
    FROM public.meals
    WHERE menu_day_id = v_md AND meal_type = rec.meal_type;

    INSERT INTO public.meal_items (meal_id, food_id, quantity_g)
    VALUES (v_meal_id, v_food_id, v_qty);
  END LOOP;

  RETURN v_md;
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_menu(date,numeric,numeric,numeric,numeric) TO authenticated;

COMMENT ON FUNCTION public.generate_menu(date,numeric,numeric,numeric,numeric) IS
  'M1 : génère/régénère le menu d un jour pour current_user_id(). Déterministe, 4 repas, optimise les kcal (test vérifie ±5%). Aliments halal+lactose_free uniquement. SECURITY DEFINER, aucun accès cross-user.';
