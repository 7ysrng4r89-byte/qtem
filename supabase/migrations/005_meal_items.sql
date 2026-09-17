-- 005_meal_items.sql
-- M0 Fondation — items alimentaires d'un repas (quantité en grammes).

CREATE TABLE IF NOT EXISTS public.meal_items (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meal_id    uuid NOT NULL REFERENCES public.meals(id) ON DELETE CASCADE,
  food_id    uuid NOT NULL REFERENCES public.foods(id) ON DELETE RESTRICT,
  quantity_g numeric(8,2) NOT NULL CHECK (quantity_g > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (meal_id, food_id)
);

COMMENT ON TABLE public.meal_items IS 'Items alimentaires d un repas (quantité en grammes, > 0).';
