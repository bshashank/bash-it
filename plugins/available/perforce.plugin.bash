cite about-plugin
about-plugin 'perforce helper functions'

function _explain_if_not_p4() {
    if [[ -n "$(p4 set P4CLIENT 2> /dev/null)" ]]; then
        return 0;
    else
        echo 'You are not in a Perforce (p4) client'
        return 1;
    fi
}

function _p4-client-syncto(){
    p4 changes -t -m1  ...#have | awk -F' ' '{ print $2 "\t" $4, $5 }'
}

function _p4-client-tot(){
    p4 changes -t -m1  ... | awk -F' ' '{ print $2 "\t" $4, $5 }'
}

function _p4-client-syncto-diff(){
    # Pass the client-syncto to this function
    local client_syncto=$1
    p4 changes -e "${client_syncto}" ... | \
        grep --count --invert-match "${client_syncto}"
}

function p4-cldiff {
  about 'print the diff (in unified format) of the given pending change'
  group 'p4'

  if _explain_if_not_p4; then
    p4 opened -c "${1}" | awk 'BEGIN { FS = "#" } // { print "p4 diff -du " $1 }' | sh;
  fi
}

function p4-cldiff2 {
  about 'print the diff (in unified format) of the given pending change'
  group 'p4'

  if _explain_if_not_p4; then
    p4 opened -c "${1}" | awk 'BEGIN { FS = "#" } // { print "p4 diff2 -du " $1 }' | sh;
  fi
}

function p4-files {
  about 'print the files associated with the changeset'
  group 'p4'

  if _explain_if_not_p4; then
    p4 describe -s "${1}" | grep --only-matching --perl-regexp '(?<=\.\.\. )//\S+(?=#\d+ \w+)'
  fi
}

function p4-bugs {
  about 'print the bug numbers associated with the changeset'
  group 'p4'

  if _explain_if_not_p4; then
    p4 change -o "${1}" | grep 'Bug Number:' | awk -F ':' '{ print $2 }'
  fi
}

function p4-shortlog() {
  about 'print a short summary.'
  group 'p4'

  if _explain_if_not_p4; then
    p4 describe "${1}" | awk 'FNR == 3 {print}'
  fi
}

function p4-status() {
  about 'print a succient summary of the client and local changes.'
  group 'p4'
  # local tot_cln, tot_time, client_cln, client_time
  IFS=$'\t' read -r tot_cln tot_time <<< "$(_p4-client-tot)"
  IFS=$'\t' read -r client_cln client_time <<< "$(_p4-client-syncto)"
  if [[ "${tot_cln}" == "${client_cln}" ]]; then
    # We are synced to top of tree
    echo -e "Synced to top of tree: ${tot_cln}, ${tot_time}"
  else
    changes_away=$(_p4-client-syncto-diff "${client_cln}")
    # Print the top of tree details
    echo -e "!!! Out of sync from top of tree"
    echo -e "    Client is ${changes_away} changes away from ToT"
    echo -e "    Top of tree: ${tot_cln} at: ${tot_time}"
    echo -e "    Client:      ${client_cln} at: ${client_time}"
  fi

  # Print a new line before details information
  echo

  # Read the opened files and display all the opened files and under their
  # changesummary heading.

  _p4-opened | awk '
  BEGIN {
    opened=0;
    type_array["edit"]=0;
    type_array["add"]=0;
    type_array["delete"]=0;
    change_array["change"]= "";
  }
  {
    # p4 opened prints one file per line, and all lines begin with "//"
    # Here is an examples:
    #
    #   $ p4 opened
    #   //depot/some/file.py#4 - edit change 716431 (text)
    #   //depot/another/file.py - edit default change (text)
    #   //now/add/a/newfile.sh -  add change 435645 (text+k)
    #       $1                 $2  $3  $4     $5      $6
    #
    if ($1 ~ /^\/\//) {
      opened += 1
      change_array[$5] = change_array[$5] FS $1
      type_array[$3] += 1
    }
  }
  END {
    asorti(change_array, sorted_changes);
    for (sort_index in sorted_changes) {
      ix = sorted_changes[sort_index];
      if( ix ~ "change") {
        if (length(change_array[ix]) == 0) {
          continue
        }
        change_summary = "Default change"
      } else {
        change_sum_cmd = "p4 describe -s " ix "| head -3 | tail -1";
        change_sum_cmd | getline change_summary;
        change_summary = ix FS change_summary;
      }
      split(change_array[ix], changes);
      print change_summary;
      for (change_index in changes) {
        print "    " changes[change_index];
      }
      print "";
    }
  }
'
}
