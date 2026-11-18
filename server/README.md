# E-Archive API (Dart + MySQL)

## Automated file organization

Complete uploads are stored under `uploads/` using this hierarchy:

`{schoolYear}/{college}/{program}/{studentCategory}/{studentNo}_{lastName}/{documentType}.ext`

Video uploads include a `Videos` folder before the file name:

`{schoolYear}/{college}/{program}/{studentCategory}/{studentNo}_{lastName}/Videos/{documentType}.ext`

Incomplete uploads (no received date on the student form) go to `uploads/Pending Documents/`.
Incomplete video uploads go to `uploads/Pending Documents/Videos/`.

## MySQL configuration

The server creates the configured database if it does not exist.

| Variable | Default |
|-----|-----|
| `E_ARCHIVE_MYSQL_HOST` | `127.0.0.1` |
| `E_ARCHIVE_MYSQL_PORT` | `3306` |
| `E_ARCHIVE_MYSQL_USER` | `root` |
| `E_ARCHIVE_MYSQL_PASSWORD` | empty |
| `E_ARCHIVE_MYSQL_DATABASE` | `e_archive` |

The optional `E_ARCHIVE_DATA_DIR` variable overrides the writable data root.
On Windows it defaults to `%LOCALAPPDATA%\E-Archive`; uploads are stored below
that directory and API startup diagnostics are written to
`logs\api-startup.log`.

## Database-backed modules

The backend stores students, documents, colleges, programs, users, audit logs,
access rules, compliance records, disposal queue items, and backup metadata in
MySQL. Uploaded files are stored under `uploads/`.

Default accounts are seeded when the `users` table is empty:

| Role | Email | Password |
|-----|-----|-----|
| Admin | `admin@gmail.com` | `admin123` |
| Staff | `staff@gmail.com` | `staff123` |

## Start the server

| How | Command |
|-----|---------|
| **Easiest (CMD)** | Double-click `run_server.bat` |
| **PowerShell** | `cd server` then `.\run_server.ps1` |
| **From project root** | Double-click `run_api_server.bat` or `dart run bin/server.dart` |
| **Inside server/** | `dart run bin/server.dart` (after `cd server`) |

From the project root, `dart run bin/server.dart` forwards to `server/bin/server.dart`.
