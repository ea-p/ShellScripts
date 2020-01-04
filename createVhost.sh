#!/bin/bash

#VARIABLES
while getopts s:a:i:p:h option
do
case "${option}"
in
s) SITE=${OPTARG};;
a) APPROOT=${OPTARG};;
i) IP=${OPTARG};;
p) PORT=${OPTARG};;
h) HELP=HELP;;
*) 
esac
done

a2ensite=/usr/local/bin/a2ensite
a2dissite=/usr/local/bin/dis2ensite
vhost=1


if [[ -n "$HELP" ]]; then
printf "Script help goes here!\n"
show_help
exit 1
fi

if [[ -n "$APPROOT" ]]; then
    if [[ -n "$IP" ]] || [[ -n "$PORT" ]]; then
        printf "Either port or IP is not specified for the reverse proxy!"
        exit 1
    fi
    vhost=2
fi

#PREREQs
##FUNCTIONS
show_help () {
echo "
        Usage: Environment DBPassword [-s Website] [-a Approot] [-i IP] [-p Port]

        -s Website      Website name without www ex:example.com.
        -a Approot      Revision number (0 means the latest revision).
        -i IP           IP of proxied application
        -o PORT         Port of porxied appliaction

        For Example: ./createVhost.sh -s example.com -a /appliation -i 80.80.80.80 -p 80

        -h              Help
"
}

create_a2ensite () {
cat <<END_SCRIPT > sudo tee /usr/local/bin/a2ensite
#!/bin/bash
if test -d /etc/httpd/sites-available && test -d /etc/httpd/sites-enabled  ; then
echo "-----------------------------------------------"
else
mkdir /etc/httpd/sites-available
mkdir /etc/httpd/sites-enabled
fi

avail=/etc/httpd/sites-available/$1.conf
enabled=/etc/httpd/sites-enabled/
site=`ls /etc/httpd/sites-available/`

if [ "$#" != "1" ]; then
                echo "Use script: a2ensite virtual_site"
                echo -e "\nAvailable virtual hosts:\n$site"
                exit 0
else

if test -e $avail; then
sudo ln -s $avail $enabled
else

echo -e "$avail virtual host does not exist! Please create one!\n$site"
exit 0
fi
if test -e $enabled/$1.conf; then

echo "Success!! Now restart Apache server: sudo systemctl restart httpd"
else
echo  -e "Virtual host $avail does not exist!\nPlease see available virtual hosts:\n$site"
exit 0
fi
fi
END_SCRIPT
sudo chmod +x /usr/local/bin/a2ensite
}

create_a2dissite () {
cat <<END_SCRIPT > sudo tee /usr/local/bin/a2dissite
#!/bin/bash
avail=/etc/httpd/sites-enabled/$1.conf
enabled=/etc/httpd/sites-enabled
site=`ls /etc/httpd/sites-enabled/`

if [ "$#" != "1" ]; then
                echo "Use script: a2dissite virtual_site"
                echo -e "\nAvailable virtual hosts: \n$site"
                exit 0
else

if test -e $avail; then
sudo rm  $avail
else
echo -e "$avail virtual host does not exist! Exiting!"
exit 0
fi

if test -e $enabled/$1.conf; then
echo "Error!! Could not remove $avail virtual host!"
else
echo  -e "Success! $avail has been removed!\nPlease restart Apache: sudo systemctl restart httpd"
exit 0
fi
fi
END_SCRIPT
sudo chmod +x /usr/local/bin/a2dissite
}

create_vhost () {
cat<<END_SCRIPT > /etc/httpd/sites-available/"${SITE}".conf
<VirtualHost *:80>

    ServerName www."${SITE}"
    ServerAlias "${SITE}"
    DocumentRoot /var/www/"${SITE}"/public_html
    ErrorLog /var/www/"${SITE}"/logs/error.log
    CustomLog /var/www/"${SITE}"/logs/requests.log combined
</VirtualHost>
END_SCRIPT
};

create_proxyvhost () {
CAT<<END_SCRIPT > /etc/httpd/sites-available/"${SITE}".conf
<VirtualHost *:*>
    ProxyPreserveHost On

    # Servers to proxy the connection, or;
    # List of application servers:
    # Usage:
    # ProxyPass / http://[IP Addr.]:[port]/
    # ProxyPassReverse / http://[IP Addr.]:[port]/
    # Example: 
    ProxyPass /.well-known !
    ProxyPass "${APPROOT}" http://"${IP}":"${PORT}"/ 
    ProxyPassReverse "${APPROOT}" http://"${IP}":"${PORT}"/

    ServerName localhost
</VirtualHost>
END_SCRIPT
};

##a2ensite and a2dissite Scripts

if ! [[ -f "$a2ensite" ]]; then
    create_a2ensite
fi

if ! [[ -f "$a2dissite" ]]; then
    create_a2dissite
fi

#CREATE VHOST FOLDERS (public_html, logs)
sudo mkdir -p /var/www/"${SITE}"/logs
sudo mkdir -p /var/www/"${SITE}"/public_html
sudo chmod +r -R /var/www/"${SITE}"


#CREATE VHOST
if [[ $vhost = 2 ]]; then
    if [[ -n "$IP" ]] || [[ -n "$PORT" ]]; then
        printf "Either port or IP is not specified for the reverse proxy!"
        exit 1
    fi
    create_proxyvhost; else
    create_vhost
fi
#RUN LETSENCRYPT