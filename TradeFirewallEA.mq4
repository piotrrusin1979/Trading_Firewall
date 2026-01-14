//+------------------------------------------------------------------+
//| TradeFirewallEA.mq4                                              |
//| Main EA file - coordinates all modules                           |
//+------------------------------------------------------------------+
#property strict

// Include all module files (from MQL4/Include/TF directory)
#include <TF\TF_Config.mqh>
#include <TF\TF_TimeUtils.mqh>
#include <TF\TF_TimeTracking.mqh>
#include <TF\TF_TradeStats.mqh>
#include <TF\TF_RiskCalculator.mqh>
#include <TF\TF_RuleEngine.mqh>
#include <TF\TF_CooldownPersistence.mqh>
#include <TF\TF_TradeTiming.mqh>
#include <TF\TF_TradeLogger.mqh>
#include <TF\TF_GUI.mqh>
#include <TF\TF_TradeExecutor.mqh>
#include <TF\TF_BreakEven.mqh>
#include <TF\TF_SmartSL.mqh>

// Global state
bool g_manualLock = false;
bool g_showPositions = false;  // Positions monitor toggle
datetime g_dayStart = 0;
datetime g_weekStart = 0;

// Click-to-capture mode
bool g_captureEntryMode = false;
bool g_captureSLMode = false;
bool g_captureTPMode = false;

// Cooldown tracking
datetime g_cooldownUntil = 0;
string g_cooldownReason = "";
int g_cooldownReasonCode = 0;
double g_cooldownReasonValue = 0.0;
bool g_bigWinToday = false;

// Persistent input values across timeframe changes
string g_savedSL = "";
string g_savedTP = "";
string g_savedPX = "";
bool g_inputsSaved = false;
int g_timerCounter = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   TimeUtils_ResetDayWeek(g_dayStart, g_weekStart);
   CooldownPersistence_Load(g_cooldownUntil, g_cooldownReason, g_cooldownReasonCode,
                            g_cooldownReasonValue, g_bigWinToday);
   
   TimeTracking_Init();  // Initialize time tracking
   TradeLogger_InitFile();
   
   GUI_DrawPanel();
   GUI_DrawSLLines();  // Draw initial SL/TP lines
   
   // Restore saved inputs after timeframe change
   if(g_inputsSaved)
   {
      GUI_SetEditText("SL", g_savedSL);
      GUI_SetEditText("TP", g_savedTP);
      GUI_SetEditText("PX", g_savedPX);
      g_inputsSaved = false;
      
      // Update display immediately
      GUI_UpdateStatus(g_dayStart, g_weekStart, g_manualLock, g_cooldownUntil, g_cooldownReason);
      GUI_DrawSLLines();  // Redraw with restored inputs
   }
   
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Save input values before cleanup (for timeframe changes)
   if(reason == REASON_CHARTCHANGE)
   {
      g_savedSL = GUI_GetEditText("SL");
      g_savedTP = GUI_GetEditText("TP");
      g_savedPX = GUI_GetEditText("PX");
      g_inputsSaved = true;
   }
   
   TimeTracking_Deinit();  // Save time tracking data
   CooldownPersistence_Save(g_cooldownUntil, g_cooldownReason, g_cooldownReasonCode,
                            g_cooldownReasonValue, g_bigWinToday);
   EventKillTimer();
   GUI_Cleanup();
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   g_timerCounter++;

   // Check if day/week changed - reset cooldowns on new day
   if(TimeUtils_IsNewDay(g_dayStart))
   {
      g_bigWinToday = false;
      g_cooldownUntil = 0;
      g_cooldownReason = "";
      g_cooldownReasonCode = 0;
      g_cooldownReasonValue = 0.0;
      CooldownPersistence_Clear();
   }
   
   // Update time tracking
   TimeTracking_Update();
   
   // Check last closed trade for cooldown
   if(!g_bigWinToday) // Only check if we haven't hit big win yet today
      TradeStats_CheckLastTradeForCooldown(g_dayStart, g_cooldownUntil, g_cooldownReason,
                                           g_cooldownReasonCode, g_cooldownReasonValue, g_bigWinToday);
   
   // Process Break Even for open positions
   BreakEven_ProcessPositions();
   SmartSL_ProcessPositions();

   CooldownPersistence_Update(g_cooldownUntil, g_cooldownReason, g_cooldownReasonCode,
                              g_cooldownReasonValue, g_bigWinToday);
   if(g_timerCounter % 30 == 0)
      TradeLogger_SyncHistory();
   
   // Update SL/TP lines
   GUI_DrawSLLines();
   
   GUI_UpdateStatus(g_dayStart, g_weekStart, g_manualLock, g_cooldownUntil, g_cooldownReason);
   
   // Refresh positions monitor if visible
   if(g_showPositions)
   {
      GUI_HidePositionsMonitor();
      GUI_ShowPositionsMonitor(g_showPositions);
   }
}

