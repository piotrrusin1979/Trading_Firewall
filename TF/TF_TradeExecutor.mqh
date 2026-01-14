//+------------------------------------------------------------------+
//| TF_TradeExecutor.mqh                                             |
//| Trade execution logic - order placement and confirmation         |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Show blocked popup message                                       |
//+------------------------------------------------------------------+
void TradeExecutor_ShowBlockedPopup(const string reason)
{
   string msg = "TRADE BLOCKED\n\n" + reason + "\n\n(No order was sent.)";
   MessageBox(msg, "Trade Firewall", MB_OK | MB_ICONSTOP);
}

//+------------------------------------------------------------------+
//| Show trade confirmation popup                                    |
//+------------------------------------------------------------------+
bool TradeExecutor_ConfirmTradePopup(string sym, int orderType, double lots,
                                     int slPips, int tpPips,
                                     double entry, double slPrice, double tpPrice,
                                     bool isPending)
{
   int digits  = (int)MarketInfo(sym, MODE_DIGITS);
   string side = "BUY";
   if(orderType == OP_SELL || orderType == OP_SELLLIMIT || orderType == OP_SELLSTOP) 
      side = "SELL";

   int spreadPips = RiskCalc_SpreadPips(sym);
   int slToPricePips = slPips - spreadPips;

   double vpp = RiskCalc_ValuePerPipPerLot(sym);
   double realRiskMoney = slPips * vpp * lots;
   double spreadPct = (slPips > 0) ? (100.0 * (double)spreadPips / (double)slPips) : 0.0;

   string ordKind = "MARKET";
   if(orderType == OP_BUYLIMIT || orderType == OP_SELLLIMIT)
      ordKind = "LIMIT";
   else if(orderType == OP_BUYSTOP || orderType == OP_SELLSTOP)
      ordKind = "STOP";

   string checklist = "";
   if(Config_EnableChecklist())
   {
      checklist =
         "\nChecklist (be honest):\n"
         "1) Planned setup (not impulse)\n"
         "2) Entry is valid (level/trigger)\n"
         "3) SL makes sense (not too tight)\n"
         "4) I accept the full loss if stopped\n";
   }

   string msg =
      "Confirm trade\n\n"
      "Symbol: " + sym + "\n"
      "Order: " + side + " " + ordKind + "\n"
      "Lots: " + DoubleToString(lots, 2) + "\n\n"
      "Entry: " + DoubleToString(entry, digits) + "\n"
      "SL-to-price: " + IntegerToString(slToPricePips) + " pips  @ " + DoubleToString(slPrice, digits) + "\n" +
      (tpPips > 0
         ? ("TP: " + IntegerToString(tpPips) + " pips  @ " + DoubleToString(tpPrice, digits) + "\n")
         : "TP: (none)\n") +
      "\n"
      "Spread: " + IntegerToString(spreadPips) + " pips (" + DoubleToString(spreadPct,1) + "% of SL)\n"
      "Total risk (incl. spread): " + IntegerToString(slPips) + " pips\n"
      "Risk (money): " + DoubleToString(realRiskMoney, 2) + " " + AccountCurrency() + "\n";

   if(isPending)
      msg += "\nNote: spread used for math is current spread.\n";

   msg += checklist;

   int r = MessageBox(msg, "Trade Firewall", MB_OKCANCEL | MB_ICONQUESTION);
   return (r == IDOK);
}

