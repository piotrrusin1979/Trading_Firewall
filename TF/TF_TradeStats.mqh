//+------------------------------------------------------------------+
//| TF_TradeStats.mqh                                                |
//| Trade statistics and history analysis                            |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Calculate closed P/L since a given time                          |
//+------------------------------------------------------------------+
double TradeStats_ClosedPLSince(datetime t0)
{
   double pl = 0.0;
   for(int i=OrdersHistoryTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderCloseTime() < t0) break;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;

      pl += (OrderProfit() + OrderSwap() + OrderCommission());
   }
   return pl;
}

//+------------------------------------------------------------------+
//| Count closed trades since a given time                           |
//+------------------------------------------------------------------+
int TradeStats_TradesClosedSince(datetime t0)
{
   int cnt = 0;
   for(int i=OrdersHistoryTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderCloseTime() < t0) break;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;

      cnt++;
   }
   return cnt;
}

//+------------------------------------------------------------------+
//| Calculate loss streak within today                               |
//+------------------------------------------------------------------+
int TradeStats_LossStreakToday(datetime dayStart)
{
   int losses = 0;
   for(int i=OrdersHistoryTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderCloseTime() < dayStart) break;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;

      double pl = (OrderProfit() + OrderSwap() + OrderCommission());
      if(pl < 0) losses++;
      else break;
   }
   return losses;
}

//+------------------------------------------------------------------+
//| Check if there's an open position on a symbol                    |
//+------------------------------------------------------------------+
bool TradeStats_HasOpenPositionOnSymbol(string sym)
{
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;
      if(OrderSymbol() == sym) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if there are open positions on any OTHER symbol           |
//+------------------------------------------------------------------+
bool TradeStats_HasOpenPositionOnOtherSymbol(string currentSymbol)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;
      
      if(OrderSymbol() != currentSymbol)
         return true;  // Found position on different symbol
   }
   return false;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check recently closed trades and determine cooldown              |
//+------------------------------------------------------------------+
void TradeStats_CheckLastTradeForCooldown(datetime dayStart, datetime &cooldownUntil, string &cooldownReason,
                                          int &cooldownReasonCode, double &cooldownReasonValue, bool &bigWinToday)
{
   int total = OrdersHistoryTotal();
   if(total == 0) return;
   
   datetime now = TimeCurrent();
   datetime longestCooldown = 0;
   string longestReason = "";
   int longestReasonCode = 0;
   double longestReasonValue = 0.0;
   bool foundBigWin = false;
   
   // Check last 10 closed trades (or all recent trades from last minute)
   int checkCount = MathMin(10, total);
   
   for(int i = total - 1; i >= total - checkCount && i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;
      
      datetime closeTime = OrderCloseTime();
      
      // Only check trades closed in the last 2 minutes (to catch Kill Switch bulk closes)
      if(now - closeTime > 120) break;
      
      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      double equity = AccountEquity();
      double profitPct = (profit / equity) * 100.0;
      
      // Check for big win (blocks rest of day)
      if(profitPct >= Config_GetBigWinPct())
      {
         foundBigWin = true;
         datetime thisCooldown = closeTime + 86400; // End of day
         if(thisCooldown > longestCooldown)
         {
            longestCooldown = thisCooldown;
            longestReason = "Big win (" + DoubleToString(profitPct, 1) + "%) - done for today";
            longestReasonCode = 4;
            longestReasonValue = profitPct;
         }
         continue;
      }
      
      // Check for big loss (1 hour cooldown)
      if(profitPct <= -Config_GetBigLossPct())
      {
         int cooldownMinutes = Config_GetCooldownAfterBigLoss();
         datetime thisCooldown = closeTime + (cooldownMinutes * 60);
         if(thisCooldown > longestCooldown)
         {
            longestCooldown = thisCooldown;
            int remaining = (int)((thisCooldown - now) / 60);
            longestReason = "Big loss (" + DoubleToString(profitPct, 1) + "%) - " + 
                           IntegerToString(remaining) + " min remaining";
            longestReasonCode = 3;
            longestReasonValue = profitPct;
         }
         continue;
      }
      
      // Regular win cooldown
      if(profit > 0)
      {
         int cooldownMinutes = Config_GetCooldownAfterWin();
         if(cooldownMinutes > 0)
         {
            datetime thisCooldown = closeTime + (cooldownMinutes * 60);
            if(thisCooldown > longestCooldown)
            {
               longestCooldown = thisCooldown;
               int remaining = (int)((thisCooldown - now) / 60);
               longestReason = "Win cooldown - " + IntegerToString(remaining) + " min remaining";
               longestReasonCode = 1;
               longestReasonValue = 0.0;
            }
         }
         continue;
      }
      
      // Regular loss cooldown
      if(profit < 0)
      {
         int cooldownMinutes = Config_GetCooldownAfterLoss();
         if(cooldownMinutes > 0)
         {
            int multiplier = 1;
            if(Config_GetBlockRevengeTrading())
            {
               int streak = TradeStats_LossStreakToday(dayStart);
               if(streak >= 2)
                  multiplier = 2;
            }

            cooldownMinutes *= multiplier;
            datetime thisCooldown = closeTime + (cooldownMinutes * 60);
            if(thisCooldown > longestCooldown)
            {
               longestCooldown = thisCooldown;
               int remaining = (int)((thisCooldown - now) / 60);
               string prefix = (multiplier > 1) ? "REVENGE BLOCK (2x)" : "Loss cooldown";
               longestReason = prefix + " - " + IntegerToString(remaining) + " min remaining";
               longestReasonCode = (multiplier > 1) ? 5 : 2;
               longestReasonValue = 0.0;
            }
         }
      }
   }
   
   // Apply the longest/most severe cooldown found
   if(foundBigWin)
   {
      bigWinToday = true;
   }
   
   if(longestCooldown > now)
   {
      cooldownUntil = longestCooldown;
      cooldownReason = longestReason;
      cooldownReasonCode = longestReasonCode;
      cooldownReasonValue = longestReasonValue;
   }
}