//+------------------------------------------------------------------+
//| Tick function                                                    |
//+------------------------------------------------------------------+
void OnTick()
{
   // Timer handles updates
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // Handle keyboard shortcuts - activate capture mode
   if(id == CHARTEVENT_KEYDOWN)
   {
      int key = (int)lparam;
      
      // R key (82) = Reset to defaults
      if(key == 82)
      {
         GUI_SetEditText("SL", IntegerToString(Config_GetDefaultSL()));
         GUI_SetEditText("TP", IntegerToString(Config_GetDefaultTP()));
         GUI_SetEditText("PX", DoubleToString(Config_GetDefaultTargetPrice(), 2));
         
         // Delete capture line
         string lineName = "ENTRY_CAPTURE_LINE";
         if(ObjectFind(0, lineName) >= 0)
            ObjectDelete(0, lineName);
         
         Print("Reset to defaults");
         Comment("");
         ChartRedraw(0);
         GUI_UpdateStatus(g_dayStart, g_weekStart, g_manualLock, g_cooldownUntil, g_cooldownReason);
         return;
      }
      
      // E key (69) = Enter capture mode for Entry
      if(key == 69)
      {
         g_captureEntryMode = true;
         g_captureSLMode = false;
         g_captureTPMode = false;
         Comment(">>> Click on chart to set ENTRY price <<<");
         return;
      }
      
      // S key (83) = Enter capture mode for SL
      if(key == 83)
      {
         string entryStr = GUI_GetEditText("PX");
         double entry = GUI_ToDoubleSafe(entryStr, 0);
         
         if(entry <= 0)
         {
            Print("Set Entry price first (press E)");
            return;
         }
         
         g_captureEntryMode = false;
         g_captureSLMode = true;
         g_captureTPMode = false;
         Comment(">>> Click on chart to set STOP LOSS <<<");
         return;
      }
      
      // T key (84) = Enter capture mode for TP
      if(key == 84)
      {
         string entryStr = GUI_GetEditText("PX");
         double entry = GUI_ToDoubleSafe(entryStr, 0);
         
         if(entry <= 0)
         {
            Print("Set Entry price first (press E)");
            return;
         }
         
         g_captureEntryMode = false;
         g_captureSLMode = false;
         g_captureTPMode = true;
         Comment(">>> Click on chart to set TAKE PROFIT <<<");
         return;
      }
   }
   
   // Handle chart clicks when in capture mode
   if(id == CHARTEVENT_CLICK)
   {
      int x = (int)lparam;
      int y = (int)dparam;
      
      // Get chart info
      int subwin = 0;
      int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, subwin);
      int windowYDistance = (int)ChartGetInteger(0, CHART_WINDOW_YDISTANCE, subwin);
      double priceMax = ChartGetDouble(0, CHART_PRICE_MAX, subwin);
      double priceMin = ChartGetDouble(0, CHART_PRICE_MIN, subwin);
      
      // Calculate chart-relative Y
      int chartRelativeY = y - windowYDistance;
      if(chartRelativeY < 0) chartRelativeY = 0;
      if(chartRelativeY > chartHeight) chartRelativeY = chartHeight;
      
      double priceRange = priceMax - priceMin;
      double yRatio = (double)chartRelativeY / (double)chartHeight;
      double clickedPrice = priceMax - (yRatio * priceRange);
      
      // Handle based on capture mode
      if(g_captureEntryMode)
      {
         GUI_SetEditText("PX", DoubleToString(clickedPrice, Digits));
         Print("Entry: ", DoubleToString(clickedPrice, Digits));
         
         // Draw line in background
         string lineName = "ENTRY_CAPTURE_LINE";
         if(ObjectFind(0, lineName) >= 0) ObjectDelete(0, lineName);
         ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, clickedPrice);
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrYellow);
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, lineName, OBJPROP_BACK, true);  // Draw in background
         ObjectSetString(0, lineName, OBJPROP_TEXT, "Entry");
         
         g_captureEntryMode = false;
         Comment("");
         ChartRedraw(0);
         GUI_UpdateStatus(g_dayStart, g_weekStart, g_manualLock, g_cooldownUntil, g_cooldownReason);
         return;
      }
      
      if(g_captureSLMode)
      {
         string entryStr = GUI_GetEditText("PX");
         double entry = GUI_ToDoubleSafe(entryStr, 0);
         
         double pip = RiskCalc_PipSize(Symbol());
         int slPips = (int)MathRound(MathAbs((entry - clickedPrice) / pip));
         int spread = RiskCalc_SpreadPips(Symbol());
         slPips += spread;
         
         GUI_SetEditText("SL", IntegerToString(slPips));
         Print("SL: ", slPips, "p");
         
         g_captureSLMode = false;
         Comment("");
         ChartRedraw(0);
         GUI_UpdateStatus(g_dayStart, g_weekStart, g_manualLock, g_cooldownUntil, g_cooldownReason);
         return;
      }
      
      if(g_captureTPMode)
      {
         string entryStr = GUI_GetEditText("PX");
         double entry = GUI_ToDoubleSafe(entryStr, 0);
         
         double pip = RiskCalc_PipSize(Symbol());
         int tpPips = (int)MathRound(MathAbs((clickedPrice - entry) / pip));
         
         GUI_SetEditText("TP", IntegerToString(tpPips));
         Print("TP: ", tpPips, "p");
         
         g_captureTPMode = false;
         Comment("");
         ChartRedraw(0);
         GUI_UpdateStatus(g_dayStart, g_weekStart, g_manualLock, g_cooldownUntil, g_cooldownReason);
         return;
      }
   }
   
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == GUI_PFX + "BUY")
      {
         TradeExecutor_PlaceTrade(OP_BUY, g_dayStart, g_weekStart, g_manualLock, g_cooldownUntil, g_cooldownReason);
         // Reset button state (make it non-bistable)
         ObjectSetInteger(0, GUI_PFX + "BUY", OBJPROP_STATE, false);
      }

      if(sparam == GUI_PFX + "SELL")
      {
         TradeExecutor_PlaceTrade(OP_SELL, g_dayStart, g_weekStart, g_manualLock, g_cooldownUntil, g_cooldownReason);
         // Reset button state (make it non-bistable)
         ObjectSetInteger(0, GUI_PFX + "SELL", OBJPROP_STATE, false);
      }

      if(sparam == GUI_PFX + "LOCK")
      {
         g_manualLock = !g_manualLock;
         Print("Manual lock set to: ", (g_manualLock ? "ON" : "OFF"));
         GUI_UpdateStatus(g_dayStart, g_weekStart, g_manualLock, g_cooldownUntil, g_cooldownReason);
      }
      
      if(sparam == GUI_PFX + "KILL")
      {
         // Require confirmation
         int confirm = MessageBox("Close ALL open positions?\n\nThis cannot be undone!", 
                                  "Kill Switch Confirmation", 
                                  MB_YESNO | MB_ICONWARNING | MB_DEFBUTTON2);
         if(confirm == IDYES)
         {
            int closed = TradeExecutor_KillSwitch();
            
            // Cooldown will be automatically applied by OnTimer checking closed trades
            Print("KILL SWITCH activated - ", closed, " positions closed");
         }
         ObjectSetInteger(0, GUI_PFX + "KILL", OBJPROP_STATE, false);
      }
      
      if(sparam == GUI_PFX + "POS")
      {
         g_showPositions = !g_showPositions;
         ObjectSetInteger(0, GUI_PFX + "POS", OBJPROP_STATE, g_showPositions);
         
         if(g_showPositions)
         {
            GUI_ShowPositionsMonitor(g_showPositions);
         }
         else
         {
            GUI_HidePositionsMonitor();
         }
         
         Print("Positions monitor: ", (g_showPositions ? "ON" : "OFF"));
      }
      
      // Handle position-specific buttons (CLOSE, NONE, BE, SMART, TRAIL)
      if(StringFind(sparam, GUI_PFX + "POS_") == 0)
      {
         int ticket = GUI_HandlePositionButton(sparam);
         if(ticket > 0)
         {
            // Refresh display after action
            GUI_HidePositionsMonitor();
            if(g_showPositions)
               GUI_ShowPositionsMonitor(g_showPositions);
         }
      }
   }
   
   // Update SL lines when user edits input fields
   if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      if(sparam == GUI_PFX + "SL" || sparam == GUI_PFX + "TP" || sparam == GUI_PFX + "PX")
      {
         GUI_DrawSLLines();  // Draw SL/TP lines when inputs change
         ChartRedraw(0);
         GUI_UpdateStatus(g_dayStart, g_weekStart, g_manualLock, g_cooldownUntil, g_cooldownReason);
      }
   }
}
//+------------------------------------------------------------------+
