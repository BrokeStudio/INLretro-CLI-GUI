#include "imgui.h"
#include "imgui_impl_sdl2.h"
#include "imgui_impl_opengl2.h"

#include <functional>
#include <sstream>
#include <stdio.h>
#include <string>
#include <SDL.h>
#include <SDL_opengl.h>
#include <thread>

#include "usb_operations.h"
#include "cli.h"
#include "dbg.h"
#include "AppLog.h"
#include "AppLogGui.h"
#include "Dialog.h"
#include "Flasher.h"
#include "Ini.h"
#include "Menu.h"
#include "Settings.h"

// FontAwesome
#include "IconsFontAwesome6.h"
#include "fa_regular_400.h"
#include "fa_solid_900.h"
#include "RobotoMonoRegular.h"

// Helpers macros
// We normally try to not use many helpers in imgui_demo.cpp in order to make code easier to copy and paste,
// but making an exception here as those are largely simplifying code...
// In other imgui sources we can use nicer internal functions from imgui_internal.h (ImMin/ImMax) but not in the demo.
#define IM_MIN(A, B) (((A) < (B)) ? (A) : (B))
#define IM_MAX(A, B) (((A) >= (B)) ? (A) : (B))
#define IM_CLAMP(V, MN, MX) ((V) < (MN) ? (MN) : (V) > (MX) ? (MX) \
                                                            : (V))

/*
void show_status_bar_window(void)
{
  ImGui::Begin("Status");
  // ImGui::AlignTextToFramePadding();
  ImGui::Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / ImGui::GetIO().Framerate, ImGui::GetIO().Framerate);
  ImGui::SameLine();
  ImGuiViewport *viewport = ImGui::GetMainViewport();
  ImGui::Text("width: %f - height : %f", viewport->WorkSize.x, viewport->WorkSize.y);
  ImGui::End();
}
*/

/*

                                88
                                ""

88,dPYba,,adPYba,   ,adPPYYba,  88  8b,dPPYba,
88P'   "88"    "8a  ""     `Y8  88  88P'   `"8a
88      88      88  ,adPPPPP88  88  88       88
88      88      88  88,    ,88  88  88       88
88      88      88  `"8bbdP"Y8  88  88       88


*/

int main(int argc, char **argv)
{

  // Setup USB
  // int usb_init = libusb_init_context(/*ctx=*/NULL, /*options=*/NULL, /*num_options=*/0);
  int usb_init = libusb_init(/*ctx=*/NULL);
  // check(usb_init == LIBUSB_SUCCESS, "Failed to initialize libusb: %s", libusb_strerror((libusb_error)usb_init));
  if (usb_init < 0)
  {
    printf("Error: %s\n", libusb_error_name(usb_init));
    printf("Error: %s\n", libusb_error_name(usb_init));
    return usb_init;
  }
  // libusb_set_option(NULL, LIBUSB_OPTION_LOG_LEVEL, LIBUSB_LOG_LEVEL_DEBUG);

  // Setup SDL
  if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER | SDL_INIT_GAMECONTROLLER) != 0)
  {
    printf("Error: %s\n", SDL_GetError());
    return -1;
  }

  // From 2.0.18: Enable native IME.
#ifdef SDL_HINT_IME_SHOW_UI
  SDL_SetHint(SDL_HINT_IME_SHOW_UI, "1");
