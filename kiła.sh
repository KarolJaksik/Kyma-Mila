export DOCKER_ACCOUNT
export PROJECT_NAME=kyma-installer
export KYMAPATH=${GOPATH}src/github.com/kyma-project/kyma

### Installation variables
export CLUSTER_NAME=flying-seals-showcase
export GCP_PROJECT=sap-hybris-sf-playground
export GCP_ZONE=europe-west1-c

export PROVICER=gcp
export VERSION=1.4.1

get_version=0
get_arg=0
task_scheduled=0
declare -a main_tasks
main_tasks[0]="nothing"
main_tasks[1]="comasz"

function build_image(){
    # Docker login
    echo Please enter your docker username:
    read -r DOCKER_ACCOUNT

    echo Docker pass for $DOCKER_ACCOUNT:
    docker login -u $DOCKER_ACCOUNT

    # Create and push kyma's docker image
    docker build -t $PROJECT_NAME -f $KYMAPATH/tools/kyma-installer/kyma.Dockerfile $KYMAPATH
    docker tag $PROJECT_NAME $DOCKER_ACCOUNT/$PROJECT_NAME
    docker push $DOCKER_ACCOUNT/$PROJECT_NAME
}

function tiller_certs(){
    echo Tiller certs...
    sh -c "$(curl -s https://raw.githubusercontent.com/kyma-project/kyma/master/installation/scripts/tiller-tls.sh)"
}

function console_certs(){
    echo Consol certs...
    tmpfile=$(mktemp /tmp/temp-cert.XXXXXX) \
    && kubectl get configmap net-global-overrides -n kyma-installer -o jsonpath='{.data.global\.ingress\.tlsCrt}' | base64 --decode > $tmpfile \
    && sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $tmpfile \
    && rm $tmpfile
}

function kymaState(){
    echo `kubectl -n default get installation/kyma-installation -o jsonpath={.status.state}`
}

function kymaInstallationState(){
    echo `kubectl -n default get installation/kyma-installation -o jsonpath="Status: {.status.state}, Description: {.status.description}"`
}

function monitor_installation(){
    echo "Waiting for Kyma..."

    COMPONENT=""
    while [ "$(kymaState)" != "Installed" ] ;
    do
        NEWCOMPONENT=$(kymaInstallationState)
        if [ "${NEWCOMPONENT}" != "${COMPONENT}" ]
        then
            echo  `date +"%T"` ${NEWCOMPONENT};
            sleep 2;
            COMPONENT=${NEWCOMPONENT}
        fi
    done
}

function get_ip(){
    URL=$(kubectl get virtualservice core-console -n kyma-system -o jsonpath='{ .spec.hosts[0] }')

    echo ${URL}
}

function get_console_ip(){
    URL=$(kubectl get virtualservice core-console -n kyma-system -o jsonpath='{ .spec.hosts[0] }')

    echo ${URL}

    open "https://${URL}"
}

function get_pass(){
    PASS=$(kubectl get secret admin-user -n kyma-system -o jsonpath="{.data.password}" | base64 --decode)
    echo ${PASS}
    echo ${PASS} | pbcopy
}

function create_cluster(){
    # Create a cluster
    gcloud container --project "$GCP_PROJECT" clusters \
    create "$CLUSTER_NAME" --zone "$GCP_ZONE" \
    --cluster-version "1.12" --machine-type "n1-standard-4" \
    --addons HorizontalPodAutoscaling,HttpLoadBalancing

    # Configure kubectl to use your new cluster
    gcloud container clusters get-credentials $CLUSTER_NAME --zone $GCP_ZONE --project $GCP_PROJECT

    # Add your account as the cluster administrator
    kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value account)
}

