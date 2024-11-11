# Package

version       = "0.0.0"
author        = "romdotdog"
description   = "an anonymous n-body simulator"
license       = "UNLICENSED"
srcDir        = "src"
bin           = @["comet"]
backend       = "js"


# Dependencies

requires "nim >= 2.0.8",
         "jscanvas >= 0.1.0"
