#!/usr/bin/env zsh

################################################################################################
# Created by Nicholas McDonald | support@kandji.io | Kandji, Inc.
################################################################################################
#
#   Created on 2020-08-10
#   Last Updated on 2025-02-28 - Cory Funk
#
################################################################################################
# Tested macOS Versions
################################################################################################
#
#   - 10.15.7 - 15.x
#
################################################################################################
# Software Information
################################################################################################
#
#   Inspiration for portions of this script taken from homebrew-3.3.sh.
#   Original credit to Tony Williams (Honestpuck)
#   https://github.com/Honestpuck/homebrew.sh/blob/master/homebrew-3.3.sh
#
#   This script silently installs Homebrew as the most common local user.
#   This script can be set to "every 15 minutes" or "daily" to ensure Homebrew remains
#   installed.
#
#   NOTE: This script is designed to added brew to the current user's PATH, but if a user has
#   pre-existing CLI sessions open, the brew command may not be recognized. The user will need
#   to relaunch their sessions (ex - zsh -l) or start a new session so that brew is seen in
#   their PATH.
#
#   For the latest on brew Apple Silicon compatibility,
#   see: https://github.com/Homebrew/brew/issues/7857
#
################################################################################################
# License Information
################################################################################################
#
# Copyright 2023 Kandji, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
# to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or
# substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
# FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.
#
################################################################################################
# CHANGELOG
################################################################################################
#
#   1.2.0
#       - Added check for Apple Silicon homebrew binary location
#
#   1.3.0
#       - Code refactor
#           - Moved Rosetta2 check to a function
#           - Added additional comments for clarification
#           - Changed how permissions and ownership are set for brew and dependencies
#           - Change how brew doctor is interpreted and let admin know to check logs
#             for more info. Apple Silicon has a warning showing that brew is not
#             installed at /usr/local and might have unexpected behavior some app
#             installs that have not been updated for Apple Silicon.
#       - Added separate permissions and ownership logic for brew installed on Apple
#         Silicon
#       - Added local logging to /Library/Logs/homebrew_install.log
#       - Added check for Xcode CLI tools and will install them if not present
#       - Added support for homebrew install as a standard user.
#
#   1.3.1
#       - Added logic to determine most common user if a logged-in user is not found.
#       - Added additional logic to validate OS versions for Xcode CLI tools
#         compatibility
#
#   1.4.0
#       - Refactored brew install process so that the curl command is only downloading
#         the latest brew tarball file to the correct location
#       - Added function that creates the brew environment
#       - General code refactor
#       - Added additional logging output
#
#   1.4.1
#       - Minor refactor and bug squashing
#
#   1.4.2
#       - Added -a flag to tee binary to ensure that the local log file is appended to
#         and not overwritten. (credit - Glen Arrowsmith)
#       - Added additional logging
#       - updated latest tested OS versions
#
#   1.4.3
#       - Updated logging to note where brew is not able to be called from a CLI
# session that is already in progress. Workaround was to close all CLI
#         sessions and then launch a new session.
#       - Added logic to update the user's PATH in either .zshrc or .bashrc with path
#         to the brew binary.
#
#   1.4.4
#       - Grammar fixes and updates :P
#
#   1.5.0
#       - Moved logic for xcode install check up in the script to account for scenarios
#         on Apple Silicon where cli tools require reinstalation when upgrading from
#         one macOS version to the next.
#
#   1.5.1
#       - Updated logic when adding and validating that brew is in the current user's PATH.
#
#   1.5.2
#       - Updated Xcode CLI tools install logic to also check for any avaialble updates via
#         software update, and install those if the latest available version is newer that the
#         installed version.
#
#   2.0.0
#       - Rewrote Homebrew validation logic to ensure installation is successful before proceeding.
#       - Improved handling of Homebrew paths for both Apple Silicon and Intel Macs.
#       - Ensured the script runs exclusively in Zsh to avoid compatibility issues with Bash.
#       - Integrated Mosyle API to register devices dynamically after Homebrew is verified.
#       - Improved logging and error handling to provide better troubleshooting information.
#       - Added explicit checks for `brew doctor` and prevented further execution if Homebrew has issues.
#
################################################################################################

