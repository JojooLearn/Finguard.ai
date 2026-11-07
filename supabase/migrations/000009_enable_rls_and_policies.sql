-- 000009_enable_rls_and_policies.sql

-- Enable Row Level Security on all user tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financial_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financial_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goal_contributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monthly_reviews ENABLE ROW LEVEL SECURITY;

-- 1. Profiles Policies
CREATE POLICY "Users can view own profile"
ON public.profiles FOR SELECT
USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
ON public.profiles FOR UPDATE
USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
ON public.profiles FOR INSERT
WITH CHECK (auth.uid() = id);

-- 2. Financial Profiles Policies
CREATE POLICY "Users can view own financial profile"
ON public.financial_profiles FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own financial profile"
ON public.financial_profiles FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own financial profile"
ON public.financial_profiles FOR UPDATE
USING (auth.uid() = user_id);

-- 3. Accounts Policies
CREATE POLICY "Users can view own accounts"
ON public.accounts FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own accounts"
ON public.accounts FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own accounts"
ON public.accounts FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own accounts"
ON public.accounts FOR DELETE
USING (auth.uid() = user_id);

-- 4. Categories Policies
CREATE POLICY "Users can view system categories or own categories"
ON public.categories FOR SELECT
USING (is_system = true OR auth.uid() = user_id);

CREATE POLICY "Users can insert own custom categories"
ON public.categories FOR INSERT
WITH CHECK (auth.uid() = user_id AND is_system = false);

CREATE POLICY "Users can update own custom categories"
ON public.categories FOR UPDATE
USING (auth.uid() = user_id AND is_system = false);

CREATE POLICY "Users can delete own custom categories"
ON public.categories FOR DELETE
USING (auth.uid() = user_id AND is_system = false);

-- 5. Transactions Policies
CREATE POLICY "Users can view own transactions"
ON public.transactions FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own transactions"
ON public.transactions FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own transactions"
ON public.transactions FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own transactions"
ON public.transactions FOR DELETE
USING (auth.uid() = user_id);

-- 6. Budgets Policies
CREATE POLICY "Users can view own budgets"
ON public.budgets FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own budgets"
ON public.budgets FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own budgets"
ON public.budgets FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own budgets"
ON public.budgets FOR DELETE
USING (auth.uid() = user_id);

-- 7. Financial Goals Policies
CREATE POLICY "Users can view own goals"
ON public.financial_goals FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own goals"
ON public.financial_goals FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own goals"
ON public.financial_goals FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own goals"
ON public.financial_goals FOR DELETE
USING (auth.uid() = user_id);

-- 8. Goal Contributions Policies
CREATE POLICY "Users can view own goal contributions"
ON public.goal_contributions FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own goal contributions"
ON public.goal_contributions FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own goal contributions"
ON public.goal_contributions FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own goal contributions"
ON public.goal_contributions FOR DELETE
USING (auth.uid() = user_id);

-- 9. Chat Conversations Policies
CREATE POLICY "Users can view own conversations"
ON public.chat_conversations FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own conversations"
ON public.chat_conversations FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own conversations"
ON public.chat_conversations FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own conversations"
ON public.chat_conversations FOR DELETE
USING (auth.uid() = user_id);

-- 10. Chat Messages Policies
CREATE POLICY "Users can view own chat messages"
ON public.chat_messages FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own chat messages"
ON public.chat_messages FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- 11. AI Requests Policies
CREATE POLICY "Users can view own AI requests"
ON public.ai_requests FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own AI requests"
ON public.ai_requests FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own AI requests"
ON public.ai_requests FOR UPDATE
USING (auth.uid() = user_id);

-- 12. Monthly Reviews Policies
CREATE POLICY "Users can view own monthly reviews"
ON public.monthly_reviews FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own monthly reviews"
ON public.monthly_reviews FOR INSERT
WITH CHECK (auth.uid() = user_id);
