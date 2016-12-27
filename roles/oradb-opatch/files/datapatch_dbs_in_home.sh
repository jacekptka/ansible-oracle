#!/bin/bash
#
# Thorsten Bruhns (thorsten.bruhns@opitz-consulting.de)
#
# Date: 30.12.2016

# This script is for applying Oracle Patches in Databases with datapatch
# Please keep in mind, that this only works with Oracle from 12c onwards.
#
# How it works:
# - check for environment
# - check for running database
# - startup open when Instance is not startet
# - datapatch -prereq
# - restart Instance when patches must be applied
# - apply patches with datapatch
# - restart Instance when patches were applied

# Restrictions:
# - no RAC support at the moment
# - only for Database Version >= 12.1 
#

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

restart_db(){
    mode=${1:-""}
    echo "#################################################"
    echo "Restart Oracle Database "$mode
    echo "#################################################"
    # check for pmon
    ps -elf | grep " ora_pmon_"$ORACLE_SID"$" > /dev/null
    if [ $? -eq 0 ] ; then
        shutdowndb="shutdown immediate"
    else
        shutdowndb=""
    fi

    # try to start the database
    $ORACLE_HOME/bin/sqlplus -S -L /nolog  << _EOF
conn / as sysdba
PROMPT $shutdowndb
$shutdowndb
prompt startup $mode
startup $mode
_EOF
}

check_open_database(){
    echo "#################################################"
    echo "Checking for running database and starting it"
    echo "#################################################"
    $ORACLE_HOME/bin/sqlplus -S -L /nolog  >/dev/null<< _EOF
whenever sqlerror exit 1
conn / as sysdba
set termout off feedback off
select count(1) from dba_users;
_EOF

    if [ $? -ne 0 ] ; then
        # try to start the database
        restart_db " "
    fi
}

check_datapatch(){
    ORACLE_SID=$1
    echo "#################################################"
    echo "Check for Patches with datapatch"
    echo "#################################################"
    datapatchout=$($DATAPATCH -verbose -prereq -upgrade_mode_only -db $ORACLE_SID)
    retcode=$?
    if [ $? -ne 0 ] ; then
        echo "datapatch returned with returncode <> 0!"
        return 99
    fi

    echo -e "$datapatchout"
    # Search for result
    echo -e "$datapatchout" | grep "The database must be in upgrade mode" > /dev/null
    if [ $? -eq 0 ] ; then
        return 2
    fi
    echo -e "$datapatchout" | grep "not installed in the SQL registry" > /dev/null
    if [ $? -eq 0 ] ; then
        return 1
    else
        echo -e "$datapatchout" | grep "Nothing to apply" > /dev/null
        if [ $? -eq 0 ] ; then
            return 0
        fi
    fi

    # Nothing to apply
    retval=$?
    echo "Return-Code: "$retval
}

do_datapatch(){
    echo "#################################################"
    echo "Execute datapatch for ORACLE_SID "$1
    echo "#################################################"
    $DATAPATCH -verbose -db $1 ${2:-""}
}




check_environment

for sid in $(cat /etc/oratab | grep -v "^#") ; do

    export ORACLE_SID=$(echo $sid | cut -d":" -f1)
    export ORACLE_HOME=$(echo $sid | cut -d":" -f2)

    DATAPATCH=$ORACLE_HOME/OPatch/datapatch

    echo "#################################################"
    echo "Working on ORACLE_SID: "$ORACLE_SID
    if [ $patch_home = $ORACLE_HOME ] ; then
        check_open_database
        check_datapatch $ORACLE_SID
        retval=$?

        # returncodes:
        #  0 = nothing to do
        #  1 = datapatch 'normal'
        #  2 = datapatch 'upgrade' mode
        # 99 = Returncode <>0 from datapatch

        if [ $retval -eq 0 ] ; then

            echo "Nothing to apply!"
            continue

        elif [ $retval -eq 1 ] ; then

            echo "#################################################"
            echo "doing normal datapatch apply"
            echo "#################################################"
            do_datapatch $ORACLE_SID

            echo "#################################################"
            echo "final chack affter datapatch"
            check_datapatch $ORACLE_SID

        elif [ $retval -eq 2 ] ; then

            echo "#################################################"
            echo "Restarting Database in Upgrade mode"
            echo "#################################################"
            restart_db upgrade
            do_datapatch $ORACLE_SID
            restart_db " "
            echo "#################################################"
            echo "final chack affter datapatch"
            check_datapatch $ORACLE_SID

        fi
    fi
done
