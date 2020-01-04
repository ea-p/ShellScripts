#!/bin/bash
#VARIABLES
myip= 

#create log file
logFileName=init_script_$(date +"%FT%H%M%z").log
printf "Started logging..." > "$logFileName"

#update everything
dnf update -y &> /dev/null
printf "\nUpdated everything." >> "$logFileName"

#install system utilities
dnf install nano vim wget curl net-tools lsof bash-completion -y >> "$logFileName"
dnf clean all
printf "\nInstalled nano, vim, wget, curl, net-tools, lsof and bash-completion. Cleaned up unnnecesary files left over." >> "$logFileName"

#Create custom alias' script
printf "alias sudo='sudo '\nalias rm='rm'\nalias mv='mv'\nalias cp='cp'\nalias ll='ls -la --color=auto'\nalias c='clear'\nalias ..='cd ..'\nalias mkdir='mkdir -pv'\nalias ping='ping -c 5'\n" > /etc/profile.d/global_aliases.sh
chmod a+r /etc/profile.d/global_aliases.sh
printf "\nCreated custom alias script." >> "$logFileName"

#install Fail2Ban
installFail2Ban () {
    printf "\n\nDo you want to install Fail2Ban? (y/n)"
    read -r fail2ban
    if [ "$fail2ban" = "y" ] || [ "$fail2ban" = "Y" ]; then
        dnf install epel-release -y &> /dev/null
        dnf install fail2ban -y &> /dev/null   
        dnf install fail2ban-systemd -y &> /dev/null
        dnf clean all &> /dev/null
        printf "\nInstalled epel-release, fail2ban and fail2ban-systemd." >> "$logFileName"
    fi      
}

installFail2Ban

#configure fail2ban
printf "\nFail2Ban is being configured."
printf "\nFail2Ban is being configured." >> "$logFileName"
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
printf "\nCreated jail.local." >> "$logFileName"
sed -i -E 's!^\n[DEFAULT] *![DEFAULT]\n# Ban IP/hosts for 1 hour ( 24h*3600s = 86400s):\nbantime = 3600\n\n# An ip address/host is banned if it has generated "maxretry" during the last "findtime" seconds.\n\nfindndtime = 300\nmaxretry = 3\n\n# "ignoreip" can be a list of IP addresses, CIDR masks or DNS hosts. Fail2ban\n# will not ban a host which matches an address in this list. Several addresses\n# can be defined using space (and/or comma) separator. For example, add your \n# static IP address that you always use for login such as 103.1.2.3\n#ignoreip = 127.0.0.1/8 ::1 103.1.2.3\nignoreip = '${myip}'\n# Call iptables to ban IP address \nbanaction = iptables-multiport \n\n# Enable sshd protection \n[sshd]\nenabled = true\n\n!' /etc/fail2ban/jail.local
systemctl start fail2ban

