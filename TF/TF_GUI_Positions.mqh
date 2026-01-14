//+------------------------------------------------------------------+
//| TF_GUI_Positions.mqh                                             |
//| Positions monitor with per-position management                   |
//+------------------------------------------------------------------+
#property strict

// Per-position mode tracking (stored in GlobalVariables for persistence)
// Mode: 0 = NONE, 1 = BE, 2 = SMART

//+------------------------------------------------------------------+
//| Get position mode from GlobalVariables                           |
//+------------------------------------------------------------------+
int GUI_GetPositionMode(int ticket)
{
   string key = "TF_PosMode_" + IntegerToString(ticket);
   if(!GlobalVariableCheck(key)) return 0; // NONE by default
   return (int)GlobalVariableGet(key);
}

//+------------------------------------------------------------------+
//| Set position mode in GlobalVariables                             |
//+------------------------------------------------------------------+
void GUI_SetPositionMode(int ticket, int mode)
{
   string key = "TF_PosMode_" + IntegerToString(ticket);
   GlobalVariableSet(key, (double)mode);
}

//+------------------------------------------------------------------+
//| Clean up mode tracking for closed position                       |
//+------------------------------------------------------------------+
void GUI_CleanupPositionMode(int ticket)
{
   string key = "TF_PosMode_" + IntegerToString(ticket);
   if(GlobalVariableCheck(key))
      GlobalVariableDel(key);
}

//+------------------------------------------------------------------+
//| Count position modes for display                                |
//+------------------------------------------------------------------+
void GUI_CountPositionModes(int &noneCount, int &beCount, int &smartCount)
{
   noneCount = 0;
   beCount = 0;
   smartCount = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;

      int posMode = GUI_GetPositionMode(OrderTicket());
      if(posMode == 1) beCount++;
      else if(posMode == 2) smartCount++;
      else noneCount++;
   }
}

