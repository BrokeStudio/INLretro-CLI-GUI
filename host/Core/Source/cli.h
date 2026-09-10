#pragma once
#ifndef CLI_H
#define CLI_H
#include <string>

#include "INLOptions.h"

// int inlprog_cli(int argc, char* argv[]);
// t_INLoptions *parseOptions(int argc, char *argv[]);
bool parseOptions(int argc, char *argv[], t_INLoptions_std *opts);
std::string get_cli(t_INLoptions_std INLoptions);

#endif
