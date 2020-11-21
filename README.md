# crt-watch
Certificate Transparency Logs Monitoring

The script monitors Certificate Transparency Logs via crt.sh site and reports 
new certificates issued for the domain specified by the config file. It logs 
and sends alerts every time there is a change detected. It uses local sendmail 
for sending the alerts.

## Usage

```
crt-watch.sh [OPTION]
```

```
OPTION:
    -c CONFIG_FILE  configuration INI file for crt-watch.sh
    -h              show this help
```
```
CONFIG FILE:

    DOMAIN          name of the domain to monitor
    EMAIL_FROM      email address of a sender
    EMAIL_TO        email address of a TO recipient
    EMAIL_CC        email address of a CC recipient
    EMAIL_BCC       email address of a BCC recipient
    EMAIL_SUBJECT   subject of the email
    LOG_DIR         directory where to store log file for the domain
    REPORT_NEW      yes = report new certificates;
                    no  = do not report new certificates
```

## Example

**Config file**

```
###################################################
## Certificate Transparency Logs Monitor Configfile
###################################################

DOMAIN          = example.com
LOG_DIR         = /var/log/crt-watch
REPORT_NEW      = yes
EMAIL_FROM      = CRT Admin <crt_admin@example.com>
EMAIL_TO        = crt_admin@example.com
EMAIL_CC        = 
EMAIL_BCC       = 
EMAIL_SUBJECT   = 
```

The script needs access to [crt.sh](https://crt.sh).

**Crontab**

The script can be run, for example, via cron:

```
30 * * * *	/usr/local/bin/crt-watch.sh -c /etc/crt-watch/sample.cfg
```
where you can control the frequency of how often you want to monitor the specified domain. Please do not abuse [crt.sh](https://crt.sh) by running the script too frequently.

