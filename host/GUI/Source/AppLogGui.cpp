#include "AppLog.h"
#include "imgui.h"

namespace AppLog
{
  void render()
  {
    ImGui::BeginChild("Bottom", ImVec2(0, 0), ImGuiChildFlags_Border);
    ImGui::SeparatorText("Activity log");
    log.render();
    ImGui::EndChild();
  }
}
