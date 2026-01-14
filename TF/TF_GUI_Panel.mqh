//+------------------------------------------------------------------+
//| TF_GUI_Panel.mqh                                                 |
//| Main panel drawing and status updates                            |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Draw main panel                                                  |
//+------------------------------------------------------------------+
void GUI_DrawPanel()
{
   int X = 5, Y = 5;
   int W = 600;  // Panel width
   int H = 365;  // Increased for session gap stats

   GUI_CreatePanelBG("BG", X, Y, W, H);

   GUI_CreateLabel("T", X+10, Y+8,  "Trade Firewall Panel", 10);
   GUI_CreateLabel("R", X+10, Y+28, "Risk: " + DoubleToString(Config_GetRiskPct(),1) + 
                   "% (auto lots; SL includes spread)");

   // Input fields
   GUI_CreateLabel("SL_L", X+10,  Y+52, "SL total (pips):");
   GUI_CreateEdit ("SL",   X+110, Y+48, 50, 18, IntegerToString(Config_GetDefaultSL()));

   GUI_CreateLabel("TP_L", X+195, Y+52, "TP (pips):");
   GUI_CreateEdit ("TP",   X+265, Y+48, 70, 18, IntegerToString(Config_GetDefaultTP()));

   GUI_CreateLabel("PX_L", X+360, Y+52, "Target:");
   GUI_CreateEdit ("PX",   X+415, Y+48, 100, 18, DoubleToString(Config_GetDefaultTargetPrice(), 2));

   // Action buttons - Row 1
   GUI_CreateButton("BUY",  X+10,  Y+78,  85, 28, "BUY");
   GUI_CreateButton("SELL", X+105, Y+78,  85, 28, "SELL");
   GUI_CreateButton("LOCK", X+200, Y+78,  70, 28, "LOCK");
   GUI_CreateButton("KILL", X+280, Y+78,  70, 28, "KILL");
   GUI_CreateButton("POS",  X+360, Y+78,  90, 28, "POSITIONS");
   
   // Set button colors
   ObjectSetInteger(0, GUI_PFX + "KILL", OBJPROP_BGCOLOR, clrDarkRed);
   ObjectSetInteger(0, GUI_PFX + "KILL", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, GUI_PFX + "POS", OBJPROP_BGCOLOR, clrDarkBlue);
   ObjectSetInteger(0, GUI_PFX + "POS", OBJPROP_COLOR, clrWhite);

   // Market info labels
   GUI_CreateLabel("BID_L", X+10,  Y+115, "Bid:");
   GUI_CreateLabel("ASK_L", X+170, Y+115, "Ask:");
   GUI_CreateLabel("SPR_L", X+330, Y+115, "Spread:");

   // Stats labels (removed week labels - redundant)
   GUI_CreateLabel("PL_L",    X+10, Y+140, "P/L today (closed):", 10);
   GUI_CreateLabel("CUMRISK_L", X+10, Y+160, "TOTAL RISK:", 11);  // New cumulative risk display
   GUI_CreateLabel("TD_L",    X+10, Y+180, "Closed trades:", 10);
   GUI_CreateLabel("LOCK_L",  X+10, Y+200, "LOCK:", 10);

   // Remaining budget labels
   GUI_CreateLabel("REMLOSS_L", X+10, Y+225, "Daily loss remaining:", 10);
   GUI_CreateLabel("REM_TD_L",  X+10, Y+245, "Trades remaining:", 10);

   // Misc info (will be updated with combined info)
   GUI_CreateLabel("MISC_L",  X+10, Y+270, "...", 9);
   
   // Time tracking display
   GUI_CreateLabel("TIME_L", X+10, Y+290, "Screen time:", 9);
   GUI_CreateLabel("GAP_TBS", X+10, Y+305, "TBS:", 8);
   GUI_CreateLabel("GAP_SESS", X+305, Y+305, "Sessions:", 8);
}

