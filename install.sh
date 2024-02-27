#!/bin/bash
#This script is used to install docker, build the container and configure everything
dockerContainerName="ready-at-dawn-echo-arena"
rsyncCommand="rsync -crtz --progress --partial --compress-level=0 "


configJson='{
  "publisher_lock": "_publisher_lock",
  "apiservice_host": "_apiservice_host",
  "configservice_host": "_configservice_host",
  "loginservice_host": "_loginservice_host",
  "matchingservice_host": "_matchingservice_host",
  "serverdb_host": "_serverdb_host",
  "transactionservice_host": "_transactionservice_host"
}'


#This function asks the user if he wants to download Echo and if so, it downloads Echo
function downloadEcho {
    #check if he wants to download
    echo -e "Do you want to Download the newest Echo Binarys? If you dont you need to provide them by your own. For this download to work you need to provide a file called rsyncHosts inside the same folder like this script \"$PWD.\"\
    Ask your Relay Provider for that file. If you contribute your Server to the Echo VR Lounge, you can contact me on Discord: marcel_One_ \nEnter y/Y for Yes, n/N for No."
    read checkdownloadEcho
    #checks if the answer is correct
    if ! [[ "$checkdownloadEcho" =~ [yYnN]{1} ]]
    then
        echo "Wrong Input. Please try again."
        downloadEcho
        return 160 # I started to choose random numbers due to laziness...
    
    fi
    if [[ "$checkdownloadEcho" =~ [yY] ]]
    then
        if ! [[ -f ./rsyncHosts ]]
        then
            echo "The rsyncHosts-file is missing. The script will be stopped now. It needs to be located at $PWD"
            echo -e '\033[0m' # No Color
            exit
        fi
        readarray -t rsyncHosts < $PWD/rsyncHosts
        installNeededSoftware
        echo -e '\033[0;31m' #write in red
        echo "Echo will now be downloaded. We will test the Download-Speeds now to automatically choose the fastest server.\
        Please do not abort! Depending on the connection to the server it could take like 2 min. The filesize is like 10mb btw."
        echo -e '\033[0m' # No Color
        #give time to read
        sleep 5
        installNeededSoftware
        serverCounter=0

        for host in ${rsyncHosts[@]}
        do        
            echo "Testing Server $( echo "$serverCounter+1" | bc)"
            #CHECK DOWNLOAD SPEED
            rm ./temp/malgun.ttf 2> /dev/null
            downloadStart[$serverCounter]=`date +%s.%N`
            output[$serverCounter]=$( $rsyncCommand$host/content/engine/core/fonts/malgun.ttf ./temp/ | tee /dev/tty )
            rm -r ./temp
            downloadEnd[$serverCounter]=`date +%s.%N`
            #If there was an error. set the time to 99999, otherwise calculate the real time
            if [[ "${output[$serverCounter]}" =~ 100\%.* ]]
            then
                speedtest[$serverCounter]=$( echo "${downloadEnd[$serverCounter]}-${downloadStart[$serverCounter]}" | bc )
            else
                speedtest[$serverCounter]=99999
            fi
            ((serverCounter++))
        done
    
        checkCounter=0
        fastestServer=0
        #check which server was the fastest
        while [[ $checkCounter+1 -lt ${#rsyncHosts[@]} ]]
        do
            calculate=$( echo "${speedtest[fastestServer]}-${speedtest[$checkCounter+1]}" | bc)
            #If calculate is not -XXX, the $checkCounter+1 is faster
            if ! [[ $calculate =~ -.* ]]
            then
                fastestServer=$(echo "$checkCounter+1" | bc)
            fi
            ((checkCounter++))
        done
       
        #If the winning time is 99999 there is an error on all server, exit the script
        if [[ "${speedtest[$fastestServer]}" =~ 99999 ]]
        then
            echo -e '\033[0;31m' #write in red
            echo "No connection to any Download-Server possible. Please try again."
            echo -e '\033[0m' # No Color
            exit
        fi
                
        echo "Download starts with host $fastestServer, speed: ${speedtest[$fastestServer]}"
        #Start the download
        $rsyncCommand${rsyncHosts[$fastestServer]}/. ./ready-at-dawn-echo-arena        
    fi
    secondInstallValue=true
}



#This function checks if the echo folder is available
function checkForEchoFolder {
    if ! [ -d "./ready-at-dawn-echo-arena" ]
    then
        scriptPath="$(dirname -- "${BASH_SOURCE[0]}")"
        echo "No ready-at-dawn-echo-arena-Folder found. It needs to be in the same folder like this script: $PWD"
        exit
    fi
    
}


#This function asks the user if he wants to get automatically updates
function checkIfUserWantsUpdates {
    echo -e '\033[0;31m' #write in red
    echo "Do you want to get automatically updates of the Echo Server Files? In case of an update we will slowly close server Instances with no matches in it, update the serverfiles and restart the server instances. \
Files you want to be excluded will be set inside ./files/exclude.list. netconfig files and config.json will be automatically excluded. To deactivate the automatic updates afterwards, you need to delete the line inside your crontab file.
Open the crontab file with 'crontab -e' The default check rythm is every 30min. To change that you also need to edit the crontab file.  \
Enter y/Y for Yes, n/N for No."
    read askUpdate
    #check the users answer
    if ! [[ "$askUpdate" =~ [yYnN]{1} ]]
    then
        echo "Wrong Input. Please try again."
        checkIfUserWantsUpdates
        return 17
    fi
    if [[ "$askUpdate" =~ [yY]{1} ]]
    then
        #check if a cronjob file exists
        if [[ -f /var/spool/cron/crontabs/$(whoami) ]]
        then    
            if crontab -l | grep -q "echo_update.sh" 
            then
                echo "Cronjob is already set"
            else
                tempCron=$(crontab -l)
                echo -e "$tempCron\n*/30 * * * * /bin/bash '$(echo $PWD)/scripts/echo_update.sh'" > /var/spool/cron/crontabs/$(whoami)
                crontab /var/spool/cron/crontabs/$(whoami)
            fi
        else
            tempCron="# Edit this file to introduce tasks to be run by cron.
# Each task to run has to be defined through a single line
# indicating with different fields when the task will be run
# and what command to run for the task
#
# To define the time you can provide concrete values for
# minute (m), hour (h), day of month (dom), month (mon),
# and day of week (dow) or use "*" in these fields (for "any").
#
# Notice that tasks will be started based on the crons system
# daemons notion of time and timezones.
#
# Output of the crontab jobs (including errors) is sent through
# email to the user the crontab file belongs to (unless redirected).
#
# For example, you can run a backup of all your user accounts
# at 5 a.m every week with:
# 0 5 * * 1 tar -zcf /var/backups/home.tgz /home/
#
# For more information see the manual pages of crontab(5) and cron(8)
#
# m h  dom mon dow   command
*/30 * * * * /bin/bash '$(echo $PWD)/scripts/echo_update.sh'" 
        echo -e "$tempCron" > /var/spool/cron/crontabs/$(whoami)
        crontab /var/spool/cron/crontabs/$(whoami)
        fi
    fi
}


#This function asks the user if he wants to configure the config.json
function checkIfUserWantsConfigure {
    echo "Do you want to configure the config.json file? If not, you need to create one by yourself. Enter y/Y for Yes, n/N for No."
    read askconfigure
    if ! [[ "$askconfigure" =~ [yYnN]{1} ]]
    then
        echo "Wrong Input. Please try again."
        checkIfUserWantsConfigure
        return 16
    fi

}

#This function gets parameters from User
function getNeededParameterFromSTDin {
    echo -e '\033[0;31m' #write in red
    #Get parameters:S
    echo "To connect to the Relay-Server we need the following Informations."
    echo "Please enter the 'publisher_lock'. It could be something like 'echovrce' or 'rad15_live'"
    read publisher_lock
    echo "Please enter the 'apiservice_host'. It should look like 'http[s]://69.133.74.20[:1337]' or 'http[s]://example.org[:1337]'"
    read apiservice_host
    echo "Please enter the configservice_host. It should look like 'ws://69.133.74.20[:1337]' or ws://config.example.org[:1337]"
    read configservice_host
    echo "Please enter the loginservice_host. It should look like 'ws://69.133.74.20[:1337]' or ws://login.example.org[:1337]"
    read loginservice_host
    echo "Please enter the matchingservice_host. It should look like 'ws://69.133.74.20[:1337]' or ws://matchmaker.example.org[:1337]"
    read matchingservice_host
    echo "Please enter the serverdb_host. It should look like 'ws://69.133.74.20[:1337]' or ws://transaction.example.org[:1337]"
    read serverdb_host
    echo "Please enter the transactionservice_host. It should look like 'ws://69.133.74.20[:1337]' or ws://transaction.example.org[:1337]"
    read transactionservice_host

    
    if [[ $publisher_lock  == "" ]] || [ "$apiservice_host"  == "" ] || [ "$configservice_host"  == "" ] || [ "$loginservice_host"  == "" ] || [ "$matchingservice_host"  == "" ] || [ "$serverdb_host"  == "" ] || [ "$transactionservice_host"  == "" ] 
    then        
        echo "At least one of the entered Parameters is empty"
        #If something empty, start again
        getNeededParameterFromSTDin
        return 10
    fi
    
    #Do some Regex to check the results
    if ! [[ $publisher_lock =~ [-A-Za-z0-9_]+ ]] \
    || ! [[ $apiservice_host =~ http[s]?:\/\/[-\+\.A-Za-z0-9]+:?(\d*) ]] \
    || ! [[ $configservice_host =~ ws:\/\/[-\+\.A-Za-z0-9]+:?(\d*) ]] \
    || ! [[ $loginservice_host =~ ws:\/\/[-\+\.A-Za-z0-9]+:?(\d*) ]] \
    || ! [[ $matchingservice_host =~ ws:\/\/[-\+\.A-Za-z0-9]+:?(\d*) ]] \
    || ! [[ $serverdb_host =~ ws:\/\/[-\+\.A-Za-z0-9]+:?(\d*) ]] \
        || ! [[ $transactionservice_host =~ ws:\/\/[-\+\.A-Za-z0-9]+:?(\d*) ]] 

    then
        echo "Error, at least one of the parameters syntax is wrong. Please try again"
        getNeededParameterFromSTDin
        return 15

    fi
    

    #Ask if the parameters are correct
    echo "Are these Parameters correct?"
    echo "publisher_lock: "$publisher_lock
    echo "apiservice_host: "$apiservice_host
    echo "Configservice_host: "$configservice_host
    echo "loginservice_host: "$loginservice_host
    echo "matchingservice_host: "$matchingservice_host
    echo "serverdb_host: "$serverdb_host
    echo "transactionservice_host: "$transactionservice_host
    echo "Enter y/Y for Yes, anything else for No" 
    read answer
    #If not correct, start again
    if ! [[ $answer =~ [yY]{1} ]]
    then
        getNeededParameterFromSTDin
        return 11      
    fi
    
}




function getRegion {
    echo -e '\033[0;31m' #write in red
    echo 'Please enter your Region:
    "uscn", // US Central North (Chicago)
    "us-central-2", // US Central South (Texas)
    "us-central-3", // US Central South (Texas)
    "use", // US East (Virgina)
    "usw", // US West (California)
    "euw", // EU West 
    "jp", // Japan (idk)
    "sin", // Singapore oce region
    '
    read region
    echo $region
    if ! [ "$region" = "uscn" ] && ! [ "$region" = "us-central-2" ] && ! [ "$region" = "us-central-3" ] && ! [ "$region" = "use" ] && ! [ "$region" = "usw" ] && ! [ "$region" = "euw" ] && ! [ "$region" = "jp" ] && ! [ "$region" = "sin" ]
    then
        echo "Wrong Region. Please enter again:"
        getRegion
        return 15
    fi   
    
}


#this function checks and writes the config.json
function writeConfigFile {
    echo -e '\033[0;31m' #write in red
    echo "Do you want to see the config.json before we write it? Enter y/Y for Yes, anything else for No."
    read askCheck
    if [[ "$askCheck" =~ [yY]{1} ]]
    then
        echo "$(echo "$configJson" | sed -e "s!_publisher_lock!$publisher_lock!g" -e "s!_apiservice_host!$apiservice_host!g" -e "s!_configservice_host!$configservice_host!g" -e "s!_loginservice_host!$loginservice_host!g" \
        -e "s!_matchingservice_host!$matchingservice_host!g" -e "s!_serverdb_host!$serverdb_host!g" -e "s!_transactionservice_host!$transactionservice_host!g" )"
        echo "Is this config correct? If you don't Enter y/Y we will ask you the Parameters again"
        read askCorrect
        if ! [[ "$askCorrect" =~ [yY]{1} ]]
        then
            getNeededParameterFromSTDin
            writeConfigFile
            return 12
        fi
    fi
    echo "The installation of Docker will now start"
    sleep 3 
    mv ./ready-at-dawn-echo-arena/_local/config.json ./ready-at-dawn-echo-arena/_local/config.json_backup
    echo "$(echo "$configJson" | sed -e "s!_publisher_lock!$publisher_lock!g" -e "s!_apiservice_host!$apiservice_host!g" -e "s!_configservice_host!$configservice_host!g" -e "s!_loginservice_host!$loginservice_host!g" \
    -e "s!_matchingservice_host!$matchingservice_host!g" -e "s!_serverdb_host!$serverdb_host!g" -e "s!_transactionservice_host!$transactionservice_host!g" )" > ./ready-at-dawn-echo-arena/_local/config.json
}


      




#change the region
function writeRegion {
    sed -i -e "s/region='.*'/region='$region'/g" ./scripts/start-echo.sh    
}


#this function checks for the OS
function checkOS {
    echo -e '\033[0;31m' #write in red
    if [ $(grep -c Debian /etc/os-release ) -gt 0 ]
    then
        osRelease=deb
    elif [ $(grep -c Ubuntu /etc/os-release ) -gt 0 ]
    then
        osRelease=ubu  
    elif [ $(grep -c Fedora /etc/os-release ) -gt 0 ]
    then
        osRelease=fed  
    elif [ $(grep -c CentOS /etc/os-release ) -gt 0 ]
    then
        osRelease=cen     
    elif [ $(grep -c Manjaro /etc/os-release ) -gt 0 ] || [ $(grep -c arch /etc/os-release ) -gt 0 ] || [ $(grep -c Arch /etc/os-release ) -gt 0 ]
    then
        osRelease=arc
    else
        echo "Unable to find out which Distro you use.
        Please enter one of the following numbers:
        1. Debian
        2. Fedora
        3. CentOS
        4. Arch Linux
        5. Ubuntu
        "
        read askDistro
        if [ $askDistro -eq 1 ]
        then
            osRelease=deb
        elif [ $askDistro -eq 2 ]
        then
            osRelease=fed  
        elif [ $askDistro -eq 3 ]
        then
            osRelease=cen     
        elif [ $askDistro -eq 4 ]
        then
            osRelease=arc
        elif [ $askDistro -eq 5 ]
        then
            osRelease=ubu
        else
            echo "Wrong Input, try again."
            checkOS
            return 13
        fi   
    fi
}


#This function installs Docker
function installNeededSoftware {
    if [ "$osRelease" = "deb" ]
    then
        apt update
        if ! [[ $secondInstallValue = true ]]
        then
            apt install -y rsync bc
        else
            # Add Docker's official GPG key:
            apt install -y ca-certificates curl gnupg
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            chmod a+r /etc/apt/keyrings/docker.gpg
            
            # Add the repository to Apt sources:
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
              $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
              tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt update
            apt install -y lsof docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        fi
    elif [ "$osRelease" = "ubu" ]
    then
        apt update
        if ! [[ $secondInstallValue = true ]]
        then
            apt install -y rsync bc
        else
            # Add Docker's official GPG key:
            apt install -y ca-certificates curl gnupg
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
            chmod a+r /etc/apt/keyrings/docker.asc
            
            # Add the repository to Apt sources:
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
              $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
              tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt-get update
            apt install -y lsof docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        fi        
    elif [ "$osRelease" = "fed" ]
    then
        if ! [[ $secondInstallValue = true ]]
        then
            yum install rsync bc
        else
            #remove old Docker Versions
            dnf -y remove docker \
                      docker-client \
                      docker-client-latest \
                      docker-common \
                      docker-latest \
                      docker-latest-logrotate \
                      docker-logrotate \
                      docker-selinux \
                      docker-engine-selinux \
                      docker-engine
            #add repo
            dnf -y install dnf-plugins-core
            dnf -y config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            #install docker and lsof
            dnf -y install lsof docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            #start and enable docker
            systemctl start docker
            systemctl enable docker
        fi
    elif [ "$osRelease" = "cen" ]
    then
        if ! [[ $secondInstallValue = true ]]
        then
            yum install rsync bc
        else
            #remove old Docker Versions
            yum -y remove docker \
                      docker-client \
                      docker-client-latest \
                      docker-common \
                      docker-latest \
                      docker-latest-logrotate \
                      docker-logrotate \
                      docker-engine
            #add repo
            yum -y install -y yum-utils
            yum-config-manager -y --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            #install docker and lsof
            yum -y install lsof docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            #start and enable docker
            systemctl start docker
            systemctl enable docker
        fi
    elif [ "$osRelease" = "arc" ]
    then
        if ! [[ $secondInstallValue = true ]]
        then
             pacman --noconfirm -S rsync bc
        else
            #Install Docker and lsof
            pacman --noconfirm -S docker lsof
            #Start and enable docker
            systemctl start docker
            systemctl enable docker
        fi
    fi
}


#build the container
function buildPackage {
    docker build -t $dockerContainerName .    
}


#This function starts the amount of wanted container
function startContainer {
    echo -e '\033[0;31m' #write in red
    #Ask for the amount
    echo "If you want to start the containers now, enter the amount, otherwise enter 0. (They will automaticaly restart after system reboot if you dont stop them with \"docker stop <Container-ID>\")"
    read askAmount
   
    #Start the correct amount
    if [[ "$askAmount" =~ ^[0-9]+$ ]] && ! [ "$askAmount" = 0 ]
    then
        #Ask if it is correct
        echo "We will start $askAmount Container
        Is that correct? Enter y/Y for Yes, anything else for No."
        read askAmountCorrect
        #If not correct, start again
        if ! [[ "$askAmountCorrect" =~ [yY]{1} ]] 
        then
            startContainer
            return 14         
        fi
        echo "We will start the Container now. This can take some time"
        c=0
        while [ $c -lt $askAmount ]
        do
            bash ./run.sh
            ((c++))
            sleep 2
        done
    elif [ "$askAmount" = 0 ]
    then
        echo "Okay, we will not start any Container now."
             
    else
        echo "Amount wasnt correct"
        startContainer
        return 15
    fi
    echo -e '\033[1;32m' #write in red
    echo "The installation is done. To start a new docker container, just run the \"run.sh\" and it will do everything for you
    If you want to stop a containter run \" docker ps\" to get the ID and run \"docker stop <Container-ID>\" to stop it.
    Every running Container will stay on as long as you dont stop them manually. Even after reboot!
    If you want to change the parameters for the echo server, you can change them in ./scripts/start-echo.sh
    You will need to restart the container!
    "
    echo -e '\033[0m' # No Color
}




#This function handles the CTRL-C INT
function ctrl_c {
    echo -e '\033[0m' # No Color
    echo "Script was interrupted by User"
    exit
}

#Hide the ^C
stty -echoctl
#Sigint Trap
trap ctrl_c SIGINT



#Start all functions
checkOS
downloadEcho
checkForEchoFolder
checkIfUserWantsUpdates
checkIfUserWantsConfigure
if [[ "$askconfigure" =~ [yY]{1} ]]
then
  getNeededParameterFromSTDin
  writeConfigFile
fi
getRegion
writeRegion
installNeededSoftware
buildPackage
startContainer
