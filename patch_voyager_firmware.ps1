$EPIC_VOYAGER_ASCII_ART = @"
                                            
                                            
 @@@@@@@@@@@@                  @@@@@@@@@@@@ 
@@@@@@@@@@@@@@@@@@        @@@@@@@@@@@@@@@@@@
@@@ VOYAGER @@@@@@        @@@@@@ SAUCER @@@@
@@@@@@@@@@@@@@@@@@        @@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@        @@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@        @@@@@@@@@@@@@@@@@@
 @@@@@@     @@@@@@@      @@@@@@@     @@@@@@ 
              @@@@@@    @@@@@@              
                @@@@    @@@@                
                 @@      @@                 
                                            
                    ----                    
                                            
                PATCH SCRIPT                
                                            
                                            
"@

Write-Host $EPIC_VOYAGER_ASCII_ART

# Define file for storing custom AUTO_MOUSE_LAYER value
$AUTO_MOUSE_LAYER_FILE = "$(Join-Path -Path $PSScriptRoot -ChildPath 'auto_mouse_layer.txt')"

# Check if custom AUTO_MOUSE_LAYER value exists in the file and prompt user for input
if (Test-Path -Path $AUTO_MOUSE_LAYER_FILE) {
    # If file exists, read stored value and prompt for a new value
    $storedValue = Get-Content -Path $AUTO_MOUSE_LAYER_FILE | Select-Object -First 1
    Write-Host "Enter the layer number for AUTO_MOUSE_LAYER (Current saved value is $storedValue)"
    $AUTO_MOUSE_LAYER = Read-Host -Prompt "Press Enter to use the saved value, or type a new number to update."
    
    # Use stored value if user presses Enter without providing a new value
    if ($AUTO_MOUSE_LAYER -eq "") {
        $AUTO_MOUSE_LAYER = $storedValue
        Write-Host "Using saved AUTO_MOUSE_LAYER value: $AUTO_MOUSE_LAYER"
    } else {
        # Update the file with the new value
        Set-Content -Path $AUTO_MOUSE_LAYER_FILE -Value $AUTO_MOUSE_LAYER
        Write-Host "AUTO_MOUSE_LAYER value updated to: $AUTO_MOUSE_LAYER"
    }
} else {
    # If file doesn't exist, prompt user to enter a value
    Write-Host "Enter the layer number for AUTO_MOUSE_LAYER (Required)"
    Write-Host "This is the layer that is enabled when you touch the trackpad"
    $AUTO_MOUSE_LAYER = Read-Host -Prompt "Mouse Layer Number"
    
    # If no value is entered, exit the script
    if ($AUTO_MOUSE_LAYER -eq "") {
        Write-Host "No AUTO_MOUSE_LAYER value provided. This value is required to specify the layer where the auto mouse feature will be active. Exiting script."
        return
    }

    # Save the new value to the file
    Set-Content -Path $AUTO_MOUSE_LAYER_FILE -Value $AUTO_MOUSE_LAYER
    Write-Host "AUTO_MOUSE_LAYER value saved as: $AUTO_MOUSE_LAYER"
}

# Define pattern to check for existing patch
$PATCH_PATTERN = "FILE PATCHED"

# Paths to the files (assuming the files are in the same directory as this script)
$KEYMAP_FILE_PATH = "$(Join-Path -Path $PSScriptRoot -ChildPath 'keymap.c')"
$RULES_MK_FILE_PATH = "$(Join-Path -Path $PSScriptRoot -ChildPath 'rules.mk')"
$CONFIG_FILE_PATH = "$(Join-Path -Path $PSScriptRoot -ChildPath 'config.h')"

# -------------------------
# Verify file existence before proceeding
# -------------------------
if (!(Test-Path -Path $KEYMAP_FILE_PATH)) {
    Write-Host "keymap.c file is missing. Please check the file path. Exiting script."
    return
}

if (!(Test-Path -Path $RULES_MK_FILE_PATH)) {
    Write-Host "rules.mk file is missing. Please check the file path. Exiting script."
    return
}

if (!(Test-Path -Path $CONFIG_FILE_PATH)) {
    Write-Host "config.h file is missing. Please check the file path. Exiting script."
    return
}

# -------------------------
# Content for rules.mk
# -------------------------

$RULES_MK_CONTENT = @"
    # $PATCH_PATTERN                             # Marker to identify if the file has already been patched
    POINTING_DEVICE_ENABLE = yes                 # Enables the pointing device feature in QMK firmware, allowing the use of mouse-like inputs
    POINTING_DEVICE_DRIVER = cirque_pinnacle_i2c # Specifies the driver to be used for the pointing device, e.g., Cirque Pinnacle touchpad
"@

# -------------------------
# Content for config.h
# -------------------------

$CONFIG_CONTENT = @"
    // $PATCH_PATTERN                             // Marker to identify if the file has already been patched
    #define CIRQUE_PINNACLE_TAP_ENABLE             // Enables tap-to-click functionality on the Cirque Pinnacle touchpad, allowing single taps to act as left-clicks
    #define POINTING_DEVICE_ROTATION_90            // Rotates the X and Y data from the pointing device by 90 degrees, useful if the device is physically oriented differently
    #define MOUSE_EXTENDED_REPORT                  // Enables support for extended mouse reports, increasing the range of movement values to -32767 to 32767
    #define POINTING_DEVICE_AUTO_MOUSE_ENABLE      // Enables the automatic mouse layer feature to activate a specific layer when the pointing device is in use
    #define AUTO_MOUSE_TIME 280                    // Sets the amount of time (in ms) that the mouse layer remains active after activation; ideal values are 250-1000 ms
    #define POINTING_DEVICE_GESTURES_SCROLL_ENABLE // Enables scroll gestures on compatible devices, allowing actions like circular or side scrolling
"@

# -------------------------
# Content for keymap.c
# -------------------------

$KEYMAP_CONTENT = @"
    // $PATCH_PATTERN                            // Marker to identify if the file has already been patched
    void pointing_device_init_user(void) {
        set_auto_mouse_layer($AUTO_MOUSE_LAYER); // only required if AUTO_MOUSE_DEFAULT_LAYER is not set to index of <mouse_layer>
        set_auto_mouse_enable(true);             // always required before the auto mouse feature will work
    }
"@

# -------------------------
# Logic to append content to files
# -------------------------

# Function to append content if it doesn't exist
function AppendConfigurationIfUnpatched {
    param (
        [string]$filePath,
        [string]$content,
        [string]$patternToCheck
    )

    # Check if the file already contains the specified pattern
    if (-not (Select-String -Path $filePath -Pattern $patternToCheck)) {
        try {
            Add-Content -Path $filePath -Value $content
            Write-Host "$filePath has been patched."
        } catch {
            Write-Host "Error appending content to {$filePath}: $_"
        }
    } else {
        Write-Host "$filePath already contains a patch."
    }
}

# Append content to keymap.c, rules.mk, and config.h if not already patched
AppendConfigurationIfUnpatched -filePath $KEYMAP_FILE_PATH -content $KEYMAP_CONTENT -patternToCheck $PATCH_PATTERN
AppendConfigurationIfUnpatched -filePath $RULES_MK_FILE_PATH -content $RULES_MK_CONTENT -patternToCheck $PATCH_PATTERN
AppendConfigurationIfUnpatched -filePath $CONFIG_FILE_PATH -content $CONFIG_CONTENT -patternToCheck $PATCH_PATTERN

# Final message to indicate successful execution
Write-Host "Script execution completed successfully. All files have been processed."
Pause