//+------------------------------------------------------------------+
//| Update panel status                                              |
//+------------------------------------------------------------------+
void GUI_UpdateStatus(datetime dayStart, datetime weekStart, bool manualLock,
                      datetime cooldownUntil, string cooldownReason)
{
   // Check for day/week reset
   if(TimeUtils_IsNewDay(dayStart) || TimeUtils_IsNewWeek(weekStart))
   {
      TimeUtils_ResetDayWeek(dayStart, weekStart);
   }

   string sym = Symbol();
   int digits = (int)MarketInfo(sym, MODE_DIGITS);

   RefreshRates();
   double bid = Bid;
   double ask = Ask;

   int spreadPts  = (int)MarketInfo(sym, MODE_SPREAD);
   int spreadPips = RiskCalc_SpreadPips(sym);

   double plToday = TradeStats_ClosedPLSince(dayStart);
   int closedToday = TradeStats_TradesClosedSince(dayStart);
   int closedWeek  = TradeStats_TradesClosedSince(weekStart);
   int streak      = TradeStats_LossStreakToday(dayStart);
   
   string lockTxt = manualLock ? "YES (manual)" : "NO";
   
   double dailyMaxLossPct = Config_GetDailyMaxLossPct();
   int maxLosses = Config_GetMaxConsecutiveLosses();
   int maxPerDay = Config_GetMaxTradesPerDay();
   int maxPerWeek = Config_GetMaxTradesPerWeek();
   int maxSpreadPts = Config_GetMaxSpreadPoints();
   
   double balance = AccountBalance();
   double maxLossMoney = balance * (dailyMaxLossPct / 100.0);
   
   if(dailyMaxLossPct > 0 && plToday <= -maxLossMoney) 
      lockTxt = "YES (daily loss)";
   if(maxLosses > 0 && streak >= maxLosses) 
      lockTxt = "YES (loss streak)";
   if(maxPerDay > 0 && closedToday >= maxPerDay) 
      lockTxt = "YES (max/day)";
   if(maxPerWeek > 0 && closedWeek >= maxPerWeek) 
      lockTxt = "YES (max/week)";
   if(maxSpreadPts > 0 && spreadPts > maxSpreadPts) 
      lockTxt = "YES (spread points)";

   // Check spread % of SL
   int slInput = GUI_ToIntSafe(GUI_GetEditText("SL"), Config_GetDefaultSL());
   double spreadPct = (slInput > 0) ? (100.0 * (double)spreadPips / (double)slInput) : 0.0;
   double maxSpreadPct = Config_GetMaxSpreadPctOfSL();
   if(maxSpreadPct > 0.0 && spreadPct > maxSpreadPct) 
      lockTxt = "YES (spread%SL)";

   // Calculate remaining budgets (percentage-based, using balance)
   string dailyRemainingTxt = "N/A";
   if(dailyMaxLossPct > 0)
   {
      double dailyRemaining = maxLossMoney + plToday;  // plToday is negative
      if(dailyRemaining < 0) dailyRemaining = 0;
      double remainingPct = (dailyRemaining / balance) * 100.0;
      dailyRemainingTxt = DoubleToString(remainingPct, 1) + "% (" + 
                          DoubleToString(dailyRemaining, 2) + " " + AccountCurrency() + ")";
   }

   int remToday = (maxPerDay > 0) ? (maxPerDay - closedToday) : 9999;
   if(remToday < 0) remToday = 0;

   int remWeek = (maxPerWeek > 0) ? (maxPerWeek - closedWeek) : 9999;
   if(remWeek < 0) remWeek = 0;

   // Market row
   GUI_CreateLabel("BID_L", 15, 115, "Bid: " + GUI_PriceStr(bid, digits));
   GUI_CreateLabel("ASK_L", 175,115, "Ask: " + GUI_PriceStr(ask, digits));
   GUI_CreateLabel("SPR_L", 335,115, "Spread: " + IntegerToString(spreadPips) + " p (" + IntegerToString(spreadPts) + " pts)");

   // Stats display
   GUI_CreateLabel("PL_L",   15, 140, "P/L today (closed): " + DoubleToString(plToday, 2) + " " + AccountCurrency(), 10);
   
   // Cumulative risk display
   double totalRiskMoney = 0;
   double totalRiskPct = 0;
   int openPositions = 0;
   TradeStats_GetCumulativeRisk(totalRiskMoney, totalRiskPct, openPositions);
   
   color riskColor = clrLimeGreen;
   string riskLabel = "TOTAL RISK: ";
   
   if(totalRiskPct < 0)
   {
      // Negative risk = positions are protected with profit
      riskColor = clrCyan;
      riskLabel = "TOTAL RISK (POS): ";
   }
   else if(totalRiskPct > 15.0)
      riskColor = clrRed;
   else if(totalRiskPct > 10.0)
      riskColor = clrOrange;
   else if(totalRiskPct > 5.0)
      riskColor = clrYellow;
   
   string riskTxt = riskLabel + DoubleToString(totalRiskPct, 1) + "% (" + 
                    DoubleToString(totalRiskMoney, 2) + " " + AccountCurrency() + ") [" + 
                    IntegerToString(openPositions) + " pos]";
   GUI_CreateLabel("CUMRISK_L", 15, 160, riskTxt, 11);
   ObjectSetInteger(0, GUI_PFX + "CUMRISK_L", OBJPROP_COLOR, riskColor);
   
   // Combined closed trades line
   string closedLine = "Closed: " + IntegerToString(closedToday) + "/" + IntegerToString(maxPerDay) + 
                       " today | " + IntegerToString(closedWeek) + "/" + IntegerToString(maxPerWeek) + " week";
   GUI_CreateLabel("TD_L", 15, 180, closedLine, 9);
   
   GUI_CreateLabel("LOCK_L", 15, 200, "LOCK: " + lockTxt, 10);
   
   // Cooldown display
   string cooldownTxt = "None";
   if(TimeCurrent() < cooldownUntil)
      cooldownTxt = cooldownReason;
   GUI_CreateLabel("CD_L", 15, 220, "Cooldown: " + cooldownTxt, 9);
   
   int noneCount = 0;
   int beCount = 0;
   int smartCount = 0;
   GUI_CountPositionModes(noneCount, beCount, smartCount);
   string modeTxt = "Modes: NONE " + IntegerToString(noneCount) +
                    " | BE " + IntegerToString(beCount) +
                    " | SMART " + IntegerToString(smartCount);
   GUI_CreateLabel("MODE_L", 15, 240, modeTxt, 9);

   // Remaining budgets
   GUI_CreateLabel("REMLOSS_L", 15, 260, "Daily loss remain: " + dailyRemainingTxt, 9);
   
   // Combined remaining line
   string remLine = "Remaining: " + IntegerToString(remToday) + " today | " + IntegerToString(remWeek) + " week";
   GUI_CreateLabel("REM_TD_L", 15, 280, remLine, 9);

   // ATR and calculation display
   GUI_UpdateCalculations();

   // Misc small details at bottom
   string misc = "Loss streak: " + IntegerToString(streak) + "/" + IntegerToString(maxLosses);
   if(maxSpreadPts > 0)
      misc += " | Max spread: " + IntegerToString(maxSpreadPts) + " pts";

   GUI_CreateLabel("MISC_L", 15, 300, misc, 8);
   
   // Time tracking display
   int todaySec, weekSec, allTimeSec;
   TimeTracking_GetData(todaySec, weekSec, allTimeSec);
   
   string timeText = "Screen time: Today " + TimeTracking_FormatSeconds(todaySec) + 
                     " | Week " + TimeTracking_FormatSeconds(weekSec) +
                     " | Total " + TimeTracking_FormatSeconds(allTimeSec);
   
   GUI_CreateLabel("TIME_L", 15, 320, timeText, 8);
   
   // Session gap statistics (condensed with separate color coding)
   int meanGap, minGap, maxGap, gapCount;
   TimeTracking_GetGapStats(meanGap, minGap, maxGap, gapCount);
   
   // Session counts
   int sessToday, sessWeek;
   double sessWeekAvg;
   TimeTracking_GetSessionCounts(sessToday, sessWeek, sessWeekAvg);
   
   // Color coding for mean TBS (goal: maximize time between sessions)
   color tbsColor = clrWhite;
   int meanGapMinutes = meanGap / 60;
   if(meanGapMinutes >= 180)        // 3+ hours
      tbsColor = clrLimeGreen;       // Excellent patience
   else if(meanGapMinutes >= 120)   // 2-3 hours
      tbsColor = clrGreen;           // Good discipline
   else if(meanGapMinutes >= 60)    // 1-2 hours
      tbsColor = clrYellow;          // Acceptable
   else if(meanGapMinutes >= 30)    // 30-60 min
      tbsColor = clrOrange;          // Frequent checking
   else if(meanGap > 0)             // <30 min
      tbsColor = clrRed;             // Compulsive behavior
   
   // Color coding for session count (goal: minimize sessions per day)
   color sessColor = clrWhite;
   if(sessWeekAvg <= 2.0)           // 2 or fewer per day
      sessColor = clrLimeGreen;      // Excellent discipline
   else if(sessWeekAvg <= 4.0)      // 2-4 per day
      sessColor = clrGreen;          // Good control
   else if(sessWeekAvg <= 6.0)      // 4-6 per day
      sessColor = clrYellow;         // Acceptable
   else if(sessWeekAvg <= 10.0)     // 6-10 per day
      sessColor = clrOrange;         // Too frequent
   else                              // 10+ per day
      sessColor = clrRed;            // Overtrading behavior
   
   // Create two separate labels with different colors
   string tbsText = "TBS: Mean " + TimeTracking_FormatGap(meanGap) +
                    " | Min " + TimeTracking_FormatGap(minGap) +
                    " | Max " + TimeTracking_FormatGap(maxGap);
   
   string sessText = " | Sessions: " + IntegerToString(sessToday) + " today, " +
                     DoubleToString(sessWeekAvg, 1) + "/day avg";
   
   // TBS part
   GUI_CreateLabel("GAP_TBS", 15, 335, tbsText, 8);
   ObjectSetInteger(0, GUI_PFX + "GAP_TBS", OBJPROP_COLOR, tbsColor);
   
   // Sessions part (offset X position)
   GUI_CreateLabel("GAP_SESS", 305, 335, sessText, 8);
   ObjectSetInteger(0, GUI_PFX + "GAP_SESS", OBJPROP_COLOR, sessColor);
}

