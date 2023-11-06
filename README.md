# cribl-geoipupdate
Keep your Maxmind Database files up to date in Cribl Cloud.

This work is an extension of an idea and scripts originally written by [Jenna Eagle](https://www.linkedin.com/in/jennameagle/)

These scripts will check for updates to the Maxmind GeoLite2-City and GeoLite2-ASN database files and move them to Cribl Cloud if/when there are updates. 

The scripts make a few assumptions in order to work:
* You've already got an API key and secret from Cribl Cloud
* You already have the [GeoIP Update program](https://dev.maxmind.com/geoip/updating-databases) installed from maxmind.com
* You have already uploaded the GeoLite2-City.mmdb and GeoLite2-ASN.mmbd files to Cribl Cloud.  (These scripts will update, but not perform the initial upload.)

Note: Country code database is not handled yet, but should be real soon now.

## What the scripts do
1. The `check_for_updates.sh` script uses the Maxmind GeoIP Update program (see above) to check the version of the GeoLite2-City.mmdb and GeoLite2-ASN.mmbd files and download them locally if there are updates.
2. If there are updates to these files, the `check_for_updates.sh` script calls the `geoip_update.sh` script .
2. Use the [Cribl Cloud API](https://docs.cribl.io/api/) to 
  * Upload the updated .mmdb files
  * Commit and Deploy
  * Commit and Deploy to version control
  * (This loop is repeated for each .mmdb file)

## How to run the scripts
1. Get a Cribl CLoud API key
2. Edit the `config.conf` file
3. Run the `check_for_updates.sh` script
4. Kick back & chill.  Everything should be done for you.