#include <string>

#include "imgui.h"
#include "IconsFontAwesome6.h"

#include "Log.h"

ImColor LogColors[LogTypes_Count] = {
    ImColor(229, 229, 229, 255), // none / white
    ImColor(214, 112, 214, 255), // section / magenta
    ImColor(17, 168, 205, 255),  // info / blue
    ImColor(13, 188, 121, 255),  // success / green
    ImColor(229, 229, 16, 255),  // warning / yellow
    ImColor(205, 49, 49, 255),   // error / red
    ImColor(17, 168, 205, 255),  // point / blue
    ImColor(17, 168, 205, 255),  // bullet / blue
};

const char *LogSymbols[LogTypes_Count] = {
    "  ",                         // none
    ICON_FA_MINUS,                // section
    ICON_FA_INFO,                 // info
    ICON_FA_CHECK,                // success
    ICON_FA_TRIANGLE_EXCLAMATION, // warning
    ICON_FA_XMARK,                // error
    ICON_FA_CARET_RIGHT,          // point
    ICON_FA_CIRCLE,               // bullet
};

void Log::render()
{
  static bool autoScroll = true;
  static bool scrollToBottom = false;
  bool copyToClipboard = false;

  // Reserve enough left-over height for 1 separator + 1 input text
  // const float footer_height_to_reserve = ImGui::GetStyle().ItemSpacing.y + ImGui::GetFrameHeightWithSpacing();
  // const float footer_height_to_reserve = ImGui::GetFrameHeightWithSpacing();
  if (ImGui::BeginChild("Log", ImVec2(-1, -1), false, ImGuiWindowFlags_HorizontalScrollbar))
  {
    if (ImGui::BeginPopupContextWindow())
    {
      if (ImGui::Selectable("Copy"))
        copyToClipboard = true;
      if (ImGui::Selectable("Clear"))
        Items.clear();
      ImGui::EndPopup();
    }

    // Display every line as a separate entry so we can change their color or add custom widgets.
    // If you only want raw text you can use ImGui::TextUnformatted(log.begin(), log.end());
    // NB- if you have thousands of entries this approach may be too inefficient and may require user-side clipping
    // to only process visible items. The clipper will automatically measure the height of your first item and then
    // "seek" to display only items in the visible area.
    // To use the clipper we can replace your standard loop:
    //      for (int i = 0; i < Items.Size; i++)
    //   With:
    //      ImGuiListClipper clipper;
    //      clipper.Begin(Items.Size);
    //      while (clipper.Step())
    //         for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; i++)
    // - That your items are evenly spaced (same height)
    // - That you have cheap random access to your elements (you can access them given their index,
    //   without processing all the ones before)
    // You cannot this code as-is if a filter is active because it breaks the 'cheap random-access' property.
    // We would need random-access on the post-filtered list.
    // A typical application wanting coarse clipping and filtering may want to pre-compute an array of indices
    // or offsets of items that passed the filtering test, recomputing this array when user changes the filter,
    // and appending newly elements as they are inserted. This is left as a task to the user until we can manage
    // to improve this example code!
    // If your items are of variable height:
    // - Split them into same height items would be simpler and facilitate random-seeking into your list.
    // - Consider using manual call to IsRectVisible() and skipping extraneous decoration from your items.
    ImGui::PushStyleVar(ImGuiStyleVar_ItemSpacing, ImVec2(4, 1)); // Tighten spacing

    if (copyToClipboard)
      ImGui::LogToClipboard();

    // make a safe copy of Items
    std::vector<LogMessage> ItemsCopy = getCopy();

    for (const LogMessage item : ItemsCopy)
    {
      ImVec4 color = LogColors[item.type];
      ImGui::PushStyleColor(ImGuiCol_Text, color);
      ImGui::TextUnformatted(LogSymbols[item.type]);
      ImGui::SameLine();
      ImGui::TextUnformatted(item.message.c_str());
      ImGui::PopStyleColor();
    }

    if (copyToClipboard)
      ImGui::LogFinish();

    if (showSpinner)
    {
      ImDrawList *draw_list = ImGui::GetWindowDrawList();
      ImVec2 pos = ImGui::GetCursorScreenPos();
      ImGuiStyle &style = ImGui::GetStyle();

      ImVec2 start_pos = ImVec2(pos.x, pos.y);
      ImVec2 end_pos = ImVec2(pos.x + ImGui::GetWindowWidth(), pos.y + ImGui::GetTextLineHeight() + style.FramePadding.y);
      draw_list->AddRectFilled(start_pos, end_pos, IM_COL32(229, 229, 229, 255));
      ImVec4 color = ImColor(0, 0, 0, 255);
      ImGui::PushStyleColor(ImGuiCol_Text, color);
      float windowWidth = ImGui::GetWindowSize().x;
      float textWidth = ImGui::CalcTextSize(spinner).x;

      ImGui::SetCursorPosX((windowWidth - textWidth) * 0.5f);
      ImGui::TextUnformatted(spinner);
      ImGui::PopStyleColor();
    }

    // Keep up at the bottom of the scroll region if we were already at the bottom at the beginning of the frame.
    // Using a scrollbar or mouse-wheel will take away from the bottom edge.
    if (scrollToBottom || (autoScroll && ImGui::GetScrollY() >= ImGui::GetScrollMaxY()))
      ImGui::SetScrollHereY(1.0f);
    scrollToBottom = false;

    ImGui::PopStyleVar();
  }
  ImGui::EndChild();
}
