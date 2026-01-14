//+------------------------------------------------------------------+
//| TF_RuleEngine.mqh                                                |
//| Trading policy enforcement and rule checking                     |
//+------------------------------------------------------------------+
#property strict

#include "TF_TradeTiming.mqh"

//+------------------------------------------------------------------+
//| Check if trading is allowed based on all rules                   |
//+------------------------------------------------------------------+
bool RuleEngine_CanTrade(string sym, int slPips, int tpPips, datetime dayStart, datetime weekStart, 
                         bool manualLock, datetime cooldownUntil, string cooldownReason,
                         string &reasonOut)
{
   // Manual lock
   if(manualLock)
   {
      reasonOut = "LOCKED (manual lock)";
      return false;
   }
   
   // Cooldown check
   if(TimeCurrent() < cooldownUntil)
   {
      reasonOut = "COOLDOWN: " + cooldownReason;
      return false;
   }

   // Spread absolute limit (points)
   int maxSpreadPoints = Config_GetMaxSpreadPoints();
   if(maxSpreadPoints > 0)
   {
      int spreadPts = (int)MarketInfo(sym, MODE_SPREAD);
      if(spreadPts > maxSpreadPoints)
      {
         reasonOut = "Blocked: spread " + IntegerToString(spreadPts) + " pts > " + 
                     IntegerToString(maxSpreadPoints) + " pts";
         return false;
      }
   }

   // Daily closed P/L lock (percentage-based, using balance)
   double dailyMaxLossPct = Config_GetDailyMaxLossPct();
   double plToday = TradeStats_ClosedPLSince(dayStart);
   
   if(dailyMaxLossPct > 0)
   {
      double balance = AccountBalance();
      double maxLossMoney = balance * (dailyMaxLossPct / 100.0);
      
      if(plToday <= -maxLossMoney)
      {
         reasonOut = "Blocked: daily loss " + DoubleToString(-plToday, 2) + " >= " + 
                     DoubleToString(dailyMaxLossPct, 1) + "% (" + 
                     DoubleToString(maxLossMoney, 2) + " " + AccountCurrency() + ")";
         return false;
      }
   }

   // Trade count limits (CLOSED trades)
   int maxPerDay = Config_GetMaxTradesPerDay();
   int closedToday = TradeStats_TradesClosedSince(dayStart);
   if(maxPerDay > 0 && closedToday >= maxPerDay)
   {
      reasonOut = "Blocked: max CLOSED trades/day hit (" + IntegerToString(closedToday) + ")";
      return false;
   }

   int maxPerWeek = Config_GetMaxTradesPerWeek();
   int closedWeek = TradeStats_TradesClosedSince(weekStart);
   if(maxPerWeek > 0 && closedWeek >= maxPerWeek)
   {
      reasonOut = "Blocked: max CLOSED trades/week hit (" + IntegerToString(closedWeek) + ")";
      return false;
   }

   // Loss streak lock
   int maxLosses = Config_GetMaxConsecutiveLosses();
   int streak = TradeStats_LossStreakToday(dayStart);
   if(maxLosses > 0 && streak >= maxLosses)
   {
      reasonOut = "Blocked: loss streak today (" + IntegerToString(streak) + ")";
      return false;
   }

   // Multiple positions check
   if(!Config_AllowMultiplePositions() && TradeStats_HasOpenPositionOnSymbol(sym))
   {
      reasonOut = "Blocked: position already open on " + sym;
      return false;
   }

   // Spread % of SL filter
   int spreadPipsNow = RiskCalc_SpreadPips(sym);
   double maxSpreadPct = Config_GetMaxSpreadPctOfSL();
   if(maxSpreadPct > 0.0 && slPips > 0)
   {
      double pct = 100.0 * (double)spreadPipsNow / (double)slPips;
      if(pct > maxSpreadPct)
      {
         reasonOut = "Blocked: spread too large vs SL. Spread=" + IntegerToString(spreadPipsNow) +
                     " pips (" + DoubleToString(pct,1) + "% of SL), max " +
                     DoubleToString(maxSpreadPct,1) + "%.";
         return false;
      }
   }

   // SL must exceed spread
   int slToPricePips = slPips - spreadPipsNow;
   if(slToPricePips <= 0)
   {
      reasonOut = "Blocked: SL (total) must be > spread. SL=" + IntegerToString(slPips) +
                  " pips, spread=" + IntegerToString(spreadPipsNow) + " pips.";
      return false;
   }

   // Require TP
   if(Config_GetRequireTP() && tpPips <= 0)
   {
      reasonOut = "Blocked: TP is required (set TP > 0)";
      return false;
   }

   // Minimum reward:risk ratio
   double minRR = Config_GetMinimumRR();
   if(minRR > 0.0 && tpPips > 0)
   {
      double rr = (double)tpPips / (double)slPips;
      if(rr < minRR)
      {
         reasonOut = "Blocked: R:R too low (" + DoubleToString(rr, 2) +
                     " < " + DoubleToString(minRR, 2) + ")";
         return false;
      }
   }

   // Minimum minutes between trades
   string timingReason = "";
   if(!TradeTiming_CanTradeNow(Config_GetMinMinutesBetweenTrades(), timingReason))
   {
      reasonOut = timingReason;
      return false;
   }
   
   // One instrument at a time restriction
   if(Config_OneInstrumentAtATime())
   {
      if(TradeStats_HasOpenPositionOnOtherSymbol(sym))
      {
         reasonOut = "Blocked: position open on another instrument (One-at-a-time mode)";
         return false;
      }
   }

   reasonOut = "OK";
   return true;
}
//+------------------------------------------------------------------+
