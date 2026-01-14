//+------------------------------------------------------------------+
//| TF_RiskCalculator.mqh                                            |
//| Risk calculation and lot sizing                                  |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Get pip size for a symbol                                        |
//+------------------------------------------------------------------+
double RiskCalc_PipSize(string sym)
{
   int digits = (int)MarketInfo(sym, MODE_DIGITS);
   double pt = MarketInfo(sym, MODE_POINT);
   if(digits == 3 || digits == 5) return pt * 10.0;
   return pt;
}

//+------------------------------------------------------------------+
//| Get spread in pips                                               |
//+------------------------------------------------------------------+
int RiskCalc_SpreadPips(string sym)
{
   int spreadPoints = (int)MarketInfo(sym, MODE_SPREAD);
   double pip = RiskCalc_PipSize(sym);
   double point = MarketInfo(sym, MODE_POINT);

   double spreadPrice = spreadPoints * point;
   int pips = (int)MathCeil(spreadPrice / pip);

   return MathMax(pips, 0);
}

//+------------------------------------------------------------------+
//| Get value per pip per lot                                        |
//+------------------------------------------------------------------+
double RiskCalc_ValuePerPipPerLot(string sym)
{
   double tickValue = MarketInfo(sym, MODE_TICKVALUE);
   double tickSize  = MarketInfo(sym, MODE_TICKSIZE);
   double pip       = RiskCalc_PipSize(sym);
   if(tickSize <= 0) return 0;
   return tickValue * (pip / tickSize);
}

//+------------------------------------------------------------------+
//| Clamp lot size to broker's min/max/step                          |
//+------------------------------------------------------------------+
double RiskCalc_ClampLot(string sym, double lots)
{
   double minLot  = MarketInfo(sym, MODE_MINLOT);
   double maxLot  = MarketInfo(sym, MODE_MAXLOT);
   double stepLot = MarketInfo(sym, MODE_LOTSTEP);

   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;

   // Normalize to lot step
   double steps = MathFloor(lots / stepLot + 1e-9);
   double out = steps * stepLot;

   return NormalizeDouble(out, 2);
}

//+------------------------------------------------------------------+
//| Calculate lot size from risk parameters                          |
//+------------------------------------------------------------------+
bool RiskCalc_CalcLotsFromRisk(string sym, int totalRiskPips, double riskPct, double &lotsOut)
{
   if(totalRiskPips <= 0) return false;

   double riskMoney = AccountEquity() * (riskPct / 100.0);
   double vpp = RiskCalc_ValuePerPipPerLot(sym);
   if(vpp <= 0) return false;

   double rawLots = riskMoney / (totalRiskPips * vpp);
   lotsOut = RiskCalc_ClampLot(sym, rawLots);
   return (lotsOut > 0);
}

//+------------------------------------------------------------------+
//| Convenience wrapper for GUI - uses config risk %                 |
//+------------------------------------------------------------------+
bool RiskCalc_CanCalcLots(string sym, int totalRiskPips, double &lotsOut)
{
   return RiskCalc_CalcLotsFromRisk(sym, totalRiskPips, Config_GetRiskPct(), lotsOut);
}

//+------------------------------------------------------------------+
//| Calculate ATR-based stop loss suggestion                         |
//+------------------------------------------------------------------+
int RiskCalc_GetATR_SL_Suggestion(string sym)
{
   int period = Config_GetATR_Period();
   double multiplier = Config_GetATR_Multiplier();
   int tfMinutes = Config_GetATR_TimeframeMinutes();
   
   // Convert minutes to MT4 timeframe constant
   ENUM_TIMEFRAMES tf = PERIOD_CURRENT;
   if(tfMinutes > 0)
   {
      if(tfMinutes == 1) tf = PERIOD_M1;
      else if(tfMinutes == 5) tf = PERIOD_M5;
      else if(tfMinutes == 15) tf = PERIOD_M15;
      else if(tfMinutes == 30) tf = PERIOD_M30;
      else if(tfMinutes == 60) tf = PERIOD_H1;
      else if(tfMinutes == 240) tf = PERIOD_H4;
      else if(tfMinutes == 1440) tf = PERIOD_D1;
      else tf = PERIOD_CURRENT;
   }
   
   // Get ATR value
   double atr = iATR(sym, tf, period, 0);
   if(atr <= 0) return 0;
   
   // Convert to pips
   double pip = RiskCalc_PipSize(sym);
   double atrPips = atr / pip;
   
   // Calculate SL distance (ATR-to-price distance)
   int slToPricePips = (int)MathRound(atrPips * multiplier);
   
   // Add spread to get total SL
   int spread = RiskCalc_SpreadPips(sym);
   int totalSL = slToPricePips + spread;
   
   return totalSL;
}

//+------------------------------------------------------------------+
//| Get raw ATR value in pips for display                           |
//+------------------------------------------------------------------+
double RiskCalc_GetATR_Pips(string sym)
{
   int period = Config_GetATR_Period();
   int tfMinutes = Config_GetATR_TimeframeMinutes();
   
   ENUM_TIMEFRAMES tf = PERIOD_CURRENT;
   if(tfMinutes > 0)
   {
      if(tfMinutes == 1) tf = PERIOD_M1;
      else if(tfMinutes == 5) tf = PERIOD_M5;
      else if(tfMinutes == 15) tf = PERIOD_M15;
      else if(tfMinutes == 30) tf = PERIOD_M30;
      else if(tfMinutes == 60) tf = PERIOD_H1;
      else if(tfMinutes == 240) tf = PERIOD_H4;
      else if(tfMinutes == 1440) tf = PERIOD_D1;
      else tf = PERIOD_CURRENT;
   }
   
   double atr = iATR(sym, tf, period, 0);
   if(atr <= 0) return 0;
   
   double pip = RiskCalc_PipSize(sym);
   return atr / pip;
}
//+------------------------------------------------------------------+