function prepare_cluster(){
    # Install kyma with tiller
    echo "Installing Kyma with Tiller from $VERSION Kyma release\n"
    if [ $VERSION == master ]
    then
        kubectl apply -f $KYMAPATH/installation/resources/tiller.yaml

        # Create kyma's yaml deployment
        (cat $KYMAPATH/installation/resources/installer.yaml ; echo "---" ; cat $KYMAPATH/installation/resources/installer-cr-cluster.yaml.tpl) > $KYMAPATH/my-kyma.yaml
        sed -i.bak "s~eu.gcr.io/kyma-project/develop/installer:[a-zA-Z0-9]*[a-zA-Z0-9]~$DOCKER_ACCOUNT/$PROJECT_NAME~g" $KYMAPATH/my-kyma.yaml
        sed -i.bak "s~IfNotPresent~Always~g" $KYMAPATH/my-kyma.yaml
        rm -rf $KYMAPATH/my-kyma.yaml.bak

        kubectl apply -f $KYMAPATH/my-kyma.yaml
    else
        kubectl apply -f https://raw.githubusercontent.com/kyma-project/kyma/$VERSION/installation/resources/tiller.yaml

        kubectl apply -f https://github.com/kyma-project/kyma/releases/download/$VERSION/kyma-installer-cluster.yaml
    fi
}
#$(seq "$#" $END)
for option in $@;
do
    #main options resolver
    if [ $get_version == 1 ];
    then
        VERSION=$option
        get_version=0
    elif [  "${main_tasks[0]}" != "nothing" ] && [ $get_arg == 1 ];
    then
        main_tasks[1]=$option
        get_arg=0
        task_scheduled=1
    elif [ "$option" == "dej" ];
    then 
        if [ "${main_tasks[0]}" != "nothing" ] && [ $task_scheduled == 1 ]; then echo Please use only one [OPTION] key word - problem with $option; exit; fi
        get_arg=1
        main_tasks[0]=$option 
    elif [ "$option" == "rusz" ];
    then
        if [ "${main_tasks[0]}" != "nothing" ] && [ $task_scheduled == 1 ]; then echo Please use only one [OPTION] key word - problem with $option; exit; fi
        get_arg=1
        main_tasks[0]=$option
    
    #switches
    elif [ "$option" == "-nm" ] || [ "$option" == "--na-minikube" ];
    then
        if [ "${PROVICER}" != "" ]; then echo You can use $option key word only once; exit; fi
        PROVICER=minikube
    elif [ "$option" == "-v" ] || [ "$option" == "--version" ];
    then
        get_version=1
    else
        echo $option is not a good key word
        exit
    fi
done

if [ ${main_tasks[0]} == "rusz" ]; 
then
    CLUSTER_NAME=${main_tasks[1]}
    if [ $VERSION == master ];
    then
        build_image
    fi
    if [ $PROVICER == gcp ];
    then
        create_cluster
        prepare_cluster
        monitor_installation
        console_certs
        tiller_certs
    else
        echo Please install kyma on gcp :c
    fi
fi

# Deploy kyma
if [ ${main_tasks[0]} == "dej" ]; 
then
    if [ ${main_tasks[1]} == "comasz" ]; 
    then
        console_certs
        tiller_certs
        get_console_ip
        get_pass
    elif [ ${main_tasks[1]} == "strone" ];
    then
        get_console_ip
    elif [ ${main_tasks[1]} == "certy" ]
    then
        console_certs
        tiller_certs
    elif [ ${main_tasks[1]} == "pasy" ];
    then
        get_pass
    elif [ ${main_tasks[1]} == "ip" ];
    then
        get_ip
    else
        echo ${main_tasks[1]} is not a right key word
        exit
    fi
fi

if [ ${main_tasks[0]} == "nothing" ]; 
then 
    echo ===================================================================================================================
    echo Welcome to Kyma-Mila tool v 1.0.1
    echo This tool can help you with deploying kyma on gcp cluster, getting certs, ip or console password
    echo Command structure: kiła [OPTION] [ARGUMENT] [SWITCH]
    echo 
    echo Creating cluster:
    echo kiła rusz CLUSTER_NAME - will deploy kyma on gcp cluster, get certs and open kyma\'s console in web browser window
    echo -v or --version - allow you to set kyma\'s version. You can use typical version like 1.4.1 or set version to master
    echo For example kiła rusz my-cluster -v 1.4.1
    echo -nm or --na-minikube - will deploy kyma on minikube. NOT SUPPORTED YET!
    echo ===================================================================================================================
    echo Getting informationes:
    echo kiła dej or kiła dej comasz- will print kyma\'s ip, password, open console in web browser window, install certs and copy password to cache
    echo kiła dej strone - will print kyma\'s ip and open it in web browser window
    echo kiła dej pasy - will print kyma\'s password
    echo kiła dej ip - will print kyma\'s ip
    echo kiła dej certy - will apply all kyma\'s certs
    echo ===================================================================================================================
fi