#!/bin/bash

EMOCMRSP=${1}/OPatch/ocm/bin/emocmrsp
OCM_FILE=${2}

test -f ${OCM_FILE} && exit 0 2>/dev/null

/usr/bin/expect - <<EOF
spawn $EMOCMRSP -no_banner -output $OCM_FILE
expect {
  "Email address/User Name:"
  {
    send "\n"
    exp_continue
  }
  "Do you wish to remain uninformed of security issues*"
  {
    send "Y\n"
    exp_continue
  }
}
EOF
