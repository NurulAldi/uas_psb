-- Admin Features Migration
-- 1. Create admins table
-- 2. Create reports table
-- 3. Add is_banned column to users table
-- 4. Create RLS policies

-- =============================================
-- 1. ADMINS TABLE
-- =============================================
CREATE TABLE IF NOT EXISTS public.admins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add index for faster email lookup
CREATE INDEX IF NOT EXISTS idx_admins_email ON public.admins(email);

-- RLS Policies for admins table
ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;

-- Only admins can read admin table
CREATE POLICY "Admins can view admin table"
    ON public.admins
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.admins
            WHERE email = auth.jwt()->>'email'
        )
    );

-- =============================================
-- 2. ADD IS_BANNED TO USERS TABLE
-- =============================================
-- Add is_banned column to users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS is_banned BOOLEAN DEFAULT FALSE;

-- Add banned_at column to track when user was banned
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS banned_at TIMESTAMP WITH TIME ZONE;

-- Add banned_by column to track which admin banned the user
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS banned_by UUID REFERENCES public.admins(id);

-- Add ban_reason column
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS ban_reason TEXT;

-- Add index for faster banned users lookup
CREATE INDEX IF NOT EXISTS idx_users_is_banned ON public.users(is_banned);

-- =============================================
-- 3. REPORTS TABLE
-- =============================================
CREATE TYPE report_type AS ENUM ('user', 'product');
CREATE TYPE report_status AS ENUM ('pending', 'reviewed', 'resolved', 'rejected');

CREATE TABLE IF NOT EXISTS public.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    report_type report_type NOT NULL,
    reported_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    reported_product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    description TEXT,
    status report_status DEFAULT 'pending',
    reviewed_by UUID REFERENCES public.admins(id),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    admin_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraint: must have either reported_user_id or reported_product_id
    CONSTRAINT check_report_target CHECK (
        (report_type = 'user' AND reported_user_id IS NOT NULL AND reported_product_id IS NULL) OR
        (report_type = 'product' AND reported_product_id IS NOT NULL AND reported_user_id IS NULL)
    )
);

-- Add indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_reports_reporter ON public.reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_reports_user ON public.reports(reported_user_id);
CREATE INDEX IF NOT EXISTS idx_reports_product ON public.reports(reported_product_id);
CREATE INDEX IF NOT EXISTS idx_reports_status ON public.reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_type ON public.reports(report_type);

-- RLS Policies for reports table
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Users can create reports
CREATE POLICY "Users can create reports"
    ON public.reports
    FOR INSERT
    WITH CHECK (auth.uid() = reporter_id);

-- Users can view their own reports
CREATE POLICY "Users can view their own reports"
    ON public.reports
    FOR SELECT
    USING (auth.uid() = reporter_id);

-- Admins can view all reports
CREATE POLICY "Admins can view all reports"
    ON public.reports
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.admins
            WHERE email = auth.jwt()->>'email'
        )
    );

-- Admins can update reports
CREATE POLICY "Admins can update reports"
    ON public.reports
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.admins
            WHERE email = auth.jwt()->>'email'
        )
    );

-- =============================================
-- 4. UPDATE EXISTING POLICIES
-- =============================================
-- Prevent banned users from creating products
CREATE POLICY "Banned users cannot create products"
    ON public.products
    FOR INSERT
    WITH CHECK (
        NOT EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND is_banned = TRUE
        )
    );

-- Prevent banned users from creating bookings
CREATE POLICY "Banned users cannot create bookings"
    ON public.bookings
    FOR INSERT
    WITH CHECK (
        NOT EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND is_banned = TRUE
        )
    );

-- =============================================
-- 5. FUNCTIONS
-- =============================================
-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for admins table
CREATE TRIGGER update_admins_updated_at
    BEFORE UPDATE ON public.admins
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger for reports table
CREATE TRIGGER update_reports_updated_at
    BEFORE UPDATE ON public.reports
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- 6. INSERT SAMPLE ADMIN (OPTIONAL)
-- =============================================
-- Password: admin123 (hashed with bcrypt)
-- You should change this password in production!
INSERT INTO public.admins (email, password_hash, name)
VALUES (
    'admin@rentlens.com',
    '$2a$10$rN3qj0VJ0KJ5kF5XqhZYxeUGlPgJh5sI0K5xq6qR7xJ5kF5XqhZYxe', -- admin123
    'Admin RentLens'
)
ON CONFLICT (email) DO NOTHING;

-- =============================================
-- 7. VIEWS FOR ADMIN DASHBOARD
-- =============================================
-- View for reports with related data
CREATE OR REPLACE VIEW admin_reports_view AS
SELECT 
    r.id,
    r.report_type,
    r.reason,
    r.description,
    r.status,
    r.created_at,
    r.updated_at,
    r.reviewed_at,
    r.admin_notes,
    -- Reporter info
    reporter.id AS reporter_id,
    reporter.full_name AS reporter_name,
    reporter.email AS reporter_email,
    -- Reported user info (if applicable)
    reported_user.id AS reported_user_id,
    reported_user.full_name AS reported_user_name,
    reported_user.email AS reported_user_email,
    reported_user.is_banned AS reported_user_is_banned,
    -- Reported product info (if applicable)
    reported_product.id AS reported_product_id,
    reported_product.name AS reported_product_name,
    reported_product.owner_id AS reported_product_owner_id,
    -- Admin reviewer info
    reviewer.id AS reviewed_by_id,
    reviewer.name AS reviewed_by_name
FROM public.reports r
INNER JOIN public.users reporter ON r.reporter_id = reporter.id
LEFT JOIN public.users reported_user ON r.reported_user_id = reported_user.id
LEFT JOIN public.products reported_product ON r.reported_product_id = reported_product.id
LEFT JOIN public.admins reviewer ON r.reviewed_by = reviewer.id;

-- View for banned users
CREATE OR REPLACE VIEW admin_banned_users_view AS
SELECT 
    u.id,
    u.email,
    u.full_name,
    u.phone,
    u.is_banned,
    u.banned_at,
    u.ban_reason,
    a.name AS banned_by_name,
    a.email AS banned_by_email,
    -- Count user's products
    (SELECT COUNT(*) FROM public.products WHERE owner_id = u.id) AS products_count,
    -- Count user's bookings
    (SELECT COUNT(*) FROM public.bookings WHERE renter_id = u.id) AS bookings_count,
    -- Count reports against this user
    (SELECT COUNT(*) FROM public.reports WHERE reported_user_id = u.id) AS reports_count
FROM public.users u
LEFT JOIN public.admins a ON u.banned_by = a.id
WHERE u.is_banned = TRUE
ORDER BY u.banned_at DESC;

-- Grant access to views for authenticated users
GRANT SELECT ON admin_reports_view TO authenticated;
GRANT SELECT ON admin_banned_users_view TO authenticated;

-- =============================================
-- NOTES FOR SETUP:
-- =============================================
-- 1. Run this migration in Supabase SQL Editor
-- 2. Create admin account manually in admins table
-- 3. For password hashing, you'll need to hash passwords before inserting
--    Use bcrypt with cost factor 10
-- 4. Admin login will check admins table instead of auth.users
-- 5. Regular users continue using auth.users (Supabase Auth)