//+------------------------------------------------------------------+
//| Main trade execution function                                    |
//+------------------------------------------------------------------+
bool TradeExecutor_PlaceTrade(int cmd, datetime dayStart, datetime weekStart, bool manualLock,
                              datetime cooldownUntil, string cooldownReason)
{
   string sym = Symbol();

   int slPips = GUI_ToIntSafe(GUI_GetEditText("SL"), Config_GetDefaultSL());
   int tpPips = GUI_ToIntSafe(GUI_GetEditText("TP"), Config_GetDefaultTP());
   double target = GUI_ToDoubleSafe(GUI_GetEditText("PX"), Config_GetDefaultTargetPrice());
   
   Print("Trade inputs: SL=", slPips, " TP=", tpPips, " Target=", target);

   if(slPips <= 0)
   {
      string r = "Blocked: SL pips must be > 0";
      Print(r); 
      TradeExecutor_ShowBlockedPopup(r);
      return false;
   }

   // Check trading rules
   string reason;
   if(!RuleEngine_CanTrade(sym, slPips, dayStart, weekStart, manualLock, cooldownUntil, cooldownReason, reason))
   {
      Print(reason); 
      TradeExecutor_ShowBlockedPopup(reason);
      return false;
   }

   // Calculate lot size
   double lots = 0;
   if(!RiskCalc_CalcLotsFromRisk(sym, slPips, Config_GetRiskPct(), lots))
   {
      string r2 = "Blocked: cannot calculate lot size (symbol settings / tick value issue)";
      Print(r2); 
      TradeExecutor_ShowBlockedPopup(r2);
      return false;
   }

   RefreshRates();
   double pip = RiskCalc_PipSize(sym);
   int digits = (int)MarketInfo(sym, MODE_DIGITS);

   int spreadP = RiskCalc_SpreadPips(sym);
   int slToPricePips = slPips - spreadP;

   bool usePending = (target > 0.0);
   int orderType = cmd;

   // Determine entry price and order type
   double entry = 0.0;
   if(!usePending)
   {
      // Market order
      entry = (cmd == OP_BUY) ? Ask : Bid;
      orderType = cmd;
   }
   else
   {
      // Pending order - auto-detect LIMIT vs STOP
      double ask = Ask;
      double bid = Bid;

      if(cmd == OP_BUY)
      {
         if(target < ask)
         {
            // BUY LIMIT (buy below current price)
            orderType = OP_BUYLIMIT;
         }
         else
         {
            // BUY STOP (buy above current price)
            orderType = OP_BUYSTOP;
         }
         entry = NormalizeDouble(target, digits);
      }
      else // OP_SELL
      {
         if(target > bid)
         {
            // SELL LIMIT (sell above current price)
            orderType = OP_SELLLIMIT;
         }
         else
         {
            // SELL STOP (sell below current price)
            orderType = OP_SELLSTOP;
         }
         entry = NormalizeDouble(target, digits);
      }
   }

   // Calculate SL/TP prices
   double sl = 0, tp = 0;
   if(orderType == OP_BUY || orderType == OP_BUYLIMIT || orderType == OP_BUYSTOP)
   {
      sl = entry - slToPricePips * pip;
      if(tpPips > 0) tp = entry + tpPips * pip;
   }
   else // OP_SELL, OP_SELLLIMIT, OP_SELLSTOP
   {
      sl = entry + slToPricePips * pip;
      if(tpPips > 0) tp = entry - tpPips * pip;
   }

   sl = NormalizeDouble(sl, digits);
   if(tpPips > 0) tp = NormalizeDouble(tp, digits);

   // Show confirmation popup
   if(Config_ShowConfirmPopup())
   {
      bool isPending = (orderType != OP_BUY && orderType != OP_SELL);
      if(!TradeExecutor_ConfirmTradePopup(sym, orderType, lots, slPips, tpPips, 
                                          entry, sl, tp, isPending))
      {
         Print("Trade cancelled by user.");
         return false;
      }
   }

   // Send order
   string comment = "TFP risk " + DoubleToString(Config_GetRiskPct(),1) + "% (SLinclSpread)";
   int ticket = OrderSend(sym, orderType, lots, entry, Config_GetSlippage(), 
                          sl, (tpPips>0 ? tp : 0), comment, 0, 0, clrNONE);
   
   if(ticket < 0)
   {
      int err = GetLastError();
      string errMsg = "OrderSend failed (err=" + IntegerToString(err) + ")\n\n";
      
      // Common error codes with helpful messages
      if(err == 2) errMsg += "Common trade error. Check connection.";
      else if(err == 3) errMsg += "Invalid trade parameters. Check SL/TP levels.";
      else if(err == 4) errMsg += "Trade server is busy. Try again.";
      else if(err == 6) errMsg += "No connection to trade server.";
      else if(err == 8) errMsg += "Too frequent requests. Wait a moment.";
      else if(err == 64) errMsg += "Account blocked. Contact broker.";
      else if(err == 65) errMsg += "Invalid account. Check login.";
      else if(err == 128) errMsg += "Trade timeout. Try again.";
      else if(err == 129) errMsg += "Invalid price. Market moved.";
      else if(err == 130) errMsg += "Invalid stops. Check SL/TP distance.";
      else if(err == 131) errMsg += "Invalid trade volume. Check lot size.";
      else if(err == 132) errMsg += "Market is closed.";
      else if(err == 133) errMsg += "Trading is disabled.";
      else if(err == 134) errMsg += "Not enough money for this trade.";
      else if(err == 135) errMsg += "Price changed. Retry.";
      else if(err == 136) errMsg += "No prices. Wait for quotes.";
      else if(err == 137) errMsg += "Broker is busy. Retry.";
      else if(err == 138) errMsg += "New prices. Requote. Retry.";
      else if(err == 139) errMsg += "Order is locked. Processing.";
      else if(err == 141) errMsg += "Too many requests. Slow down.";
      else if(err == 145) errMsg += "Modification denied. Too close to market.";
      else if(err == 146) errMsg += "Trade context is busy. Wait.";
      else if(err == 147) errMsg += "Expiration date is invalid.";
      else if(err == 148) errMsg += "Too many open/pending orders.";
      else if(err == 4051) errMsg += "Invalid function parameter.";
      else if(err == 4109) errMsg += "Trading NOT allowed!\n\nFix:\n1. Click Tools → Options → Expert Advisors\n2. Check 'Allow Algo Trading'\n3. Press F7 on chart → Common → Check 'Allow Algo Trading'";
      else errMsg += "Unknown error. Check Experts log.";
      
      Print("OrderSend failed: ", errMsg);
      TradeExecutor_ShowBlockedPopup(errMsg);
      return false;
   }

   Print("Placed ",
         (orderType==OP_BUY?"BUY MKT":
          orderType==OP_SELL?"SELL MKT":
          orderType==OP_BUYLIMIT?"BUY LIMIT":
          orderType==OP_BUYSTOP?"BUY STOP":
          orderType==OP_SELLLIMIT?"SELL LIMIT":"SELL STOP"),
         " ", sym, " lots=", DoubleToString(lots,2),
         " Entry=", DoubleToString(entry,digits),
         " SL(total)=", slPips, "p TP=", tpPips, "p");

   return true;
}

