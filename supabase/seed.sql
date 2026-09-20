-- supabase/seed.sql
-- 21 aliments SEED DE DÉMONSTRATION — valeurs VÉRIFIÉES USDA FoodData Central (per 100g, état cuit/cru conforme au nom).
-- Tous : halal = true, lactose_free = true, dairy_free = true (conformes aux contraintes de l'app).
-- source = 'USDA FoodData Central (vérifié)'.
-- Entrées FDC de référence (valeurs /100g) :
--   Poulet blanc cuit       FDC 171477  chicken breast, meat only, roasted
--   Bœuf maigre cuit        FDC 173050  beef, loin, top sirloin filet, separable lean only, trimmed to 0" fat, select, cooked, grilled
--   Dinde cuite             turkey breast, meat only, roasted
--   Œuf entier cuit         FDC 173424  egg, whole, hard-boiled
--   Saumon cuit             FDC 175168  salmon, Atlantic, farmed, cooked
--   Thon cuit               FDC 172006  fish, tuna, yellowfin, fresh, cooked, dry heat
--   Lentilles cuites        FDC 172421
--   Pois chiches cuits      FDC 173799
--   Haricots rouges cuits   FDC 173740
--   Riz blanc cuit          FDC 168935  long-grain, cooked
--   Riz complet cuit        FDC 169704  long-grain, cooked
--   Pâtes cuites            pasta, cooked, enriched
--   Flocons d'avoine        USDA SR Legacy  oats, regular/quick, dry  (389/16.9/66.3/6.9/10.1)
--   Pain complet            whole-wheat bread
--   Pomme de terre cuite    potato, boiled, flesh and skin
--   Brocoli cuit            broccoli, cooked, boiled
--   Épinards cuits          spinach, cooked, boiled
--   Carotte cuite           carrots, cooked, boiled
--   Tomate crue             tomato, raw
--   Huile d'olive           olive oil
--   Amande                  FDC 170567

INSERT INTO public.foods
  (name, source, kcal_per_100g, protein_g, carbs_g, fat_g, fiber_g, halal, lactose_free, dairy_free)
VALUES
  ('Poulet blanc cuit',     'USDA FoodData Central (vérifié)', 165, 31.0,  0.0,  3.6,  0.0, true, true, true),
  ('Bœuf maigre cuit',      'USDA FoodData Central (vérifié)', 165, 30.8,  0.0,  4.7,  0.0, true, true, true),
  ('Dinde cuite',           'USDA FoodData Central (vérifié)', 135, 30.0,  0.0,  1.0,  0.0, true, true, true),
  ('Œuf entier cuit',       'USDA FoodData Central (vérifié)', 155, 13.0,  1.1, 11.0,  0.0, true, true, true),
  ('Saumon cuit',           'USDA FoodData Central (vérifié)', 206, 22.0,  0.0, 12.0,  0.0, true, true, true),
  ('Thon cuit',             'USDA FoodData Central (vérifié)', 130, 29.1,  0.0,  0.6,  0.0, true, true, true),
  ('Lentilles cuites',      'USDA FoodData Central (vérifié)', 116,  9.0, 20.0,  0.4,  7.9, true, true, true),
  ('Pois chiches cuits',    'USDA FoodData Central (vérifié)', 164,  9.0, 27.0,  2.6,  7.6, true, true, true),
  ('Haricots rouges cuits', 'USDA FoodData Central (vérifié)', 127,  9.0, 23.0,  0.5,  6.4, true, true, true),
  ('Riz blanc cuit',        'USDA FoodData Central (vérifié)', 130,  2.7, 28.0,  0.3,  0.4, true, true, true),
  ('Riz complet cuit',      'USDA FoodData Central (vérifié)', 123,  2.7, 26.0,  1.0,  1.8, true, true, true),
  ('Pâtes cuites',          'USDA FoodData Central (vérifié)', 158,  6.0, 31.0,  0.9,  1.8, true, true, true),
  ('Flocons d''avoine',     'USDA FoodData Central (vérifié)', 389, 16.9, 66.0,  7.0, 10.0, true, true, true),
  ('Pain complet',          'USDA FoodData Central (vérifié)', 247, 13.0, 41.0,  4.2,  7.0, true, true, true),
  ('Pomme de terre cuite',  'USDA FoodData Central (vérifié)',  87,  2.0, 20.0,  0.1,  2.2, true, true, true),
  ('Brocoli cuit',          'USDA FoodData Central (vérifié)',  35,  2.4,  7.0,  0.4,  3.3, true, true, true),
  ('Épinards cuits',        'USDA FoodData Central (vérifié)',  23,  3.0,  3.8,  0.3,  2.4, true, true, true),
  ('Carotte cuite',         'USDA FoodData Central (vérifié)',  35,  0.8,  8.0,  0.3,  3.0, true, true, true),
  ('Tomate crue',           'USDA FoodData Central (vérifié)',  18,  0.9,  3.9,  0.2,  1.2, true, true, true),
  ('Huile d''olive',        'USDA FoodData Central (vérifié)', 884,  0.0,  0.0,100.0,  0.0, true, true, true),
  ('Amande',                'USDA FoodData Central (vérifié)', 579, 21.0, 22.0, 50.0, 12.5, true, true, true)
ON CONFLICT (name) DO NOTHING;