//+------------------------------------------------------------------+
//| Calculate cumulative risk across all open positions              |
//| Risk = sum of potential losses minus sum of protected profits    |
//+------------------------------------------------------------------+
void TradeStats_GetCumulativeRisk(double &riskMoney, double &riskPct, int &posCount)
{
   riskMoney = 0.0;
   riskPct = 0.0;
   posCount = 0;
   
   double balance = AccountBalance();
   if(balance <= 0) return;
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;
      
      posCount++;
      
      string sym = OrderSymbol();
      double lots = OrderLots();
      double openPrice = OrderOpenPrice();
      double sl = OrderStopLoss();
      double currentPrice = (type == OP_BUY) ? MarketInfo(sym, MODE_BID) : MarketInfo(sym, MODE_ASK);
      
      double positionRisk = 0.0;
      
      if(sl > 0)
      {
         // Calculate risk/protection based on SL
         double slDistance = MathAbs(openPrice - sl);
         double currentDistance = (type == OP_BUY) ? (currentPrice - openPrice) : (openPrice - currentPrice);
         
         double tickValue = MarketInfo(sym, MODE_TICKVALUE);
         double tickSize = MarketInfo(sym, MODE_TICKSIZE);
         
         if(tickSize > 0)
         {
            double valuePerPoint = tickValue / tickSize;
            
            // Check if position is in profit or loss
            if(currentDistance > 0)
            {
               // Position in PROFIT
               // Check if SL is protecting profit (moved beyond entry)
               bool slProtectingProfit = false;
               if(type == OP_BUY && sl > openPrice)
                  slProtectingProfit = true;
               else if(type == OP_SELL && sl < openPrice)
                  slProtectingProfit = true;
               
               if(slProtectingProfit)
               {
                  // SL is in profit zone - this REDUCES total risk
                  double protectedProfit = MathAbs(sl - openPrice);
                  positionRisk = -1.0 * protectedProfit * valuePerPoint * lots; // Negative = protected
               }
               else
               {
                  // SL still at original position, no protection yet
                  positionRisk = slDistance * valuePerPoint * lots;
               }
            }
            else
            {
               // Position in LOSS - SL represents real risk
               positionRisk = slDistance * valuePerPoint * lots;
            }
         }
      }
      else
      {
         // No SL set - calculate worst case (margin call scenario)
         double marginRequired = MarketInfo(sym, MODE_MARGINREQUIRED);
         if(marginRequired > 0)
         {
            positionRisk = marginRequired * lots;
         }
         else
         {
            // Fallback: assume account currency value of position
            double contractSize = MarketInfo(sym, MODE_LOTSIZE);
            positionRisk = openPrice * contractSize * lots * 0.01; // Rough estimate
         }
      }
      
      riskMoney += positionRisk;
   }
   
   riskPct = (balance > 0) ? (riskMoney / balance * 100.0) : 0.0;
}
//+------------------------------------------------------------------+