#endif

  // Setup window
  int min_width = 800;
  int min_height = 600;
  SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
  SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
  SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, 8);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
  SDL_WindowFlags window_flags = (SDL_WindowFlags)(SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE | SDL_WINDOW_ALLOW_HIGHDPI);
  SDL_Window *window = SDL_CreateWindow("INL retroprog GUI", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, min_width, min_height, window_flags);
  SDL_GLContext gl_context = SDL_GL_CreateContext(window);
  SDL_GL_MakeCurrent(window, gl_context);
  SDL_GL_SetSwapInterval(1); // Enable vsync
  SDL_SetWindowMinimumSize(window, min_width, min_height);

  // Setup Dear ImGui context
  IMGUI_CHECKVERSION();
  ImGui::CreateContext();
  ImGuiIO &io = ImGui::GetIO();
  (void)io;
  io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard; // Enable Keyboard Controls

  // Setup Dear ImGui style
  ImGui::StyleColorsDark();

  // When viewports are enabled we tweak WindowRounding/WindowBg so platform windows can look identical to regular ones.
  ImGuiStyle &style = ImGui::GetStyle();

  // Setup Platform/Renderer backends
  ImGui_ImplSDL2_InitForOpenGL(window, gl_context);
  ImGui_ImplOpenGL2_Init();

  // Load Fonts
  // - If no fonts are loaded, dear imgui will use the default font. You can also load multiple fonts and use ImGui::PushFont()/PopFont() to select them.
  // - AddFontFromFileTTF() will return the ImFont* so you can store it if you need to select the font among multiple.
  // - If the file cannot be loaded, the function will return a nullptr. Please handle those errors in your application (e.g. use an assertion, or display an error and quit).
  // - The fonts will be rasterized at a given size (w/ oversampling) and stored into a texture when calling ImFontAtlas::Build()/GetTexDataAsXXXX(), which ImGui_ImplXXXX_NewFrame below will call.
  // - Use '#define IMGUI_ENABLE_FREETYPE' in your imconfig file to use Freetype for higher quality font rendering.
  // - Read 'docs/FONTS.md' for more instructions and details.
  // - Remember that in C/C++ if you want to include a backslash \ in a string literal you need to write a double backslash \\ !
  io.Fonts->AddFontDefault();
  // io.Fonts->AddFontFromFileTTF("c:\\Windows\\Fonts\\segoeui.ttf", 18.0f);
  // io.Fonts->AddFontFromFileTTF("../../misc/fonts/DroidSans.ttf", 16.0f);
  // io.Fonts->AddFontFromFileTTF("../../misc/fonts/Roboto-Medium.ttf", 16.0f);
  // io.Fonts->AddFontFromFileTTF("../../misc/fonts/Cousine-Regular.ttf", 15.0f);
  // ImFont* font = io.Fonts->AddFontFromFileTTF("c:\\Windows\\Fonts\\ArialUni.ttf", 18.0f, nullptr, io.Fonts->GetGlyphRangesJapanese());
  // IM_ASSERT(font != nullptr);

  float baseFontSize = 18.0f; // 13.0f is the size of the default font. Change to the font size you use.

  // add OpenSans-Regular fonts
  ImFontConfig font_config;
  font_config.MergeMode = false;
  font_config.PixelSnapH = true;
  ImFont *RobotoMonoRegularFont = io.Fonts->AddFontFromMemoryCompressedBase85TTF(RobotoMonoRegular_compressed_data_base85, baseFontSize, &font_config);

  // add FontAwesome fonts
  float iconFontSize = baseFontSize * 2.0f / 3.0f; // FontAwesome fonts need to have their sizes reduced by 2.0f/3.0f in order to align correctly
  static const ImWchar icons_ranges[] = {ICON_MIN_FA, ICON_MAX_16_FA, 0};
  ImFontConfig icons_config;
  icons_config.MergeMode = true;
  icons_config.PixelSnapH = true;
  icons_config.GlyphMinAdvanceX = iconFontSize;
  io.Fonts->AddFontFromMemoryCompressedBase85TTF(fa_regular_400_compressed_data_base85, iconFontSize, &icons_config, icons_ranges);
  io.Fonts->AddFontFromMemoryCompressedBase85TTF(fa_solid_900_compressed_data_base85, iconFontSize, &icons_config, icons_ranges);

  // Our state
  ImVec4 clear_color = ImVec4(0.45f, 0.55f, 0.60f, 1.00f);

  // init consoles
  Ini::load();
  Ini::parse();
  Menu::init();

  // detect flashers
  // Flasher::detect_all_2();
  Flasher::detect_all();

  /*

                                  88                  88
                                  ""                  88
                                                      88
  88,dPYba,,adPYba,   ,adPPYYba,  88  8b,dPPYba,      88   ,adPPYba,    ,adPPYba,   8b,dPPYba,
  88P'   "88"    "8a  ""     `Y8  88  88P'   `"8a     88  a8"     "8a  a8"     "8a  88P'    "8a
  88      88      88  ,adPPPPP88  88  88       88     88  8b       d8  8b       d8  88       d8
  88      88      88  88,    ,88  88  88       88     88  "8a,   ,a8"  "8a,   ,a8"  88b,   ,a8"
  88      88      88  `"8bbdP"Y8  88  88       88     88   `"YbbdP"'    `"YbbdP"'   88`YbbdP"'
                                                                                    88
                                                                                    88
  */
  // Main loop
  bool done = false;
  while (!done)
  {
    // check if flashing
    static bool isFlashing;
    isFlashing = Flasher::is_flashing();

    // Poll and handle events (inputs, window resize, etc.)
    // You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear imgui wants to use your inputs.
    // - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application, or clear/overwrite your copy of the mouse data.
    // - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main application, or clear/overwrite your copy of the keyboard data.
    // Generally you may always pass all inputs to dear imgui, and hide them from your application based on those two flags.
    SDL_Event event;
    while (SDL_PollEvent(&event))
    {
      ImGui_ImplSDL2_ProcessEvent(&event);
      if (event.type == SDL_QUIT)
        done = true;
      if (event.type == SDL_WINDOWEVENT && event.window.event == SDL_WINDOWEVENT_CLOSE && event.window.windowID == SDL_GetWindowID(window))
        done = true;
    }

    // Start the Dear ImGui frame
    ImGui_ImplOpenGL2_NewFrame();
    ImGui_ImplSDL2_NewFrame();
    ImGui::NewFrame();
    ImGui::PushFont(RobotoMonoRegularFont);

#ifdef IMGUI_HAS_VIEWPORT
    ImGuiViewport *viewport = ImGui::GetMainViewport();
    ImGui::SetNextWindowPos(viewport->Pos);
    ImGui::SetNextWindowSize(viewport->Size);
    ImGui::SetNextWindowViewport(viewport->ID);
#else
    ImGui::SetNextWindowPos(ImVec2(0.0f, 0.0f));
    ImGui::SetNextWindowSize(ImGui::GetIO().DisplaySize);
#endif
    ImGui::PushStyleVar(ImGuiStyleVar_WindowRounding, 0.0f);
    ImGui::Begin("Main", 0, ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoResize); // ImGuiWindowFlags_MenuBar

    // 1. Show the big demo window (Most of the sample code is in ImGui::ShowDemoWindow()! You can browse its code to learn more about Dear ImGui!).
#if defined _DEBUG
    if (Settings::settings.imgui_demo)
      ImGui::ShowDemoWindow(&Settings::settings.imgui_demo);
#endif

    // file dialog
    Dialog::render();

    // TOP
    ImGui::SetNextWindowSizeConstraints(ImVec2(0.0f, 300.0f), ImVec2(FLT_MAX, FLT_MAX));
    ImGui::BeginChild("Top", ImVec2(0.0f, 300.0f), ImGuiChildFlags_ResizeY); // | ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoResize);

    // MENU TREE
    Menu::render_tree(isFlashing);

    // MENU CONTENT
    Menu::render_content();

    // TOP END
    ImGui::EndChild(); // Top

    // MIDDLE / FLASHER LOGS
    ImGui::BeginChild("Middle", ImVec2(0, ImGui::GetContentRegionAvail().y - 150.0f)); // MIDDLE

    // count active flashers
    size_t activeFlashers = 0;
    for (auto &flasher : Flasher::list)
    {
      if (flasher->isActive)
        activeFlashers++;
    }

    // any active flashers?
    if (activeFlashers != 0)
    {
      ImVec2 child_size = ImVec2(ImGui::GetContentRegionAvail().x / activeFlashers, 0.0f);
      if (activeFlashers > 1)
        child_size.x = child_size.x - (style.WindowPadding.x / activeFlashers) * (activeFlashers - 1);
      for (auto &flasher : Flasher::list)
      {
        if (!flasher->isActive)
          continue;

        char label[64];
        char spinner[2] = "";
        spinner[0] = flasher->isFlashing ? "|/-\\"[(int)(ImGui::GetTime() / 0.05f) & 3] : 0;
        snprintf(label, 64, "INL Retro-Pro%s [%s] %s", flasher->id.c_str(), flasher->isFlashing ? "Processing" : "Done", spinner);
        ImGui::BeginChild(label, child_size, ImGuiChildFlags_Border);
        ImGui::SeparatorText(label);
        flasher->log.render();
        ImGui::EndChild();
        ImGui::SameLine();
      }
    }
    ImGui::EndChild(); // /MIDDLE

    ImGui::BeginChild("Bottom", ImVec2(0.0f, 150.0f), ImGuiChildFlags_Border); // BOTTOM
    AppLog::render();
    ImGui::EndChild(); // /BOTTOM

    ImGui::End();

    ImGui::PopStyleVar();

    ImGui::PopFont();

    // Rendering
    ImGui::Render();
    glViewport(0, 0, (int)io.DisplaySize.x, (int)io.DisplaySize.y);
    glClearColor(clear_color.x * clear_color.w, clear_color.y * clear_color.w, clear_color.z * clear_color.w, clear_color.w);
    glClear(GL_COLOR_BUFFER_BIT);
    // glUseProgram(0); // You may want this if using this code in an OpenGL 3+ context where shaders may be bound
    ImGui_ImplOpenGL2_RenderDrawData(ImGui::GetDrawData());
    SDL_GL_SwapWindow(window);
  }

  // Cleanup
  Console::clear_list();
  Flasher::clear_list();
  Ini::save();

  if (usb_init == LIBUSB_SUCCESS)
  {
    libusb_exit(NULL);
  }

  ImGui_ImplOpenGL2_Shutdown();
  ImGui_ImplSDL2_Shutdown();
  ImGui::DestroyContext();

  SDL_GL_DeleteContext(gl_context);
  SDL_DestroyWindow(window);
  SDL_Quit();

  return 0;
}
