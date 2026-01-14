//+------------------------------------------------------------------+
//| TF_GUI_Lines.mqh                                                 |
//| Visual SL/TP/Target lines on chart                               |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Draw SL and Target lines on chart based on current inputs        |
//+------------------------------------------------------------------+
void GUI_DrawSLLines()
{
   string sym = Symbol();
   int digits = (int)MarketInfo(sym, MODE_DIGITS);
   
   // Get inputs
   int slPips = GUI_ToIntSafe(GUI_GetEditText("SL"), Config_GetDefaultSL());
   int tpPips = GUI_ToIntSafe(GUI_GetEditText("TP"), Config_GetDefaultTP());
   double targetPrice = GUI_ToDoubleSafe(GUI_GetEditText("PX"), Config_GetDefaultTargetPrice());
   
   if(slPips <= 0) 
   {
      // Remove all lines
      ObjectDelete(0, GUI_PFX + "SL_BUY");
      ObjectDelete(0, GUI_PFX + "SL_SELL");
      ObjectDelete(0, GUI_PFX + "TP_BUY");
      ObjectDelete(0, GUI_PFX + "TP_SELL");
      ObjectDelete(0, GUI_PFX + "TARGET");
      return;
   }
   
   int spreadPips = RiskCalc_SpreadPips(sym);
   
   // If spread >= SL, don't draw lines (invalid setup)
   if(spreadPips >= slPips)
   {
      ObjectDelete(0, GUI_PFX + "SL_BUY");
      ObjectDelete(0, GUI_PFX + "SL_SELL");
      ObjectDelete(0, GUI_PFX + "TP_BUY");
      ObjectDelete(0, GUI_PFX + "TP_SELL");
      ObjectDelete(0, GUI_PFX + "TARGET");
      return;
   }
   
   RefreshRates();
   double ask = Ask;
   double bid = Bid;
   double pip = RiskCalc_PipSize(sym);
   
   int slToPricePips = slPips - spreadPips;
   
   // Calculate entry prices
   double buyEntry = (targetPrice > 0) ? targetPrice : ask;
   double sellEntry = (targetPrice > 0) ? targetPrice : bid;
   
   // Calculate SL prices
   double slBuyPrice = buyEntry - (slToPricePips * pip);
   double slSellPrice = sellEntry + (slToPricePips * pip);
   
   // BUY SL Line
   string buyLineName = GUI_PFX + "SL_BUY";
   if(ObjectFind(0, buyLineName) == -1)
   {
      if(!ObjectCreate(0, buyLineName, OBJ_HLINE, 0, 0, slBuyPrice))
      {
         return;
      }
   }
      
   ObjectSetDouble(0, buyLineName, OBJPROP_PRICE, slBuyPrice);
   ObjectSetInteger(0, buyLineName, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, buyLineName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, buyLineName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, buyLineName, OBJPROP_BACK, true);
   ObjectSetInteger(0, buyLineName, OBJPROP_SELECTABLE, false);
   ObjectSetString(0, buyLineName, OBJPROP_TEXT, "BUY SL");
   ObjectSetString(0, buyLineName, OBJPROP_TOOLTIP, "BUY Stop Loss: " + DoubleToString(slBuyPrice, digits) + 
                  " (" + IntegerToString(slToPricePips) + "p from entry)");
   
   // SELL SL Line
   string sellLineName = GUI_PFX + "SL_SELL";
   if(ObjectFind(0, sellLineName) == -1)
   {
      if(!ObjectCreate(0, sellLineName, OBJ_HLINE, 0, 0, slSellPrice))
      {
         return;
      }
   }
      
   ObjectSetDouble(0, sellLineName, OBJPROP_PRICE, slSellPrice);
   ObjectSetInteger(0, sellLineName, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, sellLineName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, sellLineName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, sellLineName, OBJPROP_BACK, true);
   ObjectSetInteger(0, sellLineName, OBJPROP_SELECTABLE, false);
   ObjectSetString(0, sellLineName, OBJPROP_TEXT, "SELL SL");
   ObjectSetString(0, sellLineName, OBJPROP_TOOLTIP, "SELL Stop Loss: " + DoubleToString(slSellPrice, digits) + 
                  " (" + IntegerToString(slToPricePips) + "p from entry)");
   
   // TP Lines (if TP is set)
   if(tpPips > 0)
   {
      double tpBuyPrice = buyEntry + (tpPips * pip);
      double tpSellPrice = sellEntry - (tpPips * pip);
      
      // BUY TP Line
      string buyTPName = GUI_PFX + "TP_BUY";
      if(ObjectFind(0, buyTPName) == -1)
      {
         if(!ObjectCreate(0, buyTPName, OBJ_HLINE, 0, 0, tpBuyPrice))
         {
            return;
         }
      }
         
      ObjectSetDouble(0, buyTPName, OBJPROP_PRICE, tpBuyPrice);
      ObjectSetInteger(0, buyTPName, OBJPROP_COLOR, clrLimeGreen);
      ObjectSetInteger(0, buyTPName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, buyTPName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, buyTPName, OBJPROP_BACK, true);
      ObjectSetInteger(0, buyTPName, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, buyTPName, OBJPROP_TEXT, "BUY TP");
      ObjectSetString(0, buyTPName, OBJPROP_TOOLTIP, "BUY Take Profit: " + DoubleToString(tpBuyPrice, digits) + 
                     " (" + IntegerToString(tpPips) + "p from entry)");
      
      // SELL TP Line
      string sellTPName = GUI_PFX + "TP_SELL";
      if(ObjectFind(0, sellTPName) == -1)
      {
         if(!ObjectCreate(0, sellTPName, OBJ_HLINE, 0, 0, tpSellPrice))
         {
            return;
         }
      }
         
      ObjectSetDouble(0, sellTPName, OBJPROP_PRICE, tpSellPrice);
      ObjectSetInteger(0, sellTPName, OBJPROP_COLOR, clrLimeGreen);
      ObjectSetInteger(0, sellTPName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, sellTPName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, sellTPName, OBJPROP_BACK, true);
      ObjectSetInteger(0, sellTPName, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, sellTPName, OBJPROP_TEXT, "SELL TP");
      ObjectSetString(0, sellTPName, OBJPROP_TOOLTIP, "SELL Take Profit: " + DoubleToString(tpSellPrice, digits) + 
                     " (" + IntegerToString(tpPips) + "p from entry)");
   }
   else
   {
      ObjectDelete(0, GUI_PFX + "TP_BUY");
      ObjectDelete(0, GUI_PFX + "TP_SELL");
   }
   
   // Target Entry Line (if target price is set)
   if(targetPrice > 0)
   {
      string targetLineName = GUI_PFX + "TARGET";
      if(ObjectFind(0, targetLineName) == -1)
      {
         if(!ObjectCreate(0, targetLineName, OBJ_HLINE, 0, 0, targetPrice))
         {
            return;
         }
      }
         
      ObjectSetDouble(0, targetLineName, OBJPROP_PRICE, targetPrice);
      ObjectSetInteger(0, targetLineName, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, targetLineName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, targetLineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, targetLineName, OBJPROP_BACK, true);
      ObjectSetInteger(0, targetLineName, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, targetLineName, OBJPROP_TEXT, "Target Entry");
      ObjectSetString(0, targetLineName, OBJPROP_TOOLTIP, "Target Entry Price: " + DoubleToString(targetPrice, digits));
   }
   else
   {
      ObjectDelete(0, GUI_PFX + "TARGET");
   }
   
   ChartRedraw(0);
}
//+------------------------------------------------------------------+