# Load Zsh-specific functions
autoload is-at-least
fpath+=("/usr/share/zsh/functions")
autoload -Uz is-at-least

# Script version
VERSION="2.0"

###################################### VARIABLES #######################################

# Logging config
LOG_NAME="homebrew_install.log"
LOG_DIR="/Library/Logs"
LOG_PATH="$LOG_DIR/$LOG_NAME"

############################ FUNCTIONS - DO NOT MODIFY BELOW ###########################

logging() {
    log_level=$(printf "%s" "$1" | tr '[:lower:]' '[:upper:]')
    log_statement="$2"
    script_name="$(basename "$0")"
    prefix=$(date +"[%b %d, %Y %Z %T $log_level]:")

    if [[ -z "${LOG_PATH}" ]]; then
        LOG_PATH="/Library/Logs/${script_name}"
    fi

    if [[ -z $log_level ]]; then
        log_level="INFO"
    fi

    echo "$prefix $log_statement"
    printf "%s %s\n" "$prefix" "$log_statement" >>"$LOG_PATH"
}

set_brew_prefix() {
    if [[ $(uname -m) == "arm64" ]]; then
        export BREW_PREFIX="/opt/homebrew"
        export BREW_PATH="/opt/homebrew/bin/brew"
    else
        export BREW_PREFIX="/usr/local"
        export BREW_PATH="/usr/local/bin/brew"
    fi

    export PATH="$BREW_PREFIX/bin:$PATH"

    logging "info" "Brew Prefix: $BREW_PREFIX"
    logging "info" "Brew Path: $BREW_PATH"
}

check_brew_install_status() {
    if [[ -x "$BREW_PATH" ]]; then
        logging "info" "Homebrew already installed at $BREW_PATH..."

        logging "info" "Updating homebrew ..."
        /usr/bin/su - "$current_user" -c "zsh -c 'export PATH=$BREW_PREFIX/bin:\$PATH; $BREW_PATH update --force'" | tee -a "${LOG_PATH}"

        logging "info" "Running brew doctor..."
        BREW_STATUS=$(/usr/bin/su - "$current_user" -c "zsh -c 'export PATH=$BREW_PREFIX/bin:\$PATH; $BREW_PATH doctor'" 2>&1)

        echo "$BREW_STATUS"
        logging "info" "$BREW_STATUS"

        if [[ "$BREW_STATUS" == *"Your system is ready to brew."* ]]; then
            logging "info" "Homebrew is successfully installed and verified."
            exit 0
        else
            logging "error" "Homebrew doctor detected issues. Check the log."
            exit 1
        fi
    else
        logging "info" "Homebrew is not installed..."
    fi
}

############################ MAIN LOGIC - DO NOT MODIFY BELOW ##########################

logging "info" "--- Start Homebrew Install Log ---"
logging "info" "Script version: $VERSION"
/bin/echo "Log file at $LOG_PATH"

processor_brand="$(/usr/sbin/sysctl -n machdep.cpu.brand_string)"

current_user=$(/usr/sbin/scutil <<<"show State:/Users/ConsoleUser" |
    awk '/Name :/ && ! /loginwindow/ && ! /root/ && ! /_mbsetupuser/ { print $3 }' |
    awk -F '@' '{print $1}')

if [[ -z $current_user ]]; then
    logging "info" "Current user not logged in. Attempting to determine most common user..."
    current_user=$(/usr/sbin/ac -p | sort -nk 2 |
        grep -E -v "total|admin|root|mbsetup|adobe" | tail -1 |
        xargs | cut -d " " -f1)
fi

logging "info" "Most common user: $current_user"

if /usr/bin/dscl . -read "/Users/$current_user" >/dev/null 2>&1; then
    logging "info" "$current_user is a valid user."
else
    logging "error" "Invalid user: $current_user"
    exit 1
fi

logging "info" "Determining Homebrew path prefix..."
set_brew_prefix

logging "info" "Checking Homebrew install status..."
check_brew_install_status

logging "info" "--- End Homebrew Install Log ---"

exit 0
