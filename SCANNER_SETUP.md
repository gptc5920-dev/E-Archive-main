# USB document scanner setup

The document upload dialog includes a **Scan document** action. Scanner output is
returned to the same file list and uses the existing student metadata, document
type, tags, storage path, database record, and upload callback.

## Supported environment

- Windows 10 or Windows 11 x64
- A USB scanner with a Windows Image Acquisition (WIA) driver
- Windows PowerShell 5.1, included with supported Windows versions

Canon, Epson, HP, and Brother devices normally work when the manufacturer's
full Windows driver package exposes the scanner through WIA. A device with only
a TWAIN driver will not appear; install its WIA component or current full driver
package.

No native DLL is bundled and no CMake change is required. The application uses
the Windows WIA COM service through a non-interactive, encoded PowerShell
process. This avoids changing the application's Windows runner and keeps vendor
drivers outside the release package.

## Scanner installation

1. Disconnect the scanner before installing its driver if the vendor requests it.
2. Download the current Windows 10/11 x64 driver from the scanner manufacturer.
3. Install the full scanner/WIA package, then reconnect the USB cable.
4. Confirm that the device appears under **Imaging devices** in Device Manager.
5. Test one scan with the Windows Scan application.
6. Restart E-Archive, open **Documents → Upload documents → Scan document**, and
   select **Refresh scanners**.

The WIA service is named `StiSvc` (Windows Image Acquisition). If discovery
fails, open `services.msc`, verify that this service is available, and restart it.

## Build and release

Use the existing x64 Windows release process:

```powershell
flutter pub get
flutter build windows --release
```

The `image` package is the only scanner-specific dependency added to
`pubspec.yaml`. Existing `pdf`, `path`, and Flutter packages are reused.

## Workflow and temporary files

1. Select a scanner and supported scan settings.
2. Scan one or more pages.
3. Rotate, delete, reorder, or add pages.
4. Select combined PDF, separate PDFs, JPG, or PNG.
5. Select **Save to upload list**.
6. Complete the normal document upload form.

Review files are stored under `%TEMP%\e_archive_scans`. A scanner session is
deleted when the scanner dialog is cancelled, the upload dialog is cancelled,
the selection is cleared, or every file uploads successfully. Files are kept
temporarily after a partial upload failure so the failed items can be retried.

## Troubleshooting

- **No scanner detected:** install the WIA/full vendor driver, reconnect USB,
  test Windows Scan, and refresh the list.
- **Scanner busy:** close Windows Scan and vendor scanner utilities.
- **Paper jam/no paper:** clear the feeder and retry. Driver errors are converted
  into an in-app message.
- **Duplex disabled:** the connected WIA driver did not advertise duplex
  capability. Update the driver or choose single-sided scanning.
- **Resolution missing:** the DPI is outside the range reported by the driver.
- **PowerShell blocked:** an organization policy may block child PowerShell
  processes. IT must allow signed-in users to launch Windows PowerShell for WIA
  automation; no script file or execution-policy bypass is used.

## Source layout

```text
lib/features/documents/scanner/
  domain/scanner_models.dart
  services/scanner_service.dart
  presentation/scanner_dialog.dart
```

Integration with the current upload list is in
`lib/features/home/presentation/pages/parts/document_module/main.dart`.
