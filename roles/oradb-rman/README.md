# Role Name

Manages RMAN Backups

# Example Playbook

You need root permissions for executing the role!

    - hosts: servers
      roles:
         - roles/oradb-rman

# Configuration

## Example

The backup is configured on oracle_databases level:

  oracle_databases:
    - home: db_home1
      oracle_db_name: TEST

      rman_jobs:
         - name: parameter
         - name: archivelog
           disabled: False
           day: "*"
           weekday: "*"
           hour: "*"
           minute: "10"
         - name: online_level0
           disabled: False
           day: "*"
           weekday: "0"
           hour: "02"
           minute: "30"
         - name: online_level1
           disabled: False
           day: "*"
           weekday: "1-6"
           hour: "02"
           minute: "30"

## Variables
* rman_cronfile
Defines the name of the cronfile in /etc/cron.d. Setting rman_cronfile: "" will use the cron of the oracle_user instead of /etc/cron.d

* rman_cron_logdir
Destination for cron execution which is redirected with >> rman_cron_logdir 2>&1

* rman_retention_policy
Use rman_retention_policy_default when not defined. This variable could be used inside rman_jobs for individual retention policies for every Database.

* rman_channel_disk
Use rman_channel_disk_default when not defined. This variable could be used inside rman_jobs for individual retention policies for every
 Database.

* rman_retention_policy_default
This values is used when rman_retention_policy is not defined inside rman_jobs:.
Default: "RECOVERY WINDOW OF 14 DAYS"

* rman_channel_disk_default
Default value: "DISK FORMAT   '/u10/rmanbackup/%d/%d_%T_%U'"

* rman_controlfile_autobackup_disk_default
Default: "DISK FORMAT   '/u10/rmanbackup/%d/%d_%T_%U'"

## Howtos
### How to configure the RMAN scripts?
The role copies the templatefiles from role/oradb-rman/templates to $ORACLE_BASE/admin/<DB_NAME>/rman. The name in the list defines the name of the template with .j2 as extension.
	
### How to configure the cron?

The dictionary elements name, disabled, day, weekday, hour, minute are mandatory. The creation of cron only starts when every element is defined.

### How to use custom RMAN scripts?
Copy the script into the template directory role/oradb-rman/templates and add a '- name: <filename>' at rman_jobs. The filename must end on .rman.j2, regardless of Junja2 in the file. You could use your own variables in the custom files and add entries to rman_jobs. They will be added as item.1.<dictionaryelement> to the template.
Please do not edit existing files. The could be changed in future releases of oradb-rman.

