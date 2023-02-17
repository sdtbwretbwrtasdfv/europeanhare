# EUROPEANHARE - HTTPS Redirector

This is a Bash script that creates an HTTPS redirector using NGINX web server and Certbot SSL certificates. 
The redirector proxies incoming https requests to a Command and Control (C2) server, only if the requests meet specific criteria. 
Following check includeds:
- Check URLs
- Check headers
- Chack headers values
- Check client IP

## Configuration
The script will guide you through the configuration process, which includes:
- Updating the system
- Installing NGINX
- Stopping NGINX and backing up configuration files
- Getting SSL certificates with Certbot
- Adding accepted URLs
- Adding obligatory headers
- Cloning a site
- Generating the NGINX configuration file
- Starting NGINX and verifying its status
- License

This script is licensed under the MIT License.

## Disclaimer

This script is provided as-is, and is intended for educational and research purposes only. The authors of this script are not responsible for any damages or illegal activities resulting from the use of this script. Use at your own risk.
