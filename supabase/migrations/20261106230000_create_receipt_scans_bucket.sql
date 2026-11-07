-- Migration: Create private receipt_scans storage bucket with strict RLS and MIME/size constraints

-- 1. Create private bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'receipt_scans',
    'receipt_scans',
    false,
    2097152, -- 2MB
    ARRAY['image/jpeg', 'image/jpg', 'image/png']
)
ON CONFLICT (id) DO UPDATE SET
    public = false,
    file_size_limit = 2097152,
    allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png'];

-- 2. Storage RLS Policies
DROP POLICY IF EXISTS "Users can upload their own receipt scans" ON storage.objects;
CREATE POLICY "Users can upload their own receipt scans"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'receipt_scans' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

DROP POLICY IF EXISTS "Users can view their own receipt scans" ON storage.objects;
CREATE POLICY "Users can view their own receipt scans"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'receipt_scans' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

DROP POLICY IF EXISTS "Users can delete their own receipt scans" ON storage.objects;
CREATE POLICY "Users can delete their own receipt scans"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'receipt_scans' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

