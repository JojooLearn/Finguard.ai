-- Allow emergency fund / goal withdrawals via signed amounts in goal_contributions
-- while enforcing non-negative goal balances in trg_goal_contributions_update_amount.

ALTER TABLE public.goal_contributions
    DROP CONSTRAINT IF EXISTS goal_contributions_amount_check;

ALTER TABLE public.goal_contributions
    ADD CONSTRAINT goal_contributions_amount_check CHECK (amount <> 0);

CREATE OR REPLACE FUNCTION public.update_goal_current_amount()
RETURNS TRIGGER AS $$
DECLARE
    target_goal_id UUID;
    total_amount NUMERIC(18,2);
    goal_target NUMERIC(18,2);
    goal_type_val TEXT;
    current_status TEXT;
BEGIN
    target_goal_id := COALESCE(NEW.goal_id, OLD.goal_id);
    SELECT GREATEST(COALESCE(SUM(amount), 0.00), 0.00) INTO total_amount
    FROM public.goal_contributions
    WHERE goal_id = target_goal_id;

    SELECT target_amount, goal_type, status
    INTO goal_target, goal_type_val, current_status
    FROM public.financial_goals
    WHERE id = target_goal_id;

    UPDATE public.financial_goals
    SET current_amount = total_amount,
        status = CASE
            WHEN goal_type_val <> 'debt_repayment' AND goal_target IS NOT NULL AND total_amount >= goal_target THEN 'completed'
            WHEN goal_type_val <> 'debt_repayment' AND current_status = 'completed' AND goal_target IS NOT NULL AND total_amount < goal_target THEN 'active'
            ELSE current_status
        END,
        updated_at = now()
    WHERE id = target_goal_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

