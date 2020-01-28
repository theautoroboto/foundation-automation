#!/bin/bash

#set -xe
    #PRODUCT NAMES
    cloudcache_product_slug="p-cloudcache"
    azure_log_analytics_product_slug="azure-log-analytics-nozzle"
    azure_sb_product_slug="azure-service-broker"
    pks_product_slug="pivotal-container-service"
    spring_product_slug="p-spring-cloud-services"
    harbor_product_slug="harbor-container-registry"
    pas_product_slug="cf"
    pasw_product_slug="pas-windows"
    sso_product_slug="Pivotal_Single_Sign-On_Service"
    mysql_product_slug="pivotal-mysql"
    splunk_product_slug="splunk-nozzle"
    credhub_sb_product_slug="credhub-service-broker"
    concourse_product_slug="p-concourse"
    healthwatch_product_slug="p-healthwatch"
    rabbitmq_product_slug="p-rabbitmq"
    redis_product_slug="p-redis"
    metrics_product_slug="apm"

    #PRODUCT VERSIONS
    cloudcache_version_regex=^1\.9\..*$
    azure_log_analytics_version_regex=^1\.4\..*$
    harbor_version_regex=^1\.8\..*$
    credhub_sb_version_regex=^1\.4\..*$
    mysql_version_regex=^2\.7\..*$
    spring_version_regex=^3\.1\..*$
    redis_version_regex=^2\.2\..*$
    pks_version_regex=^1\.6\..*$
    pas_version_regex=^2\.6\..*$
    pasw_version_regex=^2\.6\..*$
    sso_version_regex=^1\.10\..*$
    splunk_version_regex=^1\.1\..*$
    metrics_version_regex=^1\.6\..*$
    rabbitmq_version_regex=^1\.17\..*$
    azure_sb_version_regex=^1\.11\..*$
    concourse_version_regex=^5\..\..*$
    concourse_stemcell_regex=^315\..*$
    healthwatch_version_regex=^1\.7\..*$


    #COMMON
    pivnet_token="RyYyf5v1LUyuvKZHqxNQ"
    export OM_TARGET=$opsman_url
    export OM_CLIENT_ID=((secrets.opsman.client_id))
    export OM_CLIENT_SECRET="${password}"
    export AZURE_STORAGE_ACCOUNT="azfog720a"
    #az account set -s 986405ef-f6c9-4993-8b3f-4a8fdf4d72d6

    download_product(){
        # download_product product product_slug version_regex
        product=$1
        product_slug=$2
        version_regex=$3
        echo "Downloading ${product} from Pivnet"
        om -k download-product --output-directory . --pivnet-api-token $pivnet_token --pivnet-file-glob "*.pivotal" --pivnet-product-slug $product_slug --product-version-regex $version_regex --stemcell-iaas azure
        echo "Uploading ${product} to OpsMan"
        om -k upload-product -p "$product_slug"*.pivotal
        echo "Uploading ${product} Stemcell to OpsMan"
        om -k upload-stemcell -s *.tgz
        echo "Staging ${product}"
        om -k stage-product --product-name "$product_slug"  --product-version $(om tile-metadata --product-path "$product_slug"*.pivotal --product-version true)
        echo "Deleting ${product} files"
        rm "$product_slug"*.pivotal
        rm *.tgz
    }

    install_pasw(){
        ##############################
        # Download/Upload/Stage PAS
        ##############################
        mkdir downloads
        echo "Downloading PASW from Pivnet"
        om -k download-product --output-directory ./downloads --pivnet-api-token $pivnet_token --pivnet-file-glob "*.pivotal" --pivnet-product-slug $pasw_product_slug --product-version-regex $pasw_version_regex --stemcell-iaas azure
        om -k download-product --output-directory ./downloads --pivnet-api-token $pivnet_token --pivnet-file-glob "winfs-*.zip" --pivnet-product-slug $pasw_product_slug --product-version-regex $pasw_version_regex
        
        unzip -o ./downloads//winfs-*.zip -d ./downloads/
        chmod +x ./downloads/winfs-injector-linux
        echo "Injecting Tile"
        ./downloads/winfs-injector-linux --input-tile ./downloads/*.pivotal --output-tile ./downloads/pasw-injected.pivotal
        
        echo "Uploading PASW to OpsMan"
        om -k upload-product -p ./downloads/pasw-injected.pivotal
        echo "Uploading PASW Stemcell to OpsMan"
        om -k upload-stemcell -s ./downloads/*.tgz
        echo "Staging PASW"
        om -k stage-product --product-name "$pasw_product_slug" --product-version $(om tile-metadata --product-path ./downloads/pasw-injected.pivotal --product-version true)
        echo "Deleting PASW files"
        rm -rf ./downloads
    }

    install_pas(){
        ##############################
        # Download/Upload/Stage PAS
        ##############################
        echo "Downloading PAS from Pivnet"
        om -k download-product --output-directory . --pivnet-api-token $pivnet_token --pivnet-file-glob "cf*.pivotal" --pivnet-product-slug $pas_product_slug --product-version-regex $pas_version_regex --stemcell-iaas azure
        echo "Uploading PAS to OpsMan"
        om -k upload-product -p "$pas_product_slug"-*.pivotal
        echo "Uploading PAS Stemcell to OpsMan"
        om -k upload-stemcell -s *.tgz
        echo "Staging PAS"
        om -k stage-product --product-name cf --product-version $(om tile-metadata --product-path "$pas_product_slug"-*.pivotal --product-version true)
        echo "Deleting PAS files"
        rm "$pas_product_slug"-*.pivotal
        rm *.tgz
    }

check_product(){
    pivnet login --api-token RyYyf5v1LUyuvKZHqxNQ
    om -k staged-products -f json > out.json

    for name in $(jq -e --raw-output '.[] | .name' < out.json)
    do
        version=$(jq -r --arg name "$name" '.[] | select(.name == $name) | .version' < out.json)
        echo $name
        echo "installed version::"$version
        pivnet_ver=$(pivnet releases -p $name --format json | jq  -e --arg version "$" '.[].version')
        echo "pivnet version::"$pivnet_ver
    done
}

check_specific_product(){
    name=$1
    pivnet login --api-token RyYyf5v1LUyuvKZHqxNQ
    current_ver=$(om -k staged-products -f json | jq -r --arg name "$name" '.[] | select(.name == $name) | .version')

#There must be a better way
    if [[ $current_ver == *"build"* ]] ; then
        current_ver=$(echo $current_ver | cut -d '-' -f 1)
    fi

    minor=$(echo $current_ver | cut -d '.' -f 1-2)
    echo "Current Version is " $current_ver
    echo "Looking for minor version " $minor
    if [[ $name == "apmPostgres" ]] ; then
        name="apm"
    fi
    pivnet_ver=$(pivnet releases -p $name --format json | jq --arg minor $minor '.[] | select(.version|test($minor)).version' | head -n 1 | cut -d '"' -f 2)
    echo "Latest Pivnet Version is " $pivnet_ver

#There must be a better way
    if [[ $current_ver == *"build"* ]] ; then
        if [ $(echo $pivnet_ver | cut -d '.' -f 3) -gt $(echo $current_ver | cut -d '-' -f 1 | cut -d '.' -f 3) ] ; then
            true
        fi
    else
        if [ $(echo $pivnet_ver | cut -d '.' -f 3) -gt $(echo $current_ver | cut -d '.' -f 3) ] ; then
            true
        else
            false
        fi
    fi
}

case $PRODUCT in
    rabbitmq)
        if check_specific_product $rabbitmq_product_slug; then
            echo "y'all best upgrade"
            download_product rabbitmq $rabbitmq_product_slug $rabbitmq_version_regex
        else
            echo "its all good man, no upgraded needed"
        fi
        ;;
    azure_log_analytics)
        if check_specific_product $azure_log_analytics_product_slug; then
            echo "y'all best upgrade"
            download_product azure_log_analytics $azure_log_analytics_product_slug $azure_log_analytics_version_regex
        else
            echo "its all good man, no upgraded needed"
        fi
        ;;
        
    healthwatch)
        if check_specific_product $healthwatch_product_slug; then
            echo "y'all best upgrade"
            download_product healthwatch $healthwatch_product_slug $healthwatch_version_regex
        else
            echo "its all good man, no upgraded needed"
        fi
        ;;
    harbor)
        if check_specific_product $harbor_product_slug; then
            echo "y'all best upgrade"
            download_product harbor $harbor_product_slug $harbor_version_regex
        else
            echo "its all good man, no upgraded needed"
        fi
        ;;
    spring)
        if check_specific_product "p_spring-cloud-services"; then
            echo "y'all best upgrade"
            download_product spring $spring_product_slug $spring_version_regex
        else
            echo "its all good man, no upgraded needed"
        fi
        ;;
    metrics)
        if check_specific_product "apmPostgres"; then
            echo "y'all best upgrade"
            download_product metrics $metrics_product_slug $metrics_version_regex
        else
            echo "its all good man, no upgraded needed"
        fi
        ;;
    splunk)
        if check_specific_product $splunk_product_slug; then
            echo "y'all best upgrade"
            download_product splunk $splunk_product_slug $splunk_version_regex
        else
            echo "its all good man, no upgraded needed"
        fi
        ;;
    sso)
        if check_specific_product $sso_product_slug; then
            echo "y'all best upgrade"
            download_product sso $sso_product_slug $sso_version_regex
        else
            echo "its all good man, no upgraded needed"
        fi
        ;;
    azure_sb)
        if check_specific_product $azure_sb_product_slug; then
            echo "y'all best upgrade"
            download_product azure_sb $azure_sb_product_slug $azure_sb_version_regex
        else
            echo "its all good man, no upgraded needed"
        fi
        ;;
    mysql)
        if check_specific_product $mysql_product_slug; then
            echo "y'all best upgrade"
            download_product mysql $mysql_product_slug $mysql_version_regex
        else
            echo "its all good man, no upgraded needed"
        fi
        ;;
    credhub_sb)
        if check_specific_product $credhub_sb_product_slug; then
            echo "y'all best upgrade"
            download_product credhub_sb $credhub_sb_product_slug $splunk_version_regex
        else
            echo "its all good man, no upgraded needed"
        fi
        ;;
    redis)
        if check_specific_product $redis_product_slug; then
            echo "y'all best upgrade"
            download_product redis $redis_product_slug $redis_version_regex
        else
            echo "its all good man, no upgraded needed"
        fi
        ;;
    cloudcache)
        if check_specific_product $cloudcache_product_slug; then
            echo "y'all best upgrade"
            download_product cloudcache $cloudcache_product_slug $cloudcache_version_regex
        else
            echo "its all good man, no upgraded needed"
        fi
        ;;
    pks)
        if check_specific_product $pks_product_slug; then
            echo "y'all best upgrade"
            download_product pks $pks_product_slug $pks_version_regex
        else
            echo "its all good man, no upgraded needed"
        fi
        ;;
    pas)
        if check_specific_product $pas_product_slug; then
            echo "y'all best upgrade"
            install_pas
        else
            echo "its all good man, no upgraded needed"
        fi
        ;;
    pasw)
        if check_specific_product $pasw_product_slug; then
            echo "y'all best upgrade"
            install_pasw
        else
            echo "its all good man, no upgraded needed"
        fi
        ;;
esac