//+------------------------------------------------------------------+
//| TF_Config.mqh                                                    |
//| Configuration and input parameters                               |
//+------------------------------------------------------------------+
#property strict

// ===== User rules =====
input double RiskPct                = 1.0;      // Risk per trade (% of equity)
input double DailyMaxLossPct        = 3.0;      // Lock if today's loss >= this % of equity
input int    MaxConsecutiveLosses   = 3;        // Lock if loss streak (today) >= this
input int    MaxTradesPerDay        = 3;        // Limit CLOSED trades today
input int    MaxTradesPerWeek       = 10;       // Limit CLOSED trades this week
input int    MaxSpreadPoints        = 0;        // 0 = ignore; else block if spread > points
input double MaxSpreadPctOfSL       = 0.0;      // 0 = ignore; else block if spread(pips) > % of SL
input int    Slippage               = 5;
input bool   AllowMultiplePositions = true;     // If false, blocks new trade if already open
input bool   OneInstrumentAtATime   = false;    // If true, blocks trading other symbols when position open

// ===== Cooldowns =====
input int    CooldownAfterLoss      = 5;        // Minutes cooldown after losing trade
input int    CooldownAfterWin       = 5;        // Minutes cooldown after winning trade
input double BigWinPct              = 15.0;     // % of account = big win (blocks rest of day)
input double BigLossPct             = 10.0;     // % of account = big loss
input int    CooldownAfterBigLoss   = 60;       // Minutes cooldown after big loss

// ===== ATR Stop Loss Suggestion =====
input int    ATR_Period             = 14;       // ATR period for stop loss suggestion
input double ATR_Multiplier         = 2.0;      // ATR multiplier for stop loss (1.5-3.0)
input int    ATR_TimeframeMinutes   = 0;        // ATR timeframe in minutes (0 = current chart)

// ===== Break Even Settings =====
input bool   ForceBE_Enabled        = false;    // Enable Force Break Even by default
input double BE_TriggerMultiplier   = 2.0;      // Trigger BE when profit = X × SL distance
input double BE_LockMultiplier      = 1.0;      // Lock profit at X × SL distance from entry

// ===== Smart SL Settings =====
input double SmartSL_TriggerMultiplier = 2.0;   // Activate Smart SL when profit = X × SL distance
input double SmartSL_ProfitLockPct     = 60.0;  // Lock this % of profit when Smart SL triggers

// ===== TP & Timing Rules =====
input bool   RequireTP             = true;      // Require TP for every trade
input double MinimumRR             = 1.5;       // Minimum reward:risk ratio (TP/SL)
input int    MinMinutesBetweenTrades = 30;      // Minimum minutes between trades
input bool   BlockRevengeTrading   = true;      // Double cooldown after 2+ consecutive losses

// ===== UX =====
input bool   ShowConfirmPopup       = true;     // Show OK/Cancel confirmation popup
input bool   EnableChecklist        = true;     // Show checklist in confirm popup
input bool   EnableDebugOutput      = false;    // Enable debug messages in Experts log

// ===== Panel defaults =====
input int    DefaultSL_Pips         = 50;       // TOTAL risk pips (includes spread)
input int    DefaultTP_Pips         = 0;        // TP distance pips
input double DefaultTargetPrice     = 0.0;      // 0 = market order; else pending limit

//+------------------------------------------------------------------+
//| Get configuration values (for other modules to access)          |
//+------------------------------------------------------------------+
double Config_GetRiskPct()              { return RiskPct; }
double Config_GetDailyMaxLossPct()      { return DailyMaxLossPct; }
int    Config_GetMaxConsecutiveLosses() { return MaxConsecutiveLosses; }
int    Config_GetMaxTradesPerDay()      { return MaxTradesPerDay; }
int    Config_GetMaxTradesPerWeek()     { return MaxTradesPerWeek; }
int    Config_GetMaxSpreadPoints()      { return MaxSpreadPoints; }
double Config_GetMaxSpreadPctOfSL()     { return MaxSpreadPctOfSL; }
int    Config_GetSlippage()             { return Slippage; }
bool   Config_AllowMultiplePositions()  { return AllowMultiplePositions; }
bool   Config_OneInstrumentAtATime()    { return OneInstrumentAtATime; }
bool   Config_ShowConfirmPopup()        { return ShowConfirmPopup; }
bool   Config_EnableChecklist()         { return EnableChecklist; }
bool   Config_EnableDebugOutput()       { return EnableDebugOutput; }
int    Config_GetDefaultSL()            { return DefaultSL_Pips; }
int    Config_GetDefaultTP()            { return DefaultTP_Pips; }
double Config_GetDefaultTargetPrice()   { return DefaultTargetPrice; }
int    Config_GetCooldownAfterLoss()    { return CooldownAfterLoss; }
int    Config_GetCooldownAfterWin()     { return CooldownAfterWin; }
double Config_GetBigWinPct()            { return BigWinPct; }
double Config_GetBigLossPct()           { return BigLossPct; }
int    Config_GetCooldownAfterBigLoss() { return CooldownAfterBigLoss; }
int    Config_GetATR_Period()           { return ATR_Period; }
double Config_GetATR_Multiplier()       { return ATR_Multiplier; }
int    Config_GetATR_TimeframeMinutes() { return ATR_TimeframeMinutes; }
bool   Config_GetForceBE_Enabled()      { return ForceBE_Enabled; }
double Config_GetBE_TriggerMultiplier() { return BE_TriggerMultiplier; }
double Config_GetBE_LockMultiplier()    { return BE_LockMultiplier; }
double Config_GetSmartSL_TriggerMultiplier() { return SmartSL_TriggerMultiplier; }
double Config_GetSmartSL_ProfitLockPct()     { return SmartSL_ProfitLockPct; }
bool   Config_GetRequireTP()            { return RequireTP; }
double Config_GetMinimumRR()            { return MinimumRR; }
int    Config_GetMinMinutesBetweenTrades() { return MinMinutesBetweenTrades; }
bool   Config_GetBlockRevengeTrading()  { return BlockRevengeTrading; }
//+------------------------------------------------------------------+