//+------------------------------------------------------------------+
//| Display open positions monitor                                   |
//+------------------------------------------------------------------+
void GUI_ShowPositionsMonitor(bool showPositions)
{
   // Dummy comment to mark change.
   if(!showPositions) return;

   int X = 5, Y = 365;  // Below main panel
   int W = 700;  // Wider to fit all buttons
   int rowH = 70;

   int posCount = 0;
   for(int i=0; i<OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;

      string sym = OrderSymbol();
      int ticket = OrderTicket();
      double lots = OrderLots();
      double openPrice = OrderOpenPrice();
      double sl = OrderStopLoss();
      double tp = OrderTakeProfit();
      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      double pip = RiskCalc_PipSize(sym);
      double vpp = RiskCalc_ValuePerPipPerLot(sym);
      int digits = (int)MarketInfo(sym, MODE_DIGITS);

      // Position box background
      string boxName = "POS_BOX_" + IntegerToString(ticket);
      int posY = Y + (posCount * rowH);

      GUI_CreatePanelBG(boxName, X, posY, W, rowH-5);

      // Position info labels
      color profitColor = (profit >= 0) ? clrLime : clrRed;
      string profitSign = (profit >= 0) ? "+" : "";

      string typeStr = (type == OP_BUY) ? "BUY" : "SELL";
      string info = "#" + IntegerToString(ticket) + " " + typeStr + " " + sym + " " + DoubleToString(lots, 2) + " lots";

      GUI_CreateLabel("POS_INFO_" + IntegerToString(ticket), X+10, posY+8, info, 9);
      GUI_CreateLabel("POS_ENTRY_" + IntegerToString(ticket), X+10, posY+25,
                      "Entry: " + DoubleToString(openPrice, digits) +
                      "  SL: " + DoubleToString(sl, digits) +
                      "  TP: " + (tp > 0 ? DoubleToString(tp, digits) : "none"), 8);

      // Profit display
      GUI_CreateLabel("POS_PL_" + IntegerToString(ticket), X+10, posY+40,
                      "P/L: " + profitSign + DoubleToString(profit, 2) + " " + AccountCurrency(), 9);
      ObjectSetInteger(0, GUI_PFX + "POS_PL_" + IntegerToString(ticket), OBJPROP_COLOR, profitColor);

      double slPips = 0.0;
      double tpPips = 0.0;
      if(pip > 0)
      {
         if(sl > 0)
         {
            if(type == OP_BUY)
               slPips = (sl - openPrice) / pip;
            else
               slPips = (openPrice - sl) / pip;
         }

         if(tp > 0)
         {
            if(type == OP_BUY)
               tpPips = (tp - openPrice) / pip;
            else
               tpPips = (openPrice - tp) / pip;
         }
      }

      double slMoney = slPips * vpp * lots;
      double tpMoney = tpPips * vpp * lots;

      string slMoneyTxt = "SL: " + DoubleToString(slMoney, 2) + " " + AccountCurrency();
      string tpMoneyTxt = "TP: " + DoubleToString(tpMoney, 2) + " " + AccountCurrency();

      GUI_CreateLabel("POS_SL_MONEY_" + IntegerToString(ticket), X+120, posY+40, slMoneyTxt, 8);
      GUI_CreateLabel("POS_TP_MONEY_" + IntegerToString(ticket), X+230, posY+40, tpMoneyTxt, 8);

      color slColor = (slMoney >= 0) ? clrLimeGreen : clrRed;
      color tpColor = (tpMoney >= 0) ? clrLimeGreen : clrRed;
      ObjectSetInteger(0, GUI_PFX + "POS_SL_MONEY_" + IntegerToString(ticket), OBJPROP_COLOR, slColor);
      ObjectSetInteger(0, GUI_PFX + "POS_TP_MONEY_" + IntegerToString(ticket), OBJPROP_COLOR, tpColor);

      // Get current mode for this position
      int posMode = GUI_GetPositionMode(ticket);

      // Action buttons for this position
      // Row 1: CLOSE | NONE | BE | SMART
      GUI_CreateButton("POS_CLOSE_" + IntegerToString(ticket), X+350, posY+8, 60, 20, "CLOSE");
      ObjectSetInteger(0, GUI_PFX + "POS_CLOSE_" + IntegerToString(ticket), OBJPROP_BGCOLOR, clrMaroon);
      ObjectSetInteger(0, GUI_PFX + "POS_CLOSE_" + IntegerToString(ticket), OBJPROP_COLOR, clrWhite);

      // Mode buttons (bistable)
      GUI_CreateButton("POS_NONE_" + IntegerToString(ticket), X+420, posY+8, 60, 20, "NONE");
      GUI_CreateButton("POS_BE_" + IntegerToString(ticket), X+490, posY+8, 50, 20, "BE");
      GUI_CreateButton("POS_SMART_" + IntegerToString(ticket), X+550, posY+8, 70, 20, "SMART");

      // Row 2: TRAIL button
      GUI_CreateButton("POS_TRAIL_" + IntegerToString(ticket), X+350, posY+35, 60, 20, "TRAIL");

      // Set active state based on current mode
      ObjectSetInteger(0, GUI_PFX + "POS_NONE_" + IntegerToString(ticket), OBJPROP_STATE, (posMode == 0));
      ObjectSetInteger(0, GUI_PFX + "POS_BE_" + IntegerToString(ticket), OBJPROP_STATE, (posMode == 1));
      ObjectSetInteger(0, GUI_PFX + "POS_SMART_" + IntegerToString(ticket), OBJPROP_STATE, (posMode == 2));

      // Color active button
      if(posMode == 0)
      {
         ObjectSetInteger(0, GUI_PFX + "POS_NONE_" + IntegerToString(ticket), OBJPROP_BGCOLOR, clrGray);
      }
      else if(posMode == 1)
      {
         ObjectSetInteger(0, GUI_PFX + "POS_BE_" + IntegerToString(ticket), OBJPROP_BGCOLOR, clrDodgerBlue);
         ObjectSetInteger(0, GUI_PFX + "POS_BE_" + IntegerToString(ticket), OBJPROP_COLOR, clrWhite);
      }
      else if(posMode == 2)
      {
         ObjectSetInteger(0, GUI_PFX + "POS_SMART_" + IntegerToString(ticket), OBJPROP_BGCOLOR, clrLimeGreen);
         ObjectSetInteger(0, GUI_PFX + "POS_SMART_" + IntegerToString(ticket), OBJPROP_COLOR, clrWhite);
      }

      posCount++;
      if(posCount >= 5) break;  // Max 5 positions displayed
   }

   if(posCount == 0)
   {
      GUI_CreateLabel("POS_NONE", X+10, Y+10, "No open positions", 10);
   }
}

//+------------------------------------------------------------------+
//| Hide positions monitor                                           |
//+------------------------------------------------------------------+
void GUI_HidePositionsMonitor()
{
   // Delete all position-related objects
   for(int i=ObjectsTotal(0, 0, -1)-1; i>=0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, GUI_PFX + "POS_") == 0)
      {
         ObjectDelete(0, name);
      }
   }
}

