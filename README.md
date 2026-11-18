# E-Archive

Flutter desktop client with a bundled Dart API and a MySQL data store.

## Build the Windows installer

Run `build_installer.bat` from the project root. This is the supported
installer-build entry point because it compiles the API first, builds Flutter,
copies the API into the release folder, and only then invokes Inno Setup.

Do not invoke `dart run inno_bundle` directly for a distributable build: it
only builds the Flutter application and can package a missing or stale API
executable.

The installed application stores mutable files under
`%LOCALAPPDATA%\E-Archive`, not under `Program Files`. API startup diagnostics
are written to `%LOCALAPPDATA%\E-Archive\logs\api-startup.log`.

MySQL must be available at `127.0.0.1:3306` by default. See
`server/README.md` for environment-variable overrides.
