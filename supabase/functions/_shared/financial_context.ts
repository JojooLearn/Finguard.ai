// supabase/functions/_shared/financial_context.ts

export interface AccountItem {
  id: string;
  name: string;
  type: string; // 'cash', 'bank', 'e_wallet', 'savings', 'investment'
  openingBalance: number;
  currentBalance: number;
  isDefault: boolean;
}

export interface TransactionItem {
  id: string;
  amount: number;
  type: string; // 'income', 'expense'
  category: string;
  allocationType: string; // 'needs', 'wants', 'savings', 'other'
  accountName: string;
  note: string;
  date: string; // YYYY-MM-DD
  createdAt: string;
}

export interface GoalItem {
  id: string;
  name: string;
  description: string;
  goalType: string; // 'emergency_fund', 'savings', 'debt_repayment', 'completed', 'other'
  target: number;
  current: number;
  remaining: number;
  targetDate: string;
  priority: number;
  status: string; // 'active', 'completed', 'paused'
  progressPercent: number;
}

export interface GoalContributionItem {
  id: string;
  goalName: string;
  amount: number;
  date: string;
  note: string;
}

export interface DebtContextItem {
  id: string;
  name: string;
  monthlyPayment: number;
  remainingTenor: number;
  totalTenor: number;
  remainingAmount: number;
  dueDay: number;
  annualInterestRate: number;
  appliedInterestAmount: number;
  appliedYears: number;
  startDate: string;
  isCompleted: boolean;
}

export interface MonthlyReviewSnapshot {
  periodStart: string;
  periodEnd: string;
  status: string;
  narrative: string;
  metrics: Record<string, any>;
}

export interface StockSignalItem {
  id: string;
  ticker: string;
  companyName: string;
  signalType: string;
  priceAtSignal: number;
  lotPrice: number; // 1 lot = 100 shares
  timeframe: string;
  reason: string;
  technicalSummary: string;
  rsi: number | null;
  macdStatus: string | null;
  maTrend: string | null;
  confidenceScore: number | null;
  validUntil: string;
  createdAt: string;
  isValid: boolean;
}

export interface UserPreferencesSnapshot {
  dailyReminder: boolean;
  budgetAlert: boolean;
  monthlyReport: boolean;
  reminderTime: string;
  budgetAlertThreshold: number;
  darkModeEnabled: boolean;
  biometricEnabled: boolean;
  currencySymbol: string;
}

export interface UserFinancialContext {
  displayName: string;
  monthlyIncome: number;
  incomeFrequency: string;
  dependentsCount: number;
  essentialExpenses: number;
  monthlyDebt: number;
  initialEmergencyFund: number;
  primaryGoalSummary: string;
  riskProfile: string;
  strictnessLevel: number;
  availableCash: number;
  availableFreeCash: number;
  monthlySavingsContributions: number;
  unpaidMonthlyDebt: number;
  hasVerifiedIncome: boolean;
  accounts: AccountItem[];
  activeBudgets: Array<{
    category: string;
    categoryId: string;
    allocationType: string;
    limit: number;
    spent: number;
    todaySpent: number;
    yesterdaySpent: number;
    remaining: number;
  }>;
  goals: GoalItem[];
  debts: DebtContextItem[];
  goalContributions: GoalContributionItem[];
  latestMonthlyReview: MonthlyReviewSnapshot | null;
  preferences: UserPreferencesSnapshot | null;
  recentTransactions: TransactionItem[];
  stockSignals: StockSignalItem[];
  todayStr: string;
  yesterdayStr: string;
  todayExpenses: number;
  yesterdayExpenses: number;
  todayIncome: number;
  yesterdayIncome: number;
  todayFoodExpense: number;
  yesterdayFoodExpense: number;
  todayTransactions: TransactionItem[];
  yesterdayTransactions: TransactionItem[];
  needsExpenseThisMonth: number;
  wantsExpenseThisMonth: number;
  savingsDebtExpenseThisMonth: number;
  monthlyTotalIncome: number;
  monthlyTotalExpense: number;
  monthlyNetCashFlow: number;
  currentDayOfMonth: number;
  daysInMonth: number;
  dailyAverageExpense: number;
}

