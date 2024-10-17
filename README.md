#Binary loader

Code in this repository is a PoC Mach-O binary files loader (and executor).
Supports both iOS and macOS (ARM64/ARM64e only).


##Build & Run

1. In case if your binary need extenal libraries (almost any binary), replace `static var dependenciesPath = "/path/to/dependencies/root"` with any absolute path to dependencies.
1. Build project as usual with Xcode

Feel free to use code of this project according to GPLv3 license.
Also feel free to contact me at [kudinov.dw@gmail.com](mailto:kudinov.dw@gmail.com)
