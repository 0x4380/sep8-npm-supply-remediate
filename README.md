How to use

Clone the repository

In the root of each of your Node.js projects, run the check:

For MacOS run remediate-npm_macos.sh

Linux
bash

    chmod +x remediate-npm.sh
    ./remediate-npm.sh --detect

Windows (PowerShell)
powershell

    ./remediate-npm.ps1 --detect

If any matches are found, apply the fix (carefully, lockfiles are not touched):

Linux
bash

    ./remediate-npm.sh --fix --yes

Windows
powershell

    ./remediate-npm.ps1 --fix --yes

Options

    --reinstall-global - After removing global packages, install the @latest version

    --allow-no-lock - Allow local update without a lockfile (disabled by default)

Recommendation after the fix

Regenerate your npm tokens and check your SSH keys.