//+------------------------------------------------------------------+
//| Handle position button clicks                                    |
//+------------------------------------------------------------------+
int GUI_HandlePositionButton(string sparam)
{
   // Extract ticket number from button name
   // Format: TFP_POS_CLOSE_12345 or TFP_POS_BE_12345

   if(StringFind(sparam, GUI_PFX + "POS_CLOSE_") == 0)
   {
      string ticketStr = StringSubstr(sparam, StringLen(GUI_PFX + "POS_CLOSE_"));
      int ticket = (int)StrToInteger(ticketStr);

      if(OrderSelect(ticket, SELECT_BY_TICKET))
      {
         bool result = false;
         if(OrderType() == OP_BUY)
            result = OrderClose(ticket, OrderLots(), Bid, Config_GetSlippage(), clrRed);
         else if(OrderType() == OP_SELL)
            result = OrderClose(ticket, OrderLots(), Ask, Config_GetSlippage(), clrRed);

         if(result)
         {
            Print("Closed position #", ticket);
            GUI_CleanupPositionMode(ticket);  // Clean up mode tracking
         }
         else
            Print("Failed to close #", ticket, " error: ", GetLastError());
      }
      return ticket;
   }

   if(StringFind(sparam, GUI_PFX + "POS_NONE_") == 0)
   {
      string ticketStr = StringSubstr(sparam, StringLen(GUI_PFX + "POS_NONE_"));
      int ticket = (int)StrToInteger(ticketStr);

      GUI_SetPositionMode(ticket, 0);  // Set to NONE mode
      Print("Position #", ticket, " → NONE mode (manual control)");
      return ticket;
   }

   if(StringFind(sparam, GUI_PFX + "POS_BE_") == 0)
   {
      string ticketStr = StringSubstr(sparam, StringLen(GUI_PFX + "POS_BE_"));
      int ticket = (int)StrToInteger(ticketStr);

      GUI_SetPositionMode(ticket, 1);  // Set to BE mode
      Print("Position #", ticket, " → BE mode (automatic break even)");
      return ticket;
   }

   if(StringFind(sparam, GUI_PFX + "POS_SMART_") == 0)
   {
      string ticketStr = StringSubstr(sparam, StringLen(GUI_PFX + "POS_SMART_"));
      int ticket = (int)StrToInteger(ticketStr);

      GUI_SetPositionMode(ticket, 2);  // Set to SMART mode
      Print("Position #", ticket, " → SMART SL mode (60% profit lock)");
      return ticket;
   }

   if(StringFind(sparam, GUI_PFX + "POS_TRAIL_") == 0)
   {
      string ticketStr = StringSubstr(sparam, StringLen(GUI_PFX + "POS_TRAIL_"));
      int ticket = (int)StrToInteger(ticketStr);

      if(OrderSelect(ticket, SELECT_BY_TICKET))
      {
         string sym = OrderSymbol();
         double pip = RiskCalc_PipSize(sym);
         int digits = (int)MarketInfo(sym, MODE_DIGITS);

         RefreshRates();
         double currentPrice = (OrderType() == OP_BUY) ? Bid : Ask;
         double currentSL = OrderStopLoss();

         if(currentSL == 0)
         {
            Print("Trailing stop #", ticket, ": No SL set, cannot trail");
            return ticket;
         }

         // Calculate CURRENT distance from price to SL
         // This is the trailing distance we'll maintain
         double trailDistance = MathAbs(currentPrice - currentSL);
         int trailDistancePips = (int)MathRound(trailDistance / pip);

         // Move SL to maintain this distance from NEW price position
         double newSL = 0;
         bool shouldUpdate = false;

         if(OrderType() == OP_BUY)
         {
            // For BUY: Keep SL below current price by the trailing distance
            newSL = currentPrice - trailDistance;
            // Only move SL up (never down)
            if(newSL > currentSL)
               shouldUpdate = true;
         }
         else if(OrderType() == OP_SELL)
         {
            // For SELL: Keep SL above current price by the trailing distance
            newSL = currentPrice + trailDistance;
            // Only move SL down (never up)
            if(newSL < currentSL)
               shouldUpdate = true;
         }

         if(shouldUpdate)
         {
            bool result = OrderModify(ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrGreen);

            if(result)
               Print("Trailed #", ticket, " → SL: ", DoubleToString(newSL, digits),
                     " (", trailDistancePips, "p behind price)");
            else
               Print("Failed to trail #", ticket, " error: ", GetLastError());
         }
         else
         {
            Print("Trail #", ticket, ": price hasn't moved favorably yet (",
                  trailDistancePips, "p distance maintained)");
         }
      }
      return ticket;
   }

   return -1;
}
//+------------------------------------------------------------------+
