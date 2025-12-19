-- Script SQL pour activer Stripe sur tous les projets
-- À exécuter directement avec psql

-- Vérifier si la colonne use_stripe existe
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name='projects' AND column_name='use_stripe'
    ) THEN
        -- Activer Stripe pour tous les projets
        UPDATE projects SET use_stripe = true;
        RAISE NOTICE 'Stripe activé pour % projets', (SELECT COUNT(*) FROM projects);
    ELSE
        RAISE NOTICE 'La colonne use_stripe n''existe pas encore. Exécutez les migrations d''abord.';
    END IF;
END $$;
