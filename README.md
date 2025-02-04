# oscap_remediator
Oscap remediator script to run oscap assesments

# Author: Gustavo Wydler Azuaga

# Date: 06/13/2024

# OSCAP Assessment and Remediation Script

This script automates the process of checking the OS version, installing necessary utilities, scanning OSCAP profiles, running assessments, remediating issues, and verifying the results for Red Hat Enterprise Linux (RHEL) systems.

## Features

- Checks the OS version
- Installs required utilities (wget, oscap, bzip2, scap-security-guide)
- Scans OSCAP profiles
- Runs an assessment or OSCAP evaluation for each profile
- Provides results with the number of failures, passes, and not applicable instances
- Attempts to remediate all instances in each profile
- Runs a verification check after the remediation process

## Steps Taken in the Script

1. Scans the version of RHEL
2. Installs the utilities required to run the assessment
3. Checks if the RHEL version is in the `/usr/share/xml/scap/ssg/content/` directory
4. Scans all existing profiles and appends them to a log file (`scap_profiles_list.log`)
5. Creates a log file and extracts only the profile names
6. Runs a report for every profile, generating an HTML file
7. Lists the number of failures, passes, and not applicable instances for each profile scanned
8. Calculates the total number of failures across all profiles
9. Runs the remediation process based on the detected OS version
10. Runs a verification check after remediation
11. Generates HTML reports with results after remediation
12. Lists the amount of failures, passes, not applicable instances, fixed, and errors for each profile scanned

## Setup

1. **Clone the repository**: 
   ```bash
   git clone https://github.com/kurogane13/oscap_remediator.git
   cd oscap-assessment-script
   chmod +x oscap_assessment.sh
   sudo ./oscap_assessment.sh

