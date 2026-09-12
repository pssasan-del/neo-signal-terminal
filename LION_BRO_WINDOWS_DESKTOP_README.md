# LION BRO Windows Desktop

This package keeps the same LION BRO Flutter frontend and existing backend integration, and adds a Windows desktop build target.

## Build on Windows
Open `mobile` and run `BUILD_LION_BRO_WINDOWS.bat`.

Requirements: Flutter stable with Windows desktop support and Visual Studio 2022 Desktop development with C++ workload.

The release folder contains `LION BRO.exe`, required DLLs, and the `data` folder. Do not copy only the EXE.

## GitHub build
Run the workflow **Build LION BRO Windows EXE**. Its artifact is `LION-BRO-Windows-EXE`, containing the complete Windows release ZIP.

The backend/strategy code is not redesigned by this desktop packaging step.
