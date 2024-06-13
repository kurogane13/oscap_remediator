#!/usr/bin/bash

# THE PURPOSE OF THIS SCRIPT IS:
# - TO CHECK THE OS VERSION
# - INSTALL THE UTILITIES REQUIRED TO RUN THE ASSESMENT
# - SCAN OSCAP PROFILES
# - RUN AN ASSESMENT OR OSCAP EVALUATION FOR EACH PROFILE
# - PROVIDE RESULTS BASED ON EACH PROFILE, WITH AMOUNT OF FAILS, PASSES, AND NOTAPPLICABLE INSTANCES
# - ATTEMPT RO REMEDIATE ALL INSTANCES IN EACH PROFILE
# - RUN A VERIFICATION CHECK AFTER THE REMEDIATION PROCESS HAS RUN

# STEPS TAKEN IN THE SCRIPT:
# 1 - Scans the version of RHEL
# 2 - Runs fucntion oscap_bz2 - Installs and the utilities required to run the assesment
# 3 - Checks if the RHEL version is inside the /usr/share/xml/scap/ssg/content/ssg,
# Set with the installation of the scap-security-guide
# 4 - Scans all the existing profiles in the path above, and append it to a log file (scap_profiles_list.log)
# 5 - Creates a log file, and scrap it to get only the profiles name
# 6 - Runs a report based on every profile, which will be generated as an .html file
# 7 - Lists the amount of failures, passes, and notapplicable instances for every profile scanned,
# and the total amount of for all profiles.
# 8 - Gets a total amount of failures of all profiles scanned
# 9 - Runs the remediation process with the version found in the os_release.txt file
# 10 - Runs the verification process
# 11 - Generates .html reports with results after the remediation process ran
# 12 - List the amount of failures, passes, and notapplicable instances for every profile scanned,
# and the total amount of for all profiles.

function oscap_bz2() {

 if command -v wget 2&>1 /dev/null; then
  echo $(date)": wget utility is installed"
 else
  echo $(date)": wget utility is not installed"
  echo $(date)": Installing wget..."
  sudo yum -y install wget
 fi

 if command -v oscap 2&>1 /dev/null; then
  echo $(date)": oscap utility is installed"
 else
  echo $(date)": oscap utility is not installed"
  echo $(date)": Installing oscap..."
  sudo yum -y install openscap-scanner
 fi

if command -v bzip2 2&>1 /dev/null; then
 echo $(date)": bzip2 utility is already installed"
else
 echo $(date)": bzip2 utility is not installed"
 echo $(date)": Installing bzip2 utility..."
 sudo yum -y install bzip2
fi

dir_path="/usr/share/xml/scap/ssg/content/"
if [ -d "$dir_path" ]; then
 echo $(date)": scap-security-guide utility is already installed"
else
 echo $(date)": Installing scap-security-guide utility..."
 sudo yum -y install scap-security-guide
fi

}

function oscap_version_file() {

  cat /etc/os-release > os_release.txt
  versions_array=("7" "8" "9")
  os_array=("Red Hat Enterprise Linux ")

  # 1 - Scans the version of RHEL
  for os in $ "${os_array[@]}"; do
    if grep -qF "$os" $"os_release.txt"; then
      echo $(date)": NAME=$os"
    else
      echo $(date)": No version $os found" 2%>1 /dev/null
    fi
  done

  # Finds whether the most recent versions are in the os-release
  for version in "${versions_array[@]}"; do
    if grep -qF "$version" $"os_release.txt"; then
      echo $(date)": VERSION=$version"
      # 2 - Runs fucntion oscap_bz2 - Installs and the utilities required to run the assesment
      oscap_bz2
      check_oval='ls *.oval.xml'

      # Checks if the oval.xml file is found for the detected version
      echo $(date)": checking existence of oval file..."
      if $check_oval 2>/dev/null; then
        echo $(date)": oval.xml file found"
      else
        echo $(date)": No .oval.xml file found"
        echo $(date)": Downloading rhel-$version.oval.xml file..."
        wget -O - https://www.redhat.com/security/data/oval/v2/RHEL$version/rhel-$version.oval.xml.bz2 | bzip2 --decompress > rhel-$version.oval.xml
        wget -O - https://www.redhat.com/security/data/oval/com.redhat.rhsa-RHEL$version.xml.bz2 | bzip2 --decompress > com.redhat.rhsa-RHEL$version.xml.bz2
        if $check_oval 2>/dev/null; then
          echo $(date)": File downloaded"
        fi
      fi
    fi
  done
}