#create users function
create_user_with_ssh () {
if [ "$(id -u)" -eq 0 ]; then
    printf "\nStarted new user set up." >> "$logFileName"
    printf "\n\nEnter username : "
	read -r username
    printf "%s\nAttempting to create user: $username" >> "$logFileName"
	
	if  grep -E  "^$username" /etc/passwd >/dev/null -eq 0 ; then
		printf "%s\n\n$username exists!" >> "$logFileName"
		exit 1
	else
		if useradd -m "$username"; then printf "%s\nUser $username has been added to system!" >> "$logFileName"
            else printf "Failed to add a user!" >> "$logFileName"
        fi
		#[ $? -eq 0 ] && printf "%s\nUser $username has been added to system!" >> "$logFileName"  || printf "Failed to add a user!" >> "$logFileName" 
        printf "%s\nAdd User $username to sudoers group? (y/n) "
        read -r answer_sudoers
        if [ "$answer_sudoers" = y ]; then
            printf "%s\nAttempting to user: $username to sudoers group" >> "$logFileName"
            usermod -aG wheel "$username";
            printf "...done." >> "$logFileName"
        fi
        if [ ! -e /home/"$username"/.ssh ]; then
            mkdir /home/"$username"/.ssh
            printf "%s\nCreated .ssh folder for user: $username." >> "$logFileName"
        elif [ ! -d /home/"$username"/.ssh ]; then
            printf "%s\n/home/$username/.ssh already exists but is not a directory" >> "$logFileName";
        fi
        if [ ! -e /root/userkeys ]; then
            mkdir /root/userkeys
            printf "\nCreated 'userkeys' folder, if not already there." >> "$logFileName"
        elif [ ! -d /root/userkeys ]; then
            printf "\n/root/userkeys already exists but is not a directory" >> "$logFileName";
        fi
	fi
else
	printf "\n\nError: Only root may add a user to the system" >> "$logFileName"
	exit 2
fi

#create private/pub key pair and download private key

# {
#    ssh-keygen -t rsa -b 4096 -f /home/"$username"/.ssh/id_rsa;
#    cat /home/"$username"/.ssh/id_rsa.pub > /home/"$username"/.ssh/authorized_keys;
#    chmod -R a-rwx /home/"$username"/.ssh;
#    chown -R "$username" /home/"$username"/.ssh;
#    chmod -R a+r /home/"$username"/.ssh;
#    printf "%s\nGenerated public-private keypair for user: $username.";
#} >> "$logFileName"
#cp /home/"$username"/.ssh/id_rsa /root/userkeys/"${username}"_id_rsa
#printf "%s\nCopied private key for user: $username to userkeys folder." >> "$logFileName"
#less /home/"$username"/.ssh/id_rsa
#pause () {
#   read -r "$*"
# }

#ask if another user is to be made
read_answer () {
    printf "\nDo you want to create another user? (y/n) : "
    read -r answer
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]
        then create_user_with_ssh
    fi
}
read_answer
}

#call create user function
create_user_with_ssh


#modify sshd conf
#Modify SSH Port
modifySSHPort () {
    printf "\nStarted changing ssh port." >> "$logFileName"
    printf "\nEnter new SSH Port: "
    read -r port
    #if [ ! "$port" =~ $re ] ; then
    if echo "$port" | grep -Eq '(?!^[0-9]+$)'; then
        printf "\nerror: Not a valid port" >> "$logFileName"; modifySSHPort
    fi
    { 
        sed -i -E "s:^#Port 22*:Port $port:" /etc/ssh/sshd_config;
        sed -i -E "s:^Port 22*:Port $port:" /etc/ssh/sshd_config;
     } >> "$logFileName"
    printf "%s\nChanged ssh port to: $port." >> "$logFileName"
}

modifySSHPort

#modify LoginGraceTime
modifyLoginGraceTime () {
    printf "\nStarted modyfing LoginGraceTime." >> "$logFileName"
    printf "\nSet new LoginGraceTime. Standard is 2 minutes (2m): "
    read -r loginGraceTime
    if echo "$loginGraceTime" | grep -Eq '(?!^[0-9]+[sm]$)' ; then
    #if [ ! "$loginGraceTime" =~ ^[0-9]+[sm]$ ] ; then
        printf "\nerror: Not a valid LoginGraceTime format!" >> "$logFileName"; modifyLoginGraceTime
    fi
    {
    sed -i -E "s:^#LoginGraceTime 2m*:LoginGraceTime $loginGraceTime:" /etc/ssh/sshd_config;
    sed -i -E "s:^LoginGraceTime 2m*:LoginGraceTime $loginGraceTime:" /etc/ssh/sshd_config;
    printf "%s\nChanged LoginGraceTime to: $loginGraceTime.";
    } >> "$logFileName"
}

modifyLoginGraceTime

