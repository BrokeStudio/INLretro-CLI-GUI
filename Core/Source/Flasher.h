#pragma once
#ifndef FLASHER_H
#define FLASHER_H

#include <vector>
#include "usb_operations.h"
#include "Lua.h"

class Flasher
{
public:
  static std::vector<Flasher *> list;

  std::string id;
  bool isFlashing;
  bool isActive;
  Lua lua;
  Log log;

  // constructor / destructor
  Flasher(const std::string &id, bool isActive);
  ~Flasher();

  // static methods
  static bool detect(char *retroprog_id);
  static void detect_all();
  // static void detect_all_2();
  static bool is_flashing();
  static int count_flashing();
  static void clear_list();
  static void exec_all(t_INLoptions_std INLoption);

  // public methods
  int t_inlprog_opt(const t_INLoptions_std &opts);
  int inlprog_opt(const t_INLoptions_std &opts);
  bool exec(t_INLoptions_std opts);

private:
  // private methods
  void cleanup(USBtransfer *transfer);

  // static methods
  static USBtransfer *usb_inldevice_open(int libusb_log, char *retroprog_id, Log *log);
  static void usb_inldevice_close(USBtransfer *transfer);
};

#endif
