#include "Dialog.h"

namespace Dialog
{

  bool showFileOpen = false;
  bool showFileSave = false;
  std::string fileExt = ".bin";
  imgui_addons::ImGuiFileBrowser file_dialog;
  std::function<void(const std::string &path, const std::string &filename)> callback;

  void render(float scale)
  {
    ImVec2 dialog_size = {700 * scale, 310 * scale};

    // open file dialog
    if (showFileOpen)
      ImGui::OpenPopup("Open File");

    if (file_dialog.showFileDialog("Open File", imgui_addons::ImGuiFileBrowser::DialogMode::OPEN, dialog_size, fileExt))
    {
      // std::cout << file_dialog.selected_fn << std::endl;	 // The name of the selected file or directory in case of Select Directory dialog mode
      // std::cout << file_dialog.selected_path << std::endl; // The absolute path to the selected file
      // printf("%s", file_dialog.selected_path.c_str());
      if (callback != nullptr)
        callback(file_dialog.selected_path, file_dialog.selected_fn);

      callback = nullptr;
    }

    showFileOpen = false;

    // save file dialog
    if (showFileSave)
      ImGui::OpenPopup("Save File");

    if (file_dialog.showFileDialog("Save File", imgui_addons::ImGuiFileBrowser::DialogMode::SAVE, dialog_size, fileExt))
    {
      // std::cout << file_dialog.selected_fn << std::endl;	 // The name of the selected file or directory in case of Select Directory dialog mode
      // std::cout << file_dialog.selected_path << std::endl; // The absolute path to the selected file
      // printf("%s", file_dialog.selected_path.c_str());
      if (callback != nullptr)
        callback(file_dialog.selected_path, file_dialog.selected_fn);

      callback = nullptr;
    }

    showFileSave = false;
  }
}