function isNeedsCategory(allocationType: string, categoryName: string): boolean {
  const alloc = allocationType.trim().toLowerCase();
  if (alloc === "needs") return true;
  if (alloc === "wants" || alloc === "savings" || alloc === "savings_debt") return false;
  return /makan|minum|food|transport|bensin|ojol|tagihan|utilitas|listrik|air|sewa|kos|kesehatan|sehat|pokok/i.test(
    categoryName,
  );
}

export async function getUserFinancialContext(supabaseClient: any, userId: string, clientDate?: string): Promise<UserFinancialContext> {
  let todayStr: string;
  let yesterdayStr: string;
  let currentYear: number;
  let currentMonth: number;
  let currentDayOfMonth: number;

  if (clientDate && /^\d{4}-\d{2}-\d{2}$/.test(clientDate)) {
    todayStr = clientDate;
    const [y, m, d] = clientDate.split("-").map(Number);
    currentYear = y;
    currentMonth = m;
    currentDayOfMonth = d;
    const dt = new Date(Date.UTC(y, m - 1, d));
    const yesterdayDt = new Date(dt.getTime() - 24 * 60 * 60 * 1000);
    yesterdayStr = yesterdayDt.toISOString().split("T")[0];
  } else {
    const now = new Date();
    // WIB offset (UTC+7) to match Indonesian local time
    const wibTime = new Date(now.getTime() + 7 * 60 * 60 * 1000);
    todayStr = wibTime.toISOString().split("T")[0];
    const yesterdayTime = new Date(wibTime.getTime() - 24 * 60 * 60 * 1000);
    yesterdayStr = yesterdayTime.toISOString().split("T")[0];
    currentYear = wibTime.getFullYear();
    currentMonth = wibTime.getMonth() + 1;
    currentDayOfMonth = wibTime.getDate();
  }

  const currentMonthStart = `${currentYear}-${String(currentMonth).padStart(2, "0")}-01`;
  const nextMonthDate = new Date(currentYear, currentMonth, 0);
  const daysInMonth = nextMonthDate.getDate();
  const currentMonthEnd = `${currentYear}-${String(currentMonth).padStart(2, "0")}-${String(daysInMonth).padStart(2, "0")}`;

  // Start query at least 35 days ago so yesterday and recent history are always captured
  const refTime = new Date(Date.UTC(currentYear, currentMonth - 1, currentDayOfMonth));
  const thirtyFiveDaysAgo = new Date(refTime.getTime() - 35 * 24 * 60 * 60 * 1000).toISOString().split("T")[0];
  const fetchStartDate = thirtyFiveDaysAgo < currentMonthStart ? thirtyFiveDaysAgo : currentMonthStart;

  // Resilient multi-table database queries across all tables in Supabase schema
  const [
    profileRes,
    financialProfileRes,
    accountsRes,
    budgetsRes,
    goalsRes,
    contributionsRes,
    monthlyReviewRes,
    transactionsRes,
    stockSignalsRes,
    preferencesRes,
  ] = await Promise.all([
    // 1. Profiles (display_name, locale, currency_code)
    supabaseClient.from("profiles").select("*").eq("id", userId).maybeSingle(),
    // 2. Financial profiles (income, essentials, debt, emergency fund, strictness, risk profile)
    supabaseClient.from("financial_profiles").select("*").eq("user_id", userId).maybeSingle(),
    // 3. Accounts (cash, bank, e_wallet, savings, investment)
    supabaseClient
      .from("accounts")
      .select("*")
      .eq("user_id", userId)
      .eq("is_archived", false),
    // 4. Budgets (amount/limit, period, category link)
    supabaseClient
      .from("budgets")
      .select("*, categories(*)")
      .eq("user_id", userId),
    // 5. Financial goals (target_amount, current_amount, is_achieved)
    supabaseClient
      .from("financial_goals")
      .select("*")
      .eq("user_id", userId),
    // 6. Goal contributions (savings ledger)
    supabaseClient
      .from("goal_contributions")
      .select("*, financial_goals(name)")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(50),
    // 7. Monthly reviews (evaluations, achievements, challenges)
    supabaseClient
      .from("monthly_reviews")
      .select("*")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle(),
    // 8. Transactions (income, expense, transfer, amount, date, description/note)
    supabaseClient
      .from("transactions")
      .select("*, accounts(name), categories(*)")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(200),
    // 9. Stock signals (technical alerts, watchlist, RSI, MA, confidence)
    supabaseClient
      .from("stock_signals")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(20),
    // 10. User preferences (reminder, alerts, dark mode, currency)
    supabaseClient
      .from("user_preferences")
      .select("*")
      .eq("user_id", userId)
      .maybeSingle(),
  ]);

  const fp = financialProfileRes.data || {};
  const monthlyIncome = fp.monthly_income != null ? Number(fp.monthly_income) : 0;
  const hasVerifiedIncome = fp.monthly_income != null && monthlyIncome > 0;

  // Account balances initialization
  const accountBalances: Record<string, number> = {};
  const accounts: AccountItem[] = (accountsRes.data || []).map((acc: any) => {
    const ob = Number(acc.opening_balance || 0);
    accountBalances[acc.id] = ob;
    return {
      id: acc.id,
      name: acc.name,
      type: acc.account_type || "cash",
      openingBalance: ob,
      currentBalance: ob,
      isDefault: acc.is_default === true,
    };
  });

  const defaultAccount = accounts.find((a) => a.isDefault) || accounts[0];

  // Calculate monthly transactions total & spending per category
  let monthlyTotalIncome = 0;
  let monthlyTotalExpense = 0;
  const categorySpentMap: Record<string, number> = {};
  const categoryTodaySpentMap: Record<string, number> = {};
  const categoryYesterdaySpentMap: Record<string, number> = {};

  const recentTransactions: TransactionItem[] = [];
  const todayTransactions: TransactionItem[] = [];
  const yesterdayTransactions: TransactionItem[] = [];

  let todayExpenses = 0;
  let yesterdayExpenses = 0;
  let todayIncome = 0;
  let yesterdayIncome = 0;
  let todayFoodExpense = 0;
  let yesterdayFoodExpense = 0;

  let needsExpenseThisMonth = 0;
  let wantsExpenseThisMonth = 0;
  let savingsDebtExpenseThisMonth = 0;

  for (const t of transactionsRes.data || []) {
    // Check soft delete & skip pending/unconfirmed drafts
    if (t.deleted_at != null) continue;
    if (t.status != null && t.status !== "confirmed") continue;

    const amt = Number(t.amount || 0);
    const dateStr = t.date ? String(t.date).split("T")[0] : (t.transaction_date ? String(t.transaction_date).split("T")[0] : (t.created_at ? String(t.created_at).split("T")[0] : ""));
    const catName = t.categories?.name || "Umum";
    const allocType = t.categories?.budget_group || t.categories?.allocation_type || "other";
    const accName = t.accounts?.name || defaultAccount?.name || "Dompet Utama";
    const note = t.description || t.note || "";
    const isFood = /makan|minum|food|kuliner|resto|warung|cafe|kopi/i.test(`${catName} ${note}`);
    const txType = t.transaction_type || "expense";

    // Update account balances
    const targetAccId = t.account_id || defaultAccount?.id;
    if (targetAccId && accountBalances[targetAccId] !== undefined) {
      if (txType === "income") {
        accountBalances[targetAccId] += amt;
      } else if (txType === "expense") {
        accountBalances[targetAccId] -= amt;
      }
    }

    const item: TransactionItem = {
      id: t.id,
      amount: amt,
      type: txType,
      category: catName,
      allocationType: allocType,
      accountName: accName,
      note: note,
      date: dateStr,
      createdAt: t.created_at || "",
    };

    recentTransactions.push(item);

    // Monthly totals (strictly current month)
    if (dateStr >= currentMonthStart && dateStr <= currentMonthEnd) {
      if (txType === "income") {
        monthlyTotalIncome += amt;
      } else if (txType === "expense") {
        monthlyTotalExpense += amt;
        if (t.category_id) {
          categorySpentMap[t.category_id] = (categorySpentMap[t.category_id] || 0) + amt;
        }

        if (allocType === "needs") needsExpenseThisMonth += amt;
        else if (allocType === "wants") wantsExpenseThisMonth += amt;
        else if (allocType === "savings" || allocType === "savings_debt") savingsDebtExpenseThisMonth += amt;
      }
    }

    // Today calculations
    if (dateStr === todayStr) {
      todayTransactions.push(item);
      if (txType === "expense") {
        todayExpenses += amt;
        if (t.category_id) {
          categoryTodaySpentMap[t.category_id] = (categoryTodaySpentMap[t.category_id] || 0) + amt;
        }
        if (isFood) {
          todayFoodExpense += amt;
        }
      } else if (txType === "income") {
        todayIncome += amt;
      }
    }

    // Yesterday calculations
    if (dateStr === yesterdayStr) {
      yesterdayTransactions.push(item);
      if (txType === "expense") {
        yesterdayExpenses += amt;
        if (t.category_id) {
          categoryYesterdaySpentMap[t.category_id] = (categoryYesterdaySpentMap[t.category_id] || 0) + amt;
        }
        if (isFood) {
          yesterdayFoodExpense += amt;
        }
      } else if (txType === "income") {
        yesterdayIncome += amt;
      }
    }
  }

  // Update currentBalance for each account
  for (const acc of accounts) {
    acc.currentBalance = Math.max(0, accountBalances[acc.id] ?? acc.openingBalance);
  }

  // Total opening balances across active accounts
  const totalOpeningBalance = accounts.reduce((acc: number, item: any) => acc + item.openingBalance, 0);

  // Avoid double-counting opening balance if it was seeded with the same monthly income transaction
  let actualLiquidCash = monthlyTotalIncome - monthlyTotalExpense;
  if (totalOpeningBalance > monthlyTotalIncome) {
    actualLiquidCash += (totalOpeningBalance - monthlyTotalIncome);
  }
  if (actualLiquidCash < 0) actualLiquidCash = 0;

  const budgets = (budgetsRes.data || [])
    .filter((b: any) => {
      if (!b.period_start || !b.period_end) return true;
      const start = String(b.period_start).split("T")[0];
      const end = String(b.period_end).split("T")[0];
      return start <= currentMonthEnd && end >= currentMonthStart;
    })
    .map((b: any) => {
      const limit = Number(b.amount ?? b.limit_amount ?? 0);
      const spent = categorySpentMap[b.category_id] || 0;
      const catName = b.categories?.name || "Kategori";
      const allocType = b.categories?.budget_group || b.categories?.allocation_type || "other";
      return {
        category: catName,
        categoryId: b.category_id,
        allocationType: allocType,
        limit,
        spent,
        todaySpent: categoryTodaySpentMap[b.category_id] || 0,
        yesterdaySpent: categoryYesterdaySpentMap[b.category_id] || 0,
        remaining: Math.max(0, limit - spent),
      };
    });

  const goals: GoalItem[] = [];
  const debts: DebtContextItem[] = [];

  for (const g of (goalsRes.data || [])) {
    if (g.goal_type === "debt_repayment") {
      let monthly = 0;
      let remaining = 1;
      let total = 1;
      let due = 10;
      let annualRate = 0;
      let appliedInterest = 0;
      let appliedYears = 0;
      let startDateStr = g.created_at || "";

      if (g.description) {
        try {
          const meta = JSON.parse(g.description);
          if (typeof meta === "object" && meta !== null) {
            monthly = Number(meta.monthly_payment || 0);
            remaining = Number(meta.remaining_tenor ?? 1);
            total = Number(meta.total_tenor ?? 1);
            due = Number(meta.due_day ?? 10);
            annualRate = Number(meta.annual_interest_rate || 0);
            appliedInterest = Number(meta.applied_interest_amount || 0);
            appliedYears = Number(meta.applied_years || 0);
            if (meta.start_date) startDateStr = String(meta.start_date);
          }
        } catch (_) {}
      }

      if (monthly === 0 && total > 0) {
        monthly = Number(g.target_amount || 0) / total;
      }

      const remPrincipal = remaining * monthly;
      const totalRemaining = remPrincipal + appliedInterest;
      const isDone = g.status === "completed" || remaining <= 0;

      debts.push({
        id: g.id,
        name: g.name,
        monthlyPayment: monthly,
        remainingTenor: remaining,
        totalTenor: total,
        remainingAmount: totalRemaining,
        dueDay: due,
        annualInterestRate: annualRate,
        appliedInterestAmount: appliedInterest,
        appliedYears,
        startDate: startDateStr,
        isCompleted: isDone,
      });
    } else {
      const target = Number(g.target_amount || 0);
      const current = Number(g.current_amount || 0);
      const isAchieved = g.is_achieved === true || g.status === "completed";
      goals.push({
        id: g.id,
        name: g.name,
        description: g.description || (isAchieved ? "Target tercapai!" : ""),
        goalType: g.goal_type || (isAchieved ? "completed" : "savings"),
        target,
        current,
        remaining: Math.max(0, target - current),
        targetDate: g.target_date || "",
        priority: Number(g.priority || 3),
        status: isAchieved ? "completed" : (g.status || "active"),
        progressPercent: target > 0 ? Math.min(100, Math.round((current / target) * 100)) : 0,
      });
    }
  }

  const goalContributions: GoalContributionItem[] = (contributionsRes.data || []).map((gc: any) => ({
    id: gc.id,
    goalName: gc.financial_goals?.name || "Celengan",
    amount: Number(gc.amount || 0),
    date: gc.contribution_date ? String(gc.contribution_date).split("T")[0] : (gc.created_at ? String(gc.created_at).split("T")[0] : ""),
    note: gc.note || "",
  }));

  const latestMonthlyReview: MonthlyReviewSnapshot | null = monthlyReviewRes.data ? {
    periodStart: monthlyReviewRes.data.year_month || monthlyReviewRes.data.period_start || "",
    periodEnd: monthlyReviewRes.data.year_month || monthlyReviewRes.data.period_end || "",
    status: monthlyReviewRes.data.status || "completed",
    narrative: monthlyReviewRes.data.coach_summary || monthlyReviewRes.data.narrative || "",
    metrics: {
      totalIncome: Number(monthlyReviewRes.data.total_income || 0),
      totalExpense: Number(monthlyReviewRes.data.total_expense || 0),
      totalSavings: Number(monthlyReviewRes.data.total_savings || 0),
      achievements: monthlyReviewRes.data.achievements || [],
      challenges: monthlyReviewRes.data.challenges || [],
      actionableSteps: monthlyReviewRes.data.actionable_steps || [],
      ...(monthlyReviewRes.data.metrics_snapshot || {}),
    },
  } : null;

  const nowTime = new Date().getTime();
  const stockSignals: StockSignalItem[] = (stockSignalsRes.data || []).map((s: any) => {
    const validUntilDate = s.valid_until ? new Date(s.valid_until) : null;
    const isValid = validUntilDate ? validUntilDate.getTime() > nowTime : true;
    const price = Number(s.price_at_signal || 0);
    const reasonText = s.reason || s.analysis_notes || s.technical_summary || "Terpilih dalam pantauan teknikal FinGuard";
    return {
      id: s.id,
      ticker: s.ticker,
      companyName: s.company_name || s.ticker,
      signalType: s.signal_type,
      priceAtSignal: price,
      lotPrice: price * 100, // 1 lot = 100 shares di BEI / IDX
      timeframe: s.timeframe || "1D",
      reason: reasonText,
      technicalSummary: s.technical_summary || reasonText,
      rsi: s.rsi != null ? Number(s.rsi) : null,
      macdStatus: s.macd_status || null,
      maTrend: s.ma_trend || null,
      confidenceScore: s.confidence_score != null ? Number(s.confidence_score) : null,
      validUntil: s.valid_until || "",
      createdAt: s.created_at || "",
      isValid,
    };
  });

  const up = preferencesRes.data;
  const preferences: UserPreferencesSnapshot | null = up ? {
    dailyReminder: up.notification_daily_reminder ?? true,
    budgetAlert: up.notification_budget_alert ?? true,
    monthlyReport: up.notification_monthly_report ?? true,
    reminderTime: up.reminder_time ? String(up.reminder_time).substring(0, 5) : "20:00",
    budgetAlertThreshold: Number(up.budget_alert_threshold || 80),
    darkModeEnabled: up.dark_mode_enabled ?? false,
    biometricEnabled: up.biometric_enabled ?? false,
    currencySymbol: up.currency_symbol || "Rp",
  } : null;

  const elapsedDays = Math.max(1, currentDayOfMonth);
  const dailyAverageExpense = monthlyTotalExpense / elapsedDays;
  const monthlyNetCashFlow = monthlyTotalIncome - monthlyTotalExpense;

  // Prioritaskan pemasukan transaksi aktual bulan ini; fallback ke profil jika belum ada transaksi masuk.
  const effectiveIncome = monthlyTotalIncome > 0 ? monthlyTotalIncome : monthlyIncome;
  const effectiveHasVerifiedIncome = hasVerifiedIncome || effectiveIncome > 0;

  // Pisahkan pembayaran cicilan dari kebutuhan pokok & keinginan agar tidak terhitung ganda
  // maupun tertelan oleh cadangan jatah kebutuhan pokok bulanan.
  const debtNamesLower = debts.map((d) => d.name.toLowerCase()).filter(Boolean);
  let paidDebtTxExpense = 0;
  let nonDebtNeedsExpense = 0;
  let nonDebtOtherExpense = 0;

  for (const tx of recentTransactions) {
    if (tx.type !== "expense" || tx.date < currentMonthStart || tx.date > currentMonthEnd) {
      continue;
    }
    const noteLower = tx.note.toLowerCase();
    const isPaidDebtTx = debtNamesLower.some((dName) => noteLower.includes(`bayar ${dName}`));
    if (isPaidDebtTx) {
      paidDebtTxExpense += tx.amount;
    } else if (isNeedsCategory(tx.allocationType, tx.category)) {
      nonDebtNeedsExpense += tx.amount;
    } else {
      nonDebtOtherExpense += tx.amount;
    }
  }

  const activeNeedsBudgetTotal = budgets
    .filter((b) => isNeedsCategory(b.allocationType, b.category))
    .reduce((acc, b) => acc + b.limit, 0);
  const monthlyEssentialCommitment =
    activeNeedsBudgetTotal > 0
      ? activeNeedsBudgetTotal
      : Number(fp.essential_monthly_expenses || 0);

  // Cadangkan jatah kebutuhan pokok bulanan penuh agar uang makan/transport/tagihan
  // yang belum terpakai di awal/tengah bulan tidak terbaca sebagai uang dingin.
  const effectiveConsumptionExpense =
    paidDebtTxExpense +
    Math.max(nonDebtNeedsExpense, monthlyEssentialCommitment) +
    nonDebtOtherExpense;

  // Calculate unpaid monthly debt for this month (prevent double counting if already paid via transaction)
  const currentMonthNotes = recentTransactions
    .filter((tx) => tx.type === "expense" && tx.date >= currentMonthStart && tx.date <= currentMonthEnd)
    .map((tx) => tx.note.toLowerCase());

  const activeDebtsList = debts.filter((d) => !d.isCompleted && d.remainingTenor > 0);
  let unpaidMonthlyDebt = 0;
  if (activeDebtsList.length > 0) {
    for (const d of activeDebtsList) {
      const paidThisMonth = currentMonthNotes.some((n) => n.includes(`bayar ${d.name.toLowerCase()}`));
      if (!paidThisMonth) {
        unpaidMonthlyDebt += d.monthlyPayment;
      }
    }
  } else {
    unpaidMonthlyDebt = debts.length > 0 ? 0 : Number(fp.monthly_debt_payments || 0);
  }

  // Hitung setoran neto tabungan & dana darurat KHUSUS bulan berjalan (tidak memakai total saldo historis bulan lalu).
  const currentMonthContribTotal = goalContributions
    .filter((gc) => gc.date >= currentMonthStart && gc.date <= currentMonthEnd)
    .reduce((acc, gc) => acc + gc.amount, 0);
  const monthlySavingsContributions = Math.max(0, currentMonthContribTotal);

  // Golden Financial Rule:
  // Uang Dingin Siap Pakai = Pemasukan Aktual - Komitmen Kebutuhan Pokok & Konsumsi - Cicilan Belum Dibayar - Setoran Tabungan/Dana Darurat Bulan Ini
  const rawFreeCash = Math.max(
    0,
    effectiveIncome - effectiveConsumptionExpense - unpaidMonthlyDebt - monthlySavingsContributions,
  );
  const hasRealCashTracking =
    monthlyTotalIncome > 0 || monthlyTotalExpense > 0 || totalOpeningBalance > 0;
  const availableFreeCash = hasRealCashTracking
    ? Math.min(rawFreeCash, actualLiquidCash)
    : rawFreeCash;

  return {
    displayName: profileRes.data?.display_name || "Sobat FinGuard",
    monthlyIncome: effectiveIncome,
    incomeFrequency: fp.income_frequency || "monthly",
    dependentsCount: Number(fp.dependents_count || 0),
    essentialExpenses: effectiveConsumptionExpense,
    monthlyDebt: unpaidMonthlyDebt,
    initialEmergencyFund: Math.max(
      Number(fp.current_emergency_fund || 0),
      goals.filter((g) => g.goalType === "emergency_fund").reduce((s, g) => s + g.current, 0),
    ),
    primaryGoalSummary: fp.primary_goal_summary || "",
    riskProfile: fp.risk_profile || "moderate",
    strictnessLevel: Number(fp.strictness_level || 3),
    availableCash: actualLiquidCash,
    availableFreeCash,
    monthlySavingsContributions,
    unpaidMonthlyDebt,
    hasVerifiedIncome: effectiveHasVerifiedIncome,
    accounts,
    activeBudgets: budgets,
    goals,
    debts,
    goalContributions,
    latestMonthlyReview,
    preferences,
    recentTransactions,
    stockSignals,
    todayStr,
    yesterdayStr,
    todayExpenses,
    yesterdayExpenses,
    todayIncome,
    yesterdayIncome,
    todayFoodExpense,
    yesterdayFoodExpense,
    todayTransactions,
    yesterdayTransactions,
    needsExpenseThisMonth,
    wantsExpenseThisMonth,
    savingsDebtExpenseThisMonth,
    monthlyTotalIncome,
    monthlyTotalExpense,
    monthlyNetCashFlow,
    currentDayOfMonth,
    daysInMonth,
    dailyAverageExpense,
  };
}

export {
  fetchOnDemandStockAnalysis,
  formatOnDemandPromptContext,
  normalizeTicker,
  fetchMarketSentimentAndMacroNews,
  fetchIpoStockIntelligence,
} from "./stock_on_demand.ts";
export type { OnDemandStockAnalysis } from "./stock_on_demand.ts";
