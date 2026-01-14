//+------------------------------------------------------------------+
//| TF_GUI.mqh                                                       |
//| Main GUI coordinator - includes all GUI modules                  |
//+------------------------------------------------------------------+
#property strict

// Include all GUI modules
#include "TF_GUI_Core.mqh"
#include "TF_GUI_Panel.mqh"
#include "TF_GUI_Lines.mqh"
#include "TF_GUI_Positions.mqh"

// Note: All GUI functions are now available through the included modules:
//
// From TF_GUI_Core.mqh:
//   - GUI_GetPrefix(), GUI_PFX
//   - GUI_ToIntSafe(), GUI_ToDoubleSafe()
//   - GUI_GetEditText(), GUI_SetEditText()
//   - GUI_CreatePanelBG(), GUI_CreateLabel(), GUI_CreateButton(), GUI_CreateEdit()
//   - GUI_Cleanup()
//
// From TF_GUI_Panel.mqh:
//   - GUI_DrawPanel()
//   - GUI_UpdateStatus()
//   - GUI_UpdateCalculations()
//
// From TF_GUI_Lines.mqh:
//   - GUI_DrawSLLines()
//
// From TF_GUI_Positions.mqh:
//   - GUI_ShowPositionsMonitor()
//   - GUI_HidePositionsMonitor()
//   - GUI_HandlePositionButton()
//+------------------------------------------------------------------+
