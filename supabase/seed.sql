-- supabase/seed.sql
-- 21 aliments SEED DE DÉMONSTRATION (valeurs NON vérifiées Ciqual/ANSES).
-- Tous : halal = true, lactose_free = true, dairy_free = true (conformes aux contraintes de l'app).
-- source = 'seed démo (valeurs non vérifiées)'.
-- Valeurs macro arrondies (/100g) — à remplacer par une source officielle vérifiable plus tard.

INSERT INTO public.foods
  (name, source, kcal_per_100g, protein_g, carbs_g, fat_g, fiber_g, halal, lactose_free, dairy_free)
VALUES
  ('Poulet blanc cuit',     'seed démo (valeurs non vérifiées)', 165, 31.0,  0.0,  3.6,  0.0, true, true, true),
  ('Bœuf maigre cuit',      'seed démo (valeurs non vérifiées)', 250, 26.0,  0.0, 15.0,  0.0, true, true, true),
  ('Dinde cuite',           'seed démo (valeurs non vérifiées)', 135, 30.0,  0.0,  1.0,  0.0, true, true, true),
  ('Œuf entier cuit',       'seed démo (valeurs non vérifiées)', 155, 13.0,  1.1, 11.0,  0.0, true, true, true),
  ('Saumon cuit',           'seed démo (valeurs non vérifiées)', 206, 22.0,  0.0, 12.0,  0.0, true, true, true),
  ('Thon cuit',             'seed démo (valeurs non vérifiées)', 132, 28.0,  0.0,  1.0,  0.0, true, true, true),
  ('Lentilles cuites',      'seed démo (valeurs non vérifiées)', 116,  9.0, 20.0,  0.4,  7.9, true, true, true),
  ('Pois chiches cuits',    'seed démo (valeurs non vérifiées)', 164,  9.0, 27.0,  2.6,  7.6, true, true, true),
  ('Haricots rouges cuits', 'seed démo (valeurs non vérifiées)', 127,  9.0, 23.0,  0.5,  6.4, true, true, true),
  ('Riz blanc cuit',        'seed démo (valeurs non vérifiées)', 130,  2.7, 28.0,  0.3,  0.4, true, true, true),
  ('Riz complet cuit',      'seed démo (valeurs non vérifiées)', 123,  2.7, 26.0,  1.0,  1.8, true, true, true),
  ('Pâtes cuites',          'seed démo (valeurs non vérifiées)', 158,  6.0, 31.0,  0.9,  1.8, true, true, true),
  ('Flocons d''avoine',     'seed démo (valeurs non vérifiées)', 389, 16.0, 66.0,  7.0, 10.0, true, true, true),
  ('Pain complet',          'seed démo (valeurs non vérifiées)', 247, 13.0, 41.0,  4.2,  7.0, true, true, true),
  ('Pomme de terre cuite',  'seed démo (valeurs non vérifiées)',  87,  2.0, 20.0,  0.1,  2.2, true, true, true),
  ('Brocoli cuit',          'seed démo (valeurs non vérifiées)',  35,  2.4,  7.0,  0.4,  3.3, true, true, true),
  ('Épinards cuits',        'seed démo (valeurs non vérifiées)',  23,  3.0,  3.8,  0.3,  2.4, true, true, true),
  ('Carotte cuite',         'seed démo (valeurs non vérifiées)',  35,  0.8,  8.0,  0.3,  3.0, true, true, true),
  ('Tomate crue',           'seed démo (valeurs non vérifiées)',  18,  0.9,  3.9,  0.2,  1.2, true, true, true),
  ('Huile d''olive',        'seed démo (valeurs non vérifiées)', 884,  0.0,  0.0,100.0,  0.0, true, true, true),
  ('Amande',                'seed démo (valeurs non vérifiées)', 579, 21.0, 22.0, 50.0, 12.5, true, true, true)
ON CONFLICT (name) DO NOTHING;
