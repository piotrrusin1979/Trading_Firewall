//+------------------------------------------------------------------+
//| TF_GUI_Core.mqh                                                  |
//| Core GUI functions - helpers, object creation, utilities         |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Get chart-specific prefix to avoid conflicts                     |
//+------------------------------------------------------------------+
string GUI_GetPrefix()
{
   static string prefix = "";
   if(prefix == "")
   {
      prefix = "TFP_" + IntegerToString(ChartID()) + "_";
   }
   return prefix;
}

// For convenience
#define GUI_PFX GUI_GetPrefix()

//+------------------------------------------------------------------+
//| GUI Helper Functions                                             |
//+------------------------------------------------------------------+
string GUI_PriceStr(double p, int digits) 
{ 
   return DoubleToString(p, digits); 
}

int GUI_ToIntSafe(string s, int defVal)
{
   s = StringTrimLeft(StringTrimRight(s));
   if(StringLen(s) == 0) return defVal;
   return (int)StrToInteger(s);
}

double GUI_ToDoubleSafe(string s, double defVal)
{
   s = StringTrimLeft(StringTrimRight(s));
   if(StringLen(s) == 0) return defVal;
   
   // Replace comma with dot for decimal separator
   StringReplace(s, ",", ".");
   
   // Convert to double
   double result = StrToDouble(s);
   
   // If StrToDouble returns 0, try treating it as integer first
   if(result == 0.0 && s != "0" && s != "0.0")
   {
      // Might be an integer like "5400"
      result = (double)StrToInteger(s);
   }
   
   return result;
}

string GUI_GetEditText(string name)
{
   string obj = GUI_PFX + name;
   long chartID = ChartID();
   int findResult = ObjectFind(chartID, obj);
   
   if(findResult == -1)
   {
      return "";
   }
   
   string text = ObjectGetString(chartID, obj, OBJPROP_TEXT);
   return text;
}

void GUI_SetEditText(string name, string value)
{
   string obj = GUI_PFX + name;
   long chartID = ChartID();
   int findResult = ObjectFind(chartID, obj);
   
   if(findResult == -1)
   {
      return;
   }
   
   ObjectSetString(chartID, obj, OBJPROP_TEXT, value);
}

//+------------------------------------------------------------------+
//| Create panel background                                          |
//+------------------------------------------------------------------+
void GUI_CreatePanelBG(string name, int x, int y, int w, int h)
{
   string bg1 = GUI_PFX + name + "_1";
   if(ObjectFind(0, bg1) == -1)
      ObjectCreate(0, bg1, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, bg1, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bg1, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, bg1, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, bg1, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, bg1, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, bg1, OBJPROP_BACK, false);           // Draw in FOREGROUND
   ObjectSetInteger(0, bg1, OBJPROP_COLOR, clrWhite);       // White border
   ObjectSetInteger(0, bg1, OBJPROP_BGCOLOR, clrBlack);     // Black background
   ObjectSetInteger(0, bg1, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bg1, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, bg1, OBJPROP_STYLE, STYLE_SOLID);

   string bg2 = GUI_PFX + name + "_2";
   if(ObjectFind(0, bg2) == -1)
      ObjectCreate(0, bg2, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, bg2, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bg2, OBJPROP_XDISTANCE, x+1);
   ObjectSetInteger(0, bg2, OBJPROP_YDISTANCE, y+1);
   ObjectSetInteger(0, bg2, OBJPROP_XSIZE, w-2);
   ObjectSetInteger(0, bg2, OBJPROP_YSIZE, h-2);
   ObjectSetInteger(0, bg2, OBJPROP_BACK, false);           // Draw in FOREGROUND
   ObjectSetInteger(0, bg2, OBJPROP_COLOR, clrBlack);       // No border
   ObjectSetInteger(0, bg2, OBJPROP_BGCOLOR, clrBlack);     // Black background
   ObjectSetInteger(0, bg2, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bg2, OBJPROP_STYLE, STYLE_SOLID);
}

//+------------------------------------------------------------------+
//| Create label                                                     |
//+------------------------------------------------------------------+
void GUI_CreateLabel(string name, int x, int y, string text, int size=9)
{
   string obj = GUI_PFX + name;
   if(ObjectFind(0, obj) == -1)
      ObjectCreate(0, obj, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, obj, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, obj, OBJPROP_COLOR, clrWhite);  // Ensure white text
   ObjectSetInteger(0, obj, OBJPROP_BACK, false);      // Draw in foreground
   ObjectSetString(0, obj, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| Create button                                                    |
//+------------------------------------------------------------------+
void GUI_CreateButton(string name, int x, int y, int w, int h, string text)
{
   string obj = GUI_PFX + name;
   if(ObjectFind(0, obj) == -1)
      ObjectCreate(0, obj, OBJ_BUTTON, 0, 0, 0);

   ObjectSetInteger(0, obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, obj, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, obj, OBJPROP_YSIZE, h);
   ObjectSetString(0, obj, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| Create edit field                                                |
//+------------------------------------------------------------------+
void GUI_CreateEdit(string name, int x, int y, int w, int h, string text)
{
   string obj = GUI_PFX + name;
   if(ObjectFind(0, obj) == -1)
      ObjectCreate(0, obj, OBJ_EDIT, 0, 0, 0);

   ObjectSetInteger(0, obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, obj, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, obj, OBJPROP_YSIZE, h);
   ObjectSetString(0, obj, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| Cleanup all GUI objects                                          |
//+------------------------------------------------------------------+
void GUI_Cleanup()
{
   // Delete all objects with our prefix (more robust than listing individually)
   string prefix = GUI_PFX;
   
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, prefix) == 0)
      {
         ObjectDelete(0, name);
      }
   }
   
   // Also delete non-prefixed objects we might have created
   ObjectDelete(0, "ENTRY_CAPTURE_LINE");
}
//+------------------------------------------------------------------+