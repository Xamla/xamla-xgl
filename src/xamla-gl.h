#pragma once

extern "C" {
#include <TH/TH.h>
}

#include <stdexcept>

#define XGLIMP(return_type, class_name, name) extern "C" return_type TH_CONCAT_4(xgl_, class_name, _, name)


class XglException
  : public std::runtime_error {
public:
  XglException(const std::string& reason)
    : runtime_error(reason) {
  }
};