function oscap_check() {
  cat /etc/os-release > os_release.txt
  versions_array=("7" "8" "9")

  for version in "${versions_array[@]}"; do
    if grep -qF "$version" $"os_release.txt"; then
      echo $(date)": Listing ssg-rhel$version-* xml files in /usr/share/xml/scap/ssg/content/..."
      # 3 - Checks if the RHEL version is inside the /usr/share/xml/scap/ssg/content/ssg,
      # Set with the installation of the scap-security-guide
      ls -l -sh /usr/share/xml/scap/ssg/content/ssg-rhel$version-*
      # 4 - Scans all the existing profiles in the path above, and append it to a log file (scap_profiles_list.log)
      oscap info --profiles /usr/share/xml/scap/ssg/content/ssg-rhel$version-ds.xml > scap_profiles_list.log
      # 5 - Creates a log file, and scrap it to get only the profiles name
      touch scap_profiles.log
      cat scap_profiles_list.log | cut -f1 -d":" > scap_profiles.log
      cat scap_profiles.log | sed -i s'/xccdf_org.ssgproject.content_profile_//g' scap_profiles.log
      echo $(date)": Listing scap profiles..."
      cat scap_profiles.log | while read profile; do echo $profile; done
      echo $(date)": Running report for scap profiles..."
      # 6 - Runs a report based on every profile, which will be generated as an .html file
      cat scap_profiles.log | while read profile_report; do
        oscap xccdf eval --fetch-remote-resources	--profile xccdf_org.ssgproject.content_profile_$profile_report --report rhel$version-$profile_report-report.html	/usr/share/xml/scap/ssg/content/ssg-rhel$version-ds.xml
      done
      # 7 - Lists the amount of failures for every profile scanned, and the total amount of failures found.
      for report in *.html; do
        echo -n $(date)": Amount of failures in profile $report: "
        cat $report | grep "fail" | wc -l | cut -f1 -d":" > amount_of_failures.log
        cat $report | grep "pass" | wc -l | cut -f1 -d":" > amount_of_passes.log
        cat $report | grep "notapplicable" | wc -l | cut -f1 -d":" > amount_of_notapplicable.log
        cat $report | grep "error" | wc -l | cut -f1 -d":" > amount_of_errors.log
        SUM=0
        for num in $(cat amount_of_failures.log); do ((SUM+=num)); echo $SUM > allprofiles_eval_failures_total_amount.log; done
        for num in $(cat amount_of_passes.log); do ((SUM+=num)); echo $SUM > allprofiles_eval_passes_total_amount.log; done
        for num in $(cat amount_of_notapplicable.log); do ((SUM+=num)); echo $SUM > allprofiles_eval_notapplicable_total_amount.log; done
        for num in $(cat amount_of_errors.log); do ((SUM+=num)); echo $SUM > allprofiles_eval_error_total_amount.log; done
      done
    else
      echo $(date)": No version $version found" 2%>1 /dev/null
    fi
  done
}

function oscap_remediate() {

      # REMEDIATION PROCESS:
      # 9 - Runs the remediation process with the version found in the os_release.txt file
      for version in "${versions_array[@]}"; do
        if grep -qF "$version" $"os_release.txt"; then
          cat scap_profiles.log | while read profile_name; do
            echo $(date)": Remediating profile $profile_name"
            sudo oscap xccdf eval --remediate --fetch-remote-resources --profile xccdf_org.ssgproject.content_profile_$profile_name --results remediation_results.xml /usr/share/xml/scap/ssg/content/ssg-rhel$version-ds.xml

          done

        fi
      done
}