//+------------------------------------------------------------------+
//| Update live calculations (ATR, lot size, risk, R:R)             |
//+------------------------------------------------------------------+
void GUI_UpdateCalculations()
{
   string sym = Symbol();
   int digits = (int)MarketInfo(sym, MODE_DIGITS);
   
   int slPips = GUI_ToIntSafe(GUI_GetEditText("SL"), Config_GetDefaultSL());
   int tpPips = GUI_ToIntSafe(GUI_GetEditText("TP"), Config_GetDefaultTP());
   double targetPrice = GUI_ToDoubleSafe(GUI_GetEditText("PX"), Config_GetDefaultTargetPrice());
   
   // Right side calculations area
   int baseX = 350;
   int baseY = 140;
   
   GUI_CreateLabel("CALC_TITLE", baseX, baseY, "=== LIVE CALCULATION ===", 9);
   
   // ATR suggestion with color coding
   int atrSuggest = RiskCalc_GetATR_SL_Suggestion(sym);
   double atrPips = RiskCalc_GetATR_Pips(sym);
   double atrMult = Config_GetATR_Multiplier();
   
   color atrColor = clrYellow;
   string atrStatus = "";
   if(slPips > 0 && atrSuggest > 0)
   {
      double ratio = (double)slPips / (double)atrSuggest;
      if(ratio >= 0.75 && ratio <= 1.25)
      {
         atrColor = clrLime;
         atrStatus = " ✓";
      }
      else if(ratio < 0.75)
      {
         atrColor = clrOrange;
         atrStatus = " (tight!)";
      }
      else
      {
         atrColor = clrYellow;
         atrStatus = " (wide)";
      }
   }
   
   GUI_CreateLabel("CALC_ATR", baseX, baseY+20, "ATR Suggest: " + IntegerToString(atrSuggest) + "p" + atrStatus, 9);
   ObjectSetInteger(0, GUI_PFX + "CALC_ATR", OBJPROP_COLOR, atrColor);
   
   GUI_CreateLabel("CALC_ATR_DETAIL", baseX, baseY+35, "(ATR " + DoubleToString(atrPips,1) + "p × " + DoubleToString(atrMult,1) + ")", 8);
   ObjectSetInteger(0, GUI_PFX + "CALC_ATR_DETAIL", OBJPROP_COLOR, clrGray);
   
   string slCompare = "Your SL: " + IntegerToString(slPips) + "p";
   GUI_CreateLabel("CALC_SL_COMPARE", baseX, baseY+50, slCompare, 9);
   ObjectSetInteger(0, GUI_PFX + "CALC_SL_COMPARE", OBJPROP_COLOR, atrColor);
   
   GUI_CreateLabel("CALC_DIVIDER", baseX, baseY+65, "---", 8);
   
   // Lot size calculation
   double lots = 0;
   if(slPips > 0)
      RiskCalc_CalcLotsFromRisk(sym, slPips, Config_GetRiskPct(), lots);
   
   GUI_CreateLabel("CALC_LOTS", baseX, baseY+75, "Lot size: " + DoubleToString(lots, 2), 9);
   
   // Entry price
   RefreshRates();
   double entryPrice = (targetPrice > 0) ? targetPrice : Ask;
   GUI_CreateLabel("CALC_ENTRY", baseX, baseY+90, "Entry (BUY): " + DoubleToString(entryPrice, digits), 8);
   
   // SL price
   double pip = RiskCalc_PipSize(sym);
   int spreadPips = RiskCalc_SpreadPips(sym);
   double slPrice = entryPrice - ((slPips - spreadPips) * pip);
   GUI_CreateLabel("CALC_SL", baseX, baseY+105, "SL price: " + DoubleToString(slPrice, digits), 8);
   
   // Risk money
   double vpp = RiskCalc_ValuePerPipPerLot(sym);
   double riskMoney = slPips * vpp * lots;
   GUI_CreateLabel("CALC_RISK", baseX, baseY+120, "Risk: " + DoubleToString(riskMoney, 2) + " " + AccountCurrency(), 9);
   
   // TP and reward
   if(tpPips > 0)
   {
      double tpPrice = entryPrice + (tpPips * pip);
      double rewardMoney = tpPips * vpp * lots;
      double rr = (riskMoney > 0) ? (rewardMoney / riskMoney) : 0;
      
      GUI_CreateLabel("CALC_TP", baseX, baseY+135, "TP price: " + DoubleToString(tpPrice, digits), 8);
      GUI_CreateLabel("CALC_REWARD", baseX, baseY+150, "Reward: " + DoubleToString(rewardMoney, 2) + " " + AccountCurrency(), 8);
      GUI_CreateLabel("CALC_RR", baseX, baseY+165, "R:R = " + DoubleToString(rr, 2), 9);
   }
   else
   {
      GUI_CreateLabel("CALC_TP", baseX, baseY+135, "TP price: (none)", 8);
      GUI_CreateLabel("CALC_REWARD", baseX, baseY+150, "Reward: (none)", 8);
      GUI_CreateLabel("CALC_RR", baseX, baseY+165, "R:R = (no TP)", 8);
   }
   
   // Spread vs SL ratio
   double spreadPct = (slPips > 0) ? (100.0 * (double)spreadPips / (double)slPips) : 0.0;
   double maxSpreadPct = Config_GetMaxSpreadPctOfSL();
   
   color spreadColor = clrWhite;
   if(maxSpreadPct > 0.0 && spreadPct > maxSpreadPct)
      spreadColor = clrRed;
   else if(spreadPct > 25.0)
      spreadColor = clrOrange;
   else if(spreadPct > 15.0)
      spreadColor = clrYellow;
   else
      spreadColor = clrLimeGreen;
   
   string spreadRatioTxt = "Spread/SL: " + DoubleToString(spreadPct, 1) + "%";
   if(maxSpreadPct > 0.0)
      spreadRatioTxt += " (max " + DoubleToString(maxSpreadPct, 1) + "%)";
      
   GUI_CreateLabel("CALC_SPREAD_RATIO", baseX, baseY+180, spreadRatioTxt, 8);
   ObjectSetInteger(0, GUI_PFX + "CALC_SPREAD_RATIO", OBJPROP_COLOR, spreadColor);
}
//+------------------------------------------------------------------+
