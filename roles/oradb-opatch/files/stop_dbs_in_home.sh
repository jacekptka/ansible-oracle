#!/bin/bash -x
#
# Thorsten Bruhns (thorsten.bruhns@opitz-consulting.de)
#
# Date: 30.12.2016

# This script is a preworker for opatch apply to make sure that 
# no component ist running.
#
# How it works:
# - check for environment
# - check for running Insances
# - stop all running Instances
# - Final for open files

# Restrictions:
# - no RAC support at the moment
# - only for Database Version >= 12.1 

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

if [ $# -ne 1 ] ; then
    echo "$(basename $0) <ORACLE_HOME>"
    exit 10
fi

patch_home=$1

check_environment(){
    echo "#################################################"
    echo "Doing some prechecks before starting the work"
    echo "#################################################"

    # check if user executing this script is owner of Oracle
    echo "ORACLE_HOME: "${patch_home}
    oracleexe=${patch_home}/bin/oracle
    if [ ! -x ${oracleexe} ] ; then
        echo "oracle is not found in "${oracleexe}
        exit 1
    fi

    echo "Check owner of Oracle"
    oracleowner=$(ls -l ${oracleexe}| awk '{print $3}')
    if [ ! $(id -un) = $oracleowner ] ; then
        echo "Please execute this scipt as $oracleowner"
        echo "Current user: "$(id -un)
        echo "ORACLE_HOME : " ${patch_home}
        exit 2
    fi
}

stop_db(){
    echo "#################################################"
    echo "Restart Oracle Database "$mode
    echo "#################################################"
    # check for pmon
    ps -elf | grep " ora_pmon_"$ORACLE_SID"$" > /dev/null
    if [ $? -eq 0 ] ; then

    $ORACLE_HOME/bin/sqlplus -S -L /nolog  << _EOF
conn / as sysdba
PROMPT Shutdown immediate
shutdown immediate
_EOF
    fi
}

check_environment

for sid in $(cat /etc/oratab | grep -v "^#") ; do

    export ORACLE_SID=$(echo $sid | cut -d":" -f1)
    export ORACLE_HOME=$(echo $sid | cut -d":" -f2)

    DATAPATCH=$ORACLE_HOME/OPatch/datapatch

    echo "#################################################"
    echo "Working on ORACLE_SID: "$ORACLE_SID
    if [ $patch_home = $ORACLE_HOME ] ; then
        stop_db
    fi
done
