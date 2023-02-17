#!/bin/bash

accepted_urls=()
obligatory_headers=()

GRAY='\033[0;37m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'
if [ -f ./tmp_config ]; then rm tmp_config; fi

function show_banner() {
  local version="1.0"
  echo -e "${RED}\n==============================================================================================${NC}"
  local logo="${RED}
  ╔═╗┬ ┬┬─┐┌─┐┌─┐┌─┐┌─┐┌┐┌╦ ╦┌─┐┬─┐┌─┐
  ║╣ │ │├┬┘│ │├─┘├┤ ├─┤│││╠═╣├─┤├┬┘├┤  ${NC}C2 HTTPS REDIRECTOR${RED}
  ╚═╝└─┘┴└─└─┘┴  └─┘┴ ┴┘└┘╩ ╩┴ ┴┴└─└─┘ $version ${NC}"
  echo -e "$logo"
  echo -e "${RED}==============================================================================================${NC}"

}

function update_system() {
	echo ""
	echo -e "${RED}[+] UPDATING SYSTEM...${NC}"
	apt-get update
}
function install_nginx() {
	if ! dpkg-query -W nginx 2>/dev/null | grep -q "^nginx"; then
		echo -e "${RED}[+] INSTALLING NGINX...${NC}"
		apt-get --assume-yes install nginx
	fi

}
function stop_nginx() {
	echo -e "${RED}[+] STOPPING NGINX AND BACKING UP CONFIGURATION FILES...${NC}\n"
	service nginx stop
	now=$(date +"%s")
	mv /etc/nginx/sites-enabled/ /etc/nginx/sites-enabled_bak_${now}/
	mkdir /etc/nginx/sites-enabled
}
function cert_get() {
	echo -e "${RED}[+] GETTING SSL CERTIFICATES WITH CERTBOT...${NC}"
	if [ ! -f /usr/bin/certbot ]; then
		echo -e "${GRAY}"
		sudo snap install --classic certbot
		sudo ln -s /snap/bin/certbot /usr/bin/certbot
		echo -e "${NC}"
	else
		echo -e "${RED}[+] CERTBOT DETECTED${NC}"
	fi

	sudo certbot certonly --standalone -d $domain --agree-tos --register-unsafely-without-email --non-interactive --expand
	echo -e "${RED}[+] SSL CERTIFICATES CREATED${NC}"
	echo -e "${RED}[+] PATH TO CERTS: ${NC}/etc/letsencrypt/live/$domain/"
}
function add_url() {
	echo -e -n "${RED}ENTER NEW URL TO ACCEPT: ${NC}"
		read new_url
  accepted_urls+=("$new_url")
  echo -e "${RED}NEW URL ADDED: ${NC}$new_url"
}
function add_header() {
	echo -e -n "${RED}ENTER NEW OBLIGATORY HEADER: ${NC}"
		read new_header
	obligatory_headers+=("$new_header")
	echo -e -n "${RED}ENTER ${NC}$new_header${RED} VALUE: ${NC}"
		read header_value
	obligatory_header_values+=("$header_value")
	echo -e "${RED}NEW HEADER ADDED: ${NC}$new_header ${RED}WITH VALUE ${NC}$header_value"
}
function clone_site(){
	mkdir /opt/sites
	echo -e -n "${RED}PROVIDE SITE TO CLONE: ${NC}"
	read site_to_clone
	echo -e "${RED}SITE WILL BE CLONNED TO DIRECTORY${NC} /opt/sites/$domain"
	nohup wget -P /opt/sites --limit-rate=200k --reject pdf --no-clobber --convert-links --random-wait -r -p -E -e robots=off -U mozilla $site_to_clone &


}
function fireup(){
	local urls_rules=""
	local headers_check_rules=""
	clonned_domain=$(echo $site_to_clone | sed 's/https:\/\///'| sed 's/http:\/\/// ')
	config_1="server {\n"
	config_1+="\tlisten 443 ssl;\n"
	config_1+="\tserver_name $domain;\n\n"
	config_1+="\troot /opt/sites/$clonned_domain/;\n\n"
	config_1+="\tssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;\n"
	config_1+="\tssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;\n"
	config_1+="\tssl_session_cache shared:SSL:1m;\n"
	config_1+="\tssl_session_timeout 10m;\n"
	config_1+="\tssl_ciphers HIGH:!aNULL:!MD5;\n"
	config_1+="\tssl_prefer_server_ciphers on;\n"
	for i in "${!obligatory_headers[@]}"; do
		header="${obligatory_headers[$i]}"
		value="${obligatory_header_values[$i]}"
		headers_check_rules+="\t\tif (\$http_$header != \"$value\") {\n"
		headers_check_rules+="\t\t\treturn 403;\n"
		headers_check_rules+="\t\t}\n"
	done
	for url in "${accepted_urls[@]}"; do
		urls_rules+="\tlocation = $url {\n"
		urls_rules+="\t\tif (\$remote_addr !~ \"$client_ip\") {\n"
		urls_rules+="\t\t\treturn 403;\n"
		urls_rules+="\t\t}\n"
		urls_rules+="$headers_check_rules"
		urls_rules+="\t\tproxy_pass http://$c2_ip:$c2_port;\n"
		urls_rules+="\t\tproxy_set_header Host \$host;\n"
		urls_rules+="\t\tproxy_set_header X-Real-IP \$remote_addr;\n"
		urls_rules+="\t\tproxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\n"
		urls_rules+="\t\tproxy_set_header X-Forwarded-Proto https;\n"
		urls_rules+="\t}\n"
	done
	local resulting_config=""
	resulting_config+="$config_1"
	resulting_config+="$urls_rules"
	resulting_config+="\tlocation / {\n"
	resulting_config+="\t\troot /opt/sites/$clonned_domain;\n"
	resulting_config+="\t\ttry_files \$uri \$uri/index.html =404;\n"
	resulting_config+="\t}\n"
	resulting_config+="}"

	echo -e $resulting_config >> tmp_config

	if [ -f /etc/nginx/sites-available/$domain ]; then rm /etc/nginx/sites-available/$domain; fi
	if [ -f /etc/nginx/sites-enabled/$domain ]; then rm /etc/nginx/sites-enabled/$domain; fi
	mv tmp_config /etc/nginx/sites-available/$domain
	sudo ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/

	echo -e "${RED}\n==============================================================================================${NC}"
	echo -e "${RED}NGINX CONFIGURATION FILE GENERATED:${YELLOW}"
	cat /etc/nginx/sites-enabled/$domain
	echo -e "${NC}"
	echo -e "${RED}==============================================================================================${NC}"
	echo -e "${NC}(C2)${RED}$c2_ip${NC}:${RED}$c2_port${NC}<---${RED}SSL${NC}---(Current host)${RED}$domain${NC}:${RED}$redirector_port${NC}<---${RED}SSL${NC}---(Client)${RED}$client_ip${RED}"
	echo -e "${RED}==============================================================================================${NC}"
	echo -e "${RED}\nOBLIGATORY HEADERS:${NC}"
	for ((i=0; i<${#obligatory_headers[@]}; i++)); do
	  echo -e "${RED}$((i+1)). ${NC}${obligatory_headers[$i]}: ${obligatory_header_values[$i]}"
	done
	echo -e "${RED}\nACCEPTED URLS:${NC}"
	for ((i=0; i<${#accepted_urls[@]}; i++)); do
	  echo -e "${RED}$((i+1)).${NC}https://$domain${accepted_urls[$i]}"
	done
	echo -e "\n${RED}\nWEB SERVICE TO MIMICRY:${NC}$site_to_clone\n"

	echo -e "${RED}NGINX CONFIG REAL FILE PATH:${NC}/etc/nginx/sites-available/$domain"
	echo -e "${RED}NGINX CONFIG LINK PATH:${NC}/etc/nginx/sites-enabled/$domain"
	echo -e "${RED}PATH TO SSL KEY:${NC}/etc/letsencrypt/live/$domain/privkey.pem"
	echo -e "${RED}PATH TO SSL CERT:${NC}/etc/letsencrypt/live/$domain/fullchain.pem"
	echo -e "${RED}\n==============================================================================================${NC}"
	sudo service nginx reload
	sudo service nginx start
	sudo service nginx status
	echo -e "${RED}\n==============================================================================================${NC}"
	exit
}
function list_urls(){
	echo -e "${RED}\nACCEPTED URLS:${NC}"
	for ((i=0; i<${#accepted_urls[@]}; i++)); do
	  echo -e "${RED}$((i+1)).${NC}https://$domain${accepted_urls[$i]}"
	done
}
function list_headers(){
	echo -e "${RED}\nOBLIGATORY HEADERS:${NC}"
	for ((i=0; i<${#obligatory_headers[@]}; i++)); do
	  echo -e "${RED}$((i+1)). ${NC}${obligatory_headers[$i]}: ${obligatory_header_values[$i]}"
	done
}

function showmenu(){
	while true; do
	  echo ""
	  echo -e "${RED}SELECT AN OPTION:${NC}"
	  echo -e "${RED}1.${NC} LIST ACCEPTED URLS"
	  echo -e "${RED}2.${NC} LIST ACCEPTED HEADERS"
	  echo -e "${RED}3.${NC} ADD ACCEPTED URL"
	  echo -e "${RED}4.${NC} ADD OBLIGATORY HEADER"
	  echo -e "${RED}5.${NC} FIREUP!!!"
	  echo ""
	  echo -e -n "${RED}ENTER OPTION NUMBER: ${NC}"
	  	read option
	  case $option in
	    1) list_urls;;
	    2) list_headers;;
	    3) add_url;;
	    4) add_header;;
	    5) clone_site && fireup;;
	    *) echo -e "\n${RED}INVALID OPTION. PLEASE TRY AGAIN.${NC}";;
	  esac
	done
}
function main() {
	show_banner
	echo ""
	update_system
	install_nginx
	stop_nginx
	echo -e -n "${RED}ENTER C2 SERVER IP ADDRESS: ${NC}"
		read c2_ip
	echo -e -n "${RED}ENTER C2 SERVER PORT: ${NC}"
		read c2_port
	echo -e -n "${RED}ENTER DOMAIN NAME THAT POINTS TO CURRENT SERVER: ${NC}"
		read domain
	echo -e -n "${RED}ENTER REDIRECTOR PORT: ${NC}"
		read redirector_port
	echo -e -n "${RED}ENTER CLIENT IP RANGE (IN CIDR NOTATION): ${NC}"
		read client_ip
	cert_get
	showmenu
}

main
