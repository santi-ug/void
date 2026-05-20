# void

void is a minimalist mac utility that "voids" your display and locks your keyboard for easy monitor cleaning.

---

## Features

* Runs from the macOS Menu Bar.
* Implements low-level keyboard input management.
* Handles window focus structures fluidly.
* Open source, compiled locally, and privacy-focused.

---

## Installation and Setup

Because void operates outside the Mac App Store and requires system-level hooks, macOS requires a one-time security configuration during installation.

### 1. Download and Install
1. Navigate to the Releases tab of this repository.
2. Download `void-Installer.dmg`.
3. Open the disk image and drag the void application into your Applications folder.

---

### 2. Bypass macOS Gatekeeper
Since this application is distributed directly via GitHub, macOS will state that it cannot be verified. To authorize the application manually:

1. Launch void from your Applications folder. Click OK to dismiss the initial warning.
2. Open System Settings from the Apple menu.
3. Select Privacy & Security in the left sidebar.
4. Scroll to the Security section on the right. Locate the message: "void was blocked from opening because it is not from an identified developer."
5. Click Open Anyway, enter your Mac password, and confirm by clicking Open.

This exception is permanent and will not be requested on subsequent launches.

---

### 3. Grant Accessibility Permissions
void requires Accessibility access to interact with system inputs.

1. On the first successful launch, an Accessibility Access prompt will appear.
2. Click Open System Settings on the dialog box.
3. Locate void in the permission list and toggle the switch to ON.
4. Authenticate with your Mac password to save the changes.

---

## Development and Compilation

To compile the project from source using Xcode:

### Prerequisites
* macOS 14.0 or newer
* Xcode 15.0 or newer

### Building Natively
1. Clone the repository:
   ```bash
   git clone https://github.com
   cd void
   ```
2. Open `void.xcodeproj` in Xcode.
3. Under Product > Scheme > Edit Scheme, change the Build Configuration to Release.
4. Press Command + B to compile the final binary.

### Packaging the DMG
To generate the distribution disk image using create-dmg:
```bash
create-dmg \
  --volname "void Installer" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "void.app" 200 190 \
  --app-drop-link 600 190 \
  "void-Installer.dmg" \
  "void.app"
```

---

## License

This project is open-source software licensed under the MIT License.