//+------------------------------------------------------------------+
//| Kill Switch - Close all open positions immediately              |
//+------------------------------------------------------------------+
int TradeExecutor_KillSwitch()
{
   int closed = 0;
   int failed = 0;
   
   // Close all market orders
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      
      int type = OrderType();
      int ticket = OrderTicket();
      string sym = OrderSymbol();
      double lots = OrderLots();
      
      bool result = false;
      
      if(type == OP_BUY)
      {
         RefreshRates();
         result = OrderClose(ticket, lots, Bid, Config_GetSlippage(), clrRed);
      }
      else if(type == OP_SELL)
      {
         RefreshRates();
         result = OrderClose(ticket, lots, Ask, Config_GetSlippage(), clrRed);
      }
      else if(type == OP_BUYLIMIT || type == OP_SELLLIMIT || 
              type == OP_BUYSTOP || type == OP_SELLSTOP)
      {
         result = OrderDelete(ticket);
      }
      
      if(result)
      {
         closed++;
         Print("KILL SWITCH: Closed #", ticket, " ", sym);
      }
      else
      {
         failed++;
         Print("KILL SWITCH: Failed to close #", ticket, " error: ", GetLastError());
      }
   }
   
   string msg = "KILL SWITCH EXECUTED\n\n";
   msg += "Closed: " + IntegerToString(closed) + " positions\n";
   if(failed > 0)
      msg += "Failed: " + IntegerToString(failed) + " positions\n";
   
   msg += "\nCooldown will be applied based on realized P/L.";
   
   MessageBox(msg, "Kill Switch", MB_OK | MB_ICONINFORMATION);
   
   return closed;
}
//+------------------------------------------------------------------+