#pragma once
#ifndef DIALOG_H
#define DIALOG_H

#include <functional>
#include "ImGuiFileBrowser.h"
#include <string.h>

namespace Dialog
{
  extern bool showFileOpen;
  extern bool showFileSave;
  extern std::string fileExt;
  extern imgui_addons::ImGuiFileBrowser file_dialog;
  extern std::function<void(const std::string &path, const std::string &filename)> callback;

  void render();
}

#endif
