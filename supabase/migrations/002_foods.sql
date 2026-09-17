-- 002_foods.sql
-- M0 Fondation — table des aliments (lecture publique).
-- Décision D : source = 'seed démo (valeurs non vérifiées)' (valeurs NON vérifiées Ciqual/ANSES).

CREATE TABLE IF NOT EXISTS public.foods (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text NOT NULL UNIQUE,
  source        text NOT NULL DEFAULT 'seed démo (valeurs non vérifiées)',
  kcal_per_100g numeric(8,2) NOT NULL CHECK (kcal_per_100g >= 0),
  protein_g     numeric(7,2) NOT NULL CHECK (protein_g >= 0),
  carbs_g       numeric(7,2) NOT NULL CHECK (carbs_g >= 0),
  fat_g         numeric(7,2) NOT NULL CHECK (fat_g >= 0),
  fiber_g       numeric(7,2) NOT NULL DEFAULT 0 CHECK (fiber_g >= 0),
  halal         boolean NOT NULL DEFAULT true,
  lactose_free  boolean NOT NULL DEFAULT true,
  dairy_free    boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.foods IS
  'Aliments de référence (lecture publique). Valeurs seed = démonstration NON vérifiées.';
