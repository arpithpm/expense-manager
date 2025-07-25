-- Supabase Database Schema for Expense Manager
-- Execute this in your Supabase SQL editor

-- Create expenses table
CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date TIMESTAMP WITH TIME ZONE NOT NULL,
    merchant TEXT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    currency TEXT NOT NULL DEFAULT 'USD',
    category TEXT NOT NULL,
    description TEXT,
    payment_method TEXT,
    tax_amount DECIMAL(10,2),
    receipt_image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create categories table for reference
CREATE TABLE IF NOT EXISTS expense_categories (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    icon TEXT,
    color TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert default categories
INSERT INTO expense_categories (name, icon, color) VALUES 
    ('Food & Dining', '🍽️', '#FF6B6B'),
    ('Transportation', '🚗', '#4ECDC4'),
    ('Shopping', '🛍️', '#45B7D1'),
    ('Entertainment', '🎬', '#96CEB4'),
    ('Bills & Utilities', '💡', '#FFEAA7'),
    ('Healthcare', '🏥', '#DDA0DD'),
    ('Travel', '✈️', '#98D8C8'),
    ('Education', '📚', '#F7DC6F'),
    ('Business', '💼', '#BB8FCE'),
    ('Other', '📝', '#A8A8A8')
ON CONFLICT (name) DO NOTHING;

-- Create payment_methods table for reference
CREATE TABLE IF NOT EXISTS payment_methods (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    icon TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert default payment methods
INSERT INTO payment_methods (name, icon) VALUES 
    ('Cash', '💵'),
    ('Credit Card', '💳'),
    ('Debit Card', '💳'),
    ('Digital Payment', '📱'),
    ('Bank Transfer', '🏦'),
    ('Check', '📋'),
    ('Other', '❓')
ON CONFLICT (name) DO NOTHING;

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date);
CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category);
CREATE INDEX IF NOT EXISTS idx_expenses_merchant ON expenses(merchant);
CREATE INDEX IF NOT EXISTS idx_expenses_created_at ON expenses(created_at);

-- Create a function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
DROP TRIGGER IF EXISTS update_expenses_updated_at ON expenses;
CREATE TRIGGER update_expenses_updated_at
    BEFORE UPDATE ON expenses
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security (RLS)
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_methods ENABLE ROW LEVEL SECURITY;

-- Create policies for public access (you may want to restrict this based on authentication)
-- For now, allowing all operations for testing
CREATE POLICY "Allow all operations on expenses" ON expenses
    FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Allow read access to expense_categories" ON expense_categories
    FOR SELECT USING (true);

CREATE POLICY "Allow read access to payment_methods" ON payment_methods
    FOR SELECT USING (true);

-- Create a view for expense summaries
CREATE OR REPLACE VIEW expense_summary AS
SELECT 
    category,
    COUNT(*) as expense_count,
    SUM(amount) as total_amount,
    AVG(amount) as average_amount,
    MIN(date) as earliest_date,
    MAX(date) as latest_date
FROM expenses
GROUP BY category;

-- Create a view for monthly summaries
CREATE OR REPLACE VIEW monthly_expense_summary AS
SELECT 
    DATE_TRUNC('month', date) as month,
    category,
    COUNT(*) as expense_count,
    SUM(amount) as total_amount,
    currency
FROM expenses
GROUP BY DATE_TRUNC('month', date), category, currency
ORDER BY month DESC, category;