//+------------------------------------------------------------------+
//| TF_SmartSL.mqh                                                   |
//| Smart Stop Loss - Locks 60% of profit when price moves favorably |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Process all open positions for Smart SL                          |
//+------------------------------------------------------------------+
void SmartSL_ProcessPositions()
{
   double profitLockPct = Config_GetSmartSL_ProfitLockPct();      // 60% default
   double triggerMult = Config_GetSmartSL_TriggerMultiplier();    // 2.0 default

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;

      int posMode = GUI_GetPositionMode(OrderTicket());
      if(posMode != 2) continue;

      // Get order details
      string sym = OrderSymbol();
      double entry = OrderOpenPrice();
      double currentSL = OrderStopLoss();
      int ticket = OrderTicket();

      // Skip if no SL set
      if(currentSL == 0) continue;

      // Calculate original SL distance from entry
      double originalSLDistance = MathAbs(entry - currentSL);
      double storedDistance = SmartSL_GetStoredDistance(ticket);
      double baseDistance = (storedDistance > 0) ? storedDistance : originalSLDistance;
      if(baseDistance < 0.00001) continue; // No meaningful SL

      // Get current price
      RefreshRates();
      double currentPrice = (type == OP_BUY) ? Bid : Ask;

      // Calculate current profit in price terms
      double currentProfit = (type == OP_BUY) ? (currentPrice - entry) : (entry - currentPrice);

      bool slOnNegativeSide = (type == OP_BUY) ? (currentSL < entry) : (currentSL > entry);
      if(slOnNegativeSide && currentProfit >= originalSLDistance)
      {
         if(SmartSL_ModifySL(ticket, entry))
         {
            int digits = (int)MarketInfo(sym, MODE_DIGITS);
            Print("Smart SL #", ticket, " ", sym, " → SL: ",
                  DoubleToString(entry, digits), " (break even)");
         }
         continue;
      }

      // Check if profit reached trigger level (2x original SL distance)
      double triggerDistance = baseDistance * triggerMult;

      if(currentProfit >= triggerDistance)
      {
         // Calculate new SL to lock 60% of current profit
         double profitToLock = currentProfit * (profitLockPct / 100.0);
         double newSL = 0;
         bool shouldUpdate = false;

         if(type == OP_BUY)
         {
            // For BUY: Lock profit above entry
            newSL = entry + profitToLock;

            // Only move SL up (never down)
            if(newSL > currentSL)
               shouldUpdate = true;
         }
         else if(type == OP_SELL)
         {
            // For SELL: Lock profit below entry
            newSL = entry - profitToLock;

            // Only move SL down (never up)
            if(newSL < currentSL)
               shouldUpdate = true;
         }

         if(shouldUpdate)
         {
            if(SmartSL_ModifySL(ticket, newSL))
            {
               int digits = (int)MarketInfo(sym, MODE_DIGITS);
               double pip = RiskCalc_PipSize(sym);
               int lockedPips = (int)MathRound(profitToLock / pip);
               int totalProfitPips = (int)MathRound(currentProfit / pip);

               Print("Smart SL #", ticket, " ", sym,
                     " → SL: ", DoubleToString(newSL, digits),
                     " (locked ", lockedPips, "p of ", totalProfitPips, "p = ",
                     DoubleToString(profitLockPct, 0), "%)");
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Modify stop loss for a specific order                            |
//+------------------------------------------------------------------+
bool SmartSL_ModifySL(int ticket, double newSL)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return false;

   string sym = OrderSymbol();
   int digits = (int)MarketInfo(sym, MODE_DIGITS);
   newSL = NormalizeDouble(newSL, digits);

   double entry = OrderOpenPrice();
   double tp = OrderTakeProfit();

   bool result = OrderModify(ticket, entry, newSL, tp, 0, clrBlue);

   if(!result)
   {
      int err = GetLastError();
      Print("Smart SL ModifySL failed for #", ticket, " error: ", err);
   }

   return result;
}

//+------------------------------------------------------------------+
//| Get count of positions with Smart SL active                      |
//| (SL is above entry for BUY or below entry for SELL)             |
//+------------------------------------------------------------------+
int SmartSL_GetActiveCount()
{
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;

      double entry = OrderOpenPrice();
      double sl = OrderStopLoss();

      if(sl == 0) continue;

      // Check if SL is in profit territory
      if(type == OP_BUY && sl > entry) count++;
      if(type == OP_SELL && sl < entry) count++;
   }

   return count;
}

//+------------------------------------------------------------------+
//| Helpers for Smart SL original distance tracking                  |
//+------------------------------------------------------------------+
string SmartSL_DistanceKey(int ticket)
{
   return "TF_SMARTSL_DIST_" + IntegerToString(ticket);
}

double SmartSL_GetStoredDistance(int ticket)
{
   string key = SmartSL_DistanceKey(ticket);
   if(GlobalVariableCheck(key))
      return GlobalVariableGet(key);
   return 0.0;
}

void SmartSL_SetStoredDistance(int ticket, double distance)
{
   if(distance <= 0) return;
   string key = SmartSL_DistanceKey(ticket);
   GlobalVariableSet(key, distance);
}

void SmartSL_ClearStoredDistance(int ticket)
{
   string key = SmartSL_DistanceKey(ticket);
   if(GlobalVariableCheck(key))
      GlobalVariableDel(key);
}
//+------------------------------------------------------------------+