#modify PermitRootLogin
modifyPermitRootLogin () {
    printf "\nStarted changing PermitRootLogin." >> "$logFileName"
    printf "\n\nSet wether the root user may login directly or not (y/n): "
    read -r permitRootLogin
    if echo "$permitRootLogin" | grep -Eq '(?![yn])' ; then
    #if [ ! "$permitRootLogin" = [yn] ] ; then
        printf "\nerror: Not a valid answer!" >> "$logFileName"; modifyPermitRootLogin
    fi
    if [ "$permitRootLogin" = "y" ] ; then
        modifyLoginGraceTime_value=yes
        else modifyLoginGraceTime_value=no
    fi 
    {
    sed -i -E "s:^#PermitRootLogin (yes|no)*:PermitRootLogin $modifyLoginGraceTime_value:" /etc/ssh/sshd_config;
    sed -i -E "s:^PermitRootLogin (yes|no)*:PermitRootLogin $modifyLoginGraceTime_value:" /etc/ssh/sshd_config;
    printf "%s\nChanged PermitRootLogin to: $modifyLoginGraceTime_value.";
    } >> "$logFileName"
}

modifyPermitRootLogin

#set PubkeyAuthentication
setPubkeyAuthentication () {
    printf "\nStarted changing PubKeyAuthentication." >> "$logFileName"
    printf "\n\nSet PubkeyAuthentication (y/n): "
    read -r pubkeyAuthentication
    if echo "$pubkeyAuthentication" | grep -Eq '(?![yn])' ; then
    #if [ ! "$pubkeyAuthentication" = [yn] ] ; then
        printf "\nerror: Not a valid answer!" >> "$logFileName"; setPubkeyAuthentication
    fi
    if [ "$pubkeyAuthentication" = "y" ] ; then
        pubkeyAuthentication_value=yes
        else pubkeyAuthentication_value=no
    fi
    {
    sed -i -E "s:^#PubkeyAuthentication (yes|no)*:PubkeyAuthentication $pubkeyAuthentication_value:" /etc/ssh/sshd_config;
    sed -i -E "s:^PubkeyAuthentication (yes|no)*:PubkeyAuthentication $pubkeyAuthentication_value:" /etc/ssh/sshd_config;
    printf "%s\nChanged PubkeyAuthentication to: $pubkeyAuthentication_value.";
    } >> "$logFileName"
}

setPubkeyAuthentication


#set PasswordAuthentication
setPasswordAuthentication () {
    printf "\nStarted changing PasswordAuthentication." >> "$logFileName"
    printf "\n\nSet PasswordAuthentication (y/n): "
    read -r passwordAuthentication
    if echo "$pubkeyAuthentication" | grep -Eq '(?![yn}])' ; then
    #if [ ! "$pubkeyAuthentication" = [yn] ] ; then
        printf "\nerror: Not a valid answer!" >> "$logFileName"; setPasswordAuthentication
    fi
    if [ "$passwordAuthentication" = "y" ] ; then
        passwordAuthentication_value=yes
        else passwordAuthentication_value=no
    fi
    {
    sed -i -E "s:^#PasswordAuthentication (yes|no)*:PasswordAuthentication $passwordAuthentication_value:" /etc/ssh/sshd_config;
    sed -i -E "s:^PasswordAuthentication (yes|no)*:PasswordAuthentication $passwordAuthentication_value:" /etc/ssh/sshd_config;
    printf "%s\nChanged PasswordAuthentication to: $passwordAuthentication_value.";
    } >> "$logFileName"
}

setPasswordAuthentication

#install firewall, add new ssh port and initialize
installFirewalld () {
    printf "\nStarted firewalld installation."
    printf "\nfirewalld will be installed."
    dnf -y install firewalld &> /dev/null
    dnf clean all &> /dev/null
    printf "\nFirewalld succesfully installed. Installation was cleaned up."
    systemctl start firewalld
    systemctl enable firewalld
} 

installFirewalld >> "$logFileName"

#configure firewalld
{ 
    firewall-cmd --zone=public --add-service=http --permanent;
    firewall-cmd --zone=public --add-service=https --permanent;
    firewall-cmd --zone=public --remove-port=22/tcp --permanent; 
    firewall-cmd --zone=public --add-port="$port"/tcp --permanent; 
    firewall-cmd --reload; 
} >> "$logFileName"

#install cockpit
{ 
    dnf install -y cockpit;
    systemctl enable --now cockpit.socket;
} >> "$logFileName"