function oscap_verify() {

  # VERIFICATION PROCESS:
  # 10 - Runs the verification process
  cat scap_profiles.log | while read profile_name; do
    echo $(date)": Verifiying profile $profile_name"
    sudo oscap xccdf eval --profile xccdf_org.ssgproject.content_$profile_name --results $profile_name_postRem_results.xml --report $profile_name_postRem_report.html /usr/share/xml/scap/ssg/content/ssg-rhel$version-ds.xml
  done
  # 11 - Generates .html reports with results after the remediation process ran
  for report_remediate in *.html; do

    cat $report_remediate | grep "fail" | wc -l | cut -f1 -d":" > $report_remediate_remediate_amount_of_failures.log
    cat $report_remediate | grep "pass" | wc -l | cut -f1 -d":" > $report_remediate_remediate_amount_of_passes.log
    cat $report_remediate | grep "notapplicable" | wc -l | cut -f1 -d":" > $report_remediate_remediate_amount_of_notapplicable.log
    cat $report_remediate | grep "fixed" | wc -l | cut -f1 -d":" > $report_remediate_remediate_amount_of_fixed.log
    cat $report_remediate | grep "error" | wc -l | cut -f1 -d":" > $report_remediate_remediate_amount_of_error.log
    SUM=0
    for num in $(cat $report_remediate_remediate_amount_of_failures.log); do ((SUM+=num)); echo $SUM > failures_total_amount.log; done
    for num in $(cat $report_remediate_remediate_amount_of_passes.log); do ((SUM+=num)); echo $SUM > passes_total_amount.log; done
    for num in $(cat $report_remediate_remediate_amount_of_notapplicable.log); do ((SUM+=num)); echo $SUM > notapplicable_total_amount.log; done
    for num in $(cat $report_remediate_remediate_amount_of_fixed.log); do ((SUM+=num)); echo $SUM > fixed_total_amount.log; done
    for num in $(cat $report_remediate_remediate_amount_of_error.log); do ((SUM+=num)); echo $SUM > error_total_amount.log; done

  done

  for num in $(cat passes_total_amount.log); do ((SUM+=num)); echo $SUM > all_profiles_failures_total_amount.log; done
  for num in $(cat failures_total_amount.log); do ((SUM+=num)); echo $SUM > all_profiles_passes_total_amount.log; done
  for num in $(cat notapplicable_total_amount.log); do ((SUM+=num)); echo $SUM > all_profiles_notapplicable_total_amount.log; done
  for num in $(cat fixed_total_amount.log); do ((SUM+=num)); echo $SUM > all_profiles_fixed_total_amount.log; done
  for num in $(cat error_total_amount.log); do ((SUM+=num)); echo $SUM > all_profiles_error_total_amount.log; done

  # 12 - Lists the amount of failures, passes, fixed, errors and notapplicable instances for every profile scanned,
  # and the total amount of for all profiles.
  echo -n $(date)": Amount of fails before remedtiation: " && cat allprofiles_eval_failures_total_amount.log
  echo -n $(date)": Amount of pass before remedtiation: " && cat allprofiles_eval_passes_total_amount.log
  echo -n $(date)": Amount of notapplicable before remedtiation: " && cat allprofiles_eval_notapplicable_total_amount.log
  echo -n $(date)": Amount of errors before remedtiation: " && cat allprofiles_eval_error_total_amount.log

  echo -n $(date)": Total Amount of passes after remediation: " && cat all_profiles_passes_total_amount.log
  echo -n $(date)": Total Amount of failures after remediation: " && cat all_profiles_failures_total_amount.log
  echo -n $(date)": Total Amount of notapplicable after remediation: " && cat all_profiles_notapplicable_total_amount.log
  echo -n $(date)": Total Amount of fixed after remediation: " && cat all_profiles_fixed_total_amount.log
  echo -n $(date)": Total Amount of errors after remediation: " && cat all_profiles_error_total_amount.log

}

oscap_version_file
oscap_check
oscap_remediate
oscap_verify
