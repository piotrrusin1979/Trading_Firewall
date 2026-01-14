//+------------------------------------------------------------------+
//| TF_BreakEven.mqh                                                 |
//| Break Even management - Force BE feature                         |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Process all open positions for Break Even                        |
//+------------------------------------------------------------------+
void BreakEven_ProcessPositions()
{
   
   double triggerMult = Config_GetBE_TriggerMultiplier();
   double lockMult = Config_GetBE_LockMultiplier();
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;

      int posMode = GUI_GetPositionMode(OrderTicket());
      if(posMode != 1) continue;

      // Get order details
      string sym = OrderSymbol();
      double entry = OrderOpenPrice();
      double currentSL = OrderStopLoss();
      int ticket = OrderTicket();
      
      // Skip if SL is already at or beyond BE level
      if(currentSL == 0) continue; // No SL set
      
      // Calculate original SL distance from entry
      double slDistance = MathAbs(entry - currentSL);
      if(slDistance < 0.00001) continue; // No meaningful SL
      
      // Get current price
      RefreshRates();
      double currentPrice = (type == OP_BUY) ? Bid : Ask;
      
      // Calculate profit in price terms
      double profit = (type == OP_BUY) ? (currentPrice - entry) : (entry - currentPrice);
      
      // Check if profit reached trigger level (2× SL distance)
      double triggerDistance = slDistance * triggerMult;
      
      if(profit >= triggerDistance)
      {
         // Calculate new BE SL (entry + 1× SL distance)
         double newSL = 0;
         if(type == OP_BUY)
         {
            newSL = entry + (slDistance * lockMult);
            
            // Only move if new SL is better than current
            if(newSL > currentSL)
            {
               if(BreakEven_ModifySL(ticket, newSL))
               {
                  Print("BE activated for ticket #", ticket, " ", sym, 
                        " moved SL from ", DoubleToString(currentSL, Digits),
                        " to ", DoubleToString(newSL, Digits));
               }
            }
         }
         else // OP_SELL
         {
            newSL = entry - (slDistance * lockMult);
            
            // Only move if new SL is better than current
            if(newSL < currentSL)
            {
               if(BreakEven_ModifySL(ticket, newSL))
               {
                  Print("BE activated for ticket #", ticket, " ", sym,
                        " moved SL from ", DoubleToString(currentSL, Digits),
                        " to ", DoubleToString(newSL, Digits));
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Modify stop loss for a specific order                           |
//+------------------------------------------------------------------+
bool BreakEven_ModifySL(int ticket, double newSL)
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
      Print("BE ModifySL failed for ticket #", ticket, " error: ", err);
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Get count of positions with BE active (SL above/below entry)    |
//+------------------------------------------------------------------+
int BreakEven_GetActiveCount()
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
