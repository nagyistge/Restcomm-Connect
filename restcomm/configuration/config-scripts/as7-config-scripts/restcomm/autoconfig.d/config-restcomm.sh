#!/bin/bash
##
## Description: Configures RestComm
## Author: Henrique Rosa (henrique.rosa@telestax.com)
## Author: Pavel Slegr (pavel.slegr@telestax.com)
##

# VARIABLES
RESTCOMM_BIN=$RESTCOMM_HOME/bin
RESTCOMM_DARS=$RESTCOMM_HOME/standalone/configuration/dars
RESTCOMM_CONF=$RESTCOMM_HOME/standalone/configuration
RESTCOMM_DEPLOY=$RESTCOMM_HOME/standalone/deployments/restcomm.war

## FUNCTIONS

## Description: Configures Java Options for Application Server
## Parameters : none
configJavaOpts() {
	FILE=$RESTCOMM_BIN/standalone.conf

	# Find total available memory on the instance
    TOTAL_MEM=$(free -m -t | grep 'Total:' | awk '{print $2}')
    # get 70 percent of available memory
    # need to use division by 1 for scale to be read
    CHUNK_MEM=$(echo "scale=0; ($TOTAL_MEM * 0.7)/1" | bc -l)
    # divide chunk memory into units of 64mb
    MULTIPLIER=$(echo "scale=0; $CHUNK_MEM/64" | bc -l)
    # use multiples of 64mb to know effective memory
    FINAL_MEM=$(echo "$MULTIPLIER * 64" | bc -l)
    MEM_UNIT='m'

    RESTCOMM_OPTS="-Xms$FINAL_MEM$MEM_UNIT -Xmx$FINAL_MEM$MEM_UNIT -XX:MaxPermSize=256m -Dorg.jboss.resolver.warning=true -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000"

	sed -e "/if \[ \"x\$JAVA_OPTS\" = \"x\" \]; then/ {
		N; s|JAVA_OPTS=.*|JAVA_OPTS=\"$RESTCOMM_OPTS\"|
	}" $FILE > $FILE.bak
	mv $FILE.bak $FILE
	echo "Configured JVM for RestComm: $RESTCOMM_OPTS"
}

## Description: Updates RestComm configuration file
## Parameters : 1.STATIC_ADDRESS
configRestcomm() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml
	static_address="$1"

	sed -e  "s|<\!--.*<external-ip>.*<\/external-ip>.*-->|<external-ip>$static_address<\/external-ip>|" \
		-e "s|<external-ip>.*<\/external-ip>|<external-ip>$static_address<\/external-ip>|" \
		 $FILE > $FILE.bak;

	mv $FILE.bak $FILE
	echo 'Updated RestComm configuration'

	if [ "$SSL_MODE" == "strict" ] || [ "$SSL_MODE" == "STRICT" ]; then
		sed -e "s/<ssl-mode>.*<\/ssl-mode>/<ssl-mode>strict<\/ssl-mode>/" $FILE > $FILE.bak
		mv $FILE.bak $FILE
	else
		sed -e "s/<ssl-mode>.*<\/ssl-mode>/<ssl-mode>allowall<\/ssl-mode>/" $FILE > $FILE.bak
		mv $FILE.bak $FILE
	fi
}

configOutboundProxy(){
    FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml
    sed -e "s|<outbound-proxy-uri>.*<\/outbound-proxy-uri>|<outbound-proxy-uri>$OUTBOUND_PROXY<\/outbound-proxy-uri>|" \
	-e "s|<outbound-proxy-user>.*<\/outbound-proxy-user>|<outbound-proxy-user>$OUTBOUND_PROXY_USERNAME<\/outbound-proxy-user>|"  \
	-e "s|<outbound-proxy-password>.*<\/outbound-proxy-password>|<outbound-proxy-password>$OUTBOUND_PROXY_PASSWORD<\/outbound-proxy-password>|" $FILE > $FILE.bak;
	mv $FILE.bak $FILE
}

## Description: Configures Voip Innovations Credentials
## Parameters : 1.Login
## 				2.Password
## 				3.Endpoint
configVoipInnovations() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml

	sed -e "/<voip-innovations>/ {
		N; s|<login>.*</login>|<login>$1</login>|
        N; s|<password>.*</password>|<password>$2</password>|
        N; s|<endpoint>.*</endpoint>|<endpoint>$3</endpoint>|
	}" $FILE > $FILE.bak

	mv $FILE.bak $FILE
	echo 'Configured Voip Innovation credentials'
}

configDidProvisionManager() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml

	if (( $PORT_OFFSET > 0 )); then
		local SIP_PORT_UDP=$((SIP_PORT_UDP + PORT_OFFSET))
	fi

		if [[ "$PROVISION_PROVIDER" == "VI" || "$PROVISION_PROVIDER" == "vi" ]]; then
		sed -e "s|phone-number-provisioning class=\".*\"|phone-number-provisioning class=\"org.mobicents.servlet.restcomm.provisioning.number.vi.VoIPInnovationsNumberProvisioningManager\"|" $FILE > $FILE.bak

		sed -e "/<voip-innovations>/ {
			N; s|<login>.*</login>|<login>$1</login>|
			N; s|<password>.*</password>|<password>$2</password>|
			N; s|<endpoint>.*</endpoint>|<endpoint>$3</endpoint>|
		}" $FILE.bak > $FILE
		sed -i "s|<outboudproxy-user-at-from-header>.*<\/outboudproxy-user-at-from-header>|<outboudproxy-user-at-from-header>"false"<\/outboudproxy-user-at-from-header>|" $FILE
		echo 'Configured Voip Innovation credentials'
		else
			if [[ "$PROVISION_PROVIDER" == "BW" || "$PROVISION_PROVIDER" == "bw" ]]; then
			sed -e "s|phone-number-provisioning class=\".*\"|phone-number-provisioning class=\"org.mobicents.servlet.restcomm.provisioning.number.bandwidth.BandwidthNumberProvisioningManager\"|" $FILE > $FILE.bak

			sed -e "/<bandwidth>/ {
				N; s|<username>.*</username>|<username>$1</username>|
				N; s|<password>.*</password>|<password>$2</password>|
				N; s|<accountId>.*</accountId>|<accountId>$6</accountId>|
				N; s|<siteId>.*</siteId>|<siteId>$4</siteId>|
			}" $FILE.bak > $FILE
			sed -i "s|<outboudproxy-user-at-from-header>.*<\/outboudproxy-user-at-from-header>|<outboudproxy-user-at-from-header>"false"<\/outboudproxy-user-at-from-header>|" $FILE
			echo 'Configured Bandwidth credentials'
		else
			if [[ "$PROVISION_PROVIDER" == "NX" || "$PROVISION_PROVIDER" == "nx" ]]; then
				echo "Nexmo PROVISION_PROVIDER"
				sed -i "s|phone-number-provisioning class=\".*\"|phone-number-provisioning class=\"org.mobicents.servlet.restcomm.provisioning.number.nexmo.NexmoPhoneNumberProvisioningManager\"|" $FILE

				sed -i "/<callback-urls>/ {
					N; s|<voice url=\".*\" method=\".*\" />|<voice url=\"$5:$SIP_PORT_UDP\" method=\"SIP\" />|
					N; s|<sms url=\".*\" method=\".*\" />|<sms url=\"\" method=\"\" />|
					N; s|<fax url=\".*\" method=\".*\" />|<fax url=\"\" method=\"\" />|
					N; s|<ussd url=\".*\" method=\".*\" />|<ussd url=\"\" method=\"\" />|
				}" $FILE

				sed -i "/<nexmo>/ {
					N; s|<api-key>.*</api-key>|<api-key>$1</api-key>|
					N; s|<api-secret>.*</api-secret>|<api-secret>$2</api-secret>|
					N
					N; s|<smpp-system-type>.*</smpp-system-type>|<smpp-system-type>$7</smpp-system-type>|
				}" $FILE

				sed -i "s|<outboudproxy-user-at-from-header>.*<\/outboudproxy-user-at-from-header>|<outboudproxy-user-at-from-header>"true"<\/outboudproxy-user-at-from-header>|" $FILE

		else
			if [[ "$PROVISION_PROVIDER" == "VB" || "$PROVISION_PROVIDER" == "vb" ]]; then
				echo "Voxbone PROVISION_PROVIDER"
				sed -i "s|phone-number-provisioning class=\".*\"|phone-number-provisioning class=\"org.mobicents.servlet.restcomm.provisioning.number.voxbone.VoxbonePhoneNumberProvisioningManager\"|" $FILE

				sed -i "/<callback-urls>/ {
					N; s|<voice url=\".*\" method=\".*\" />|<voice url=\"\+\{E164\}\@$5:$SIP_PORT_UDP\" method=\"SIP\" />|
					N; s|<sms url=\".*\" method=\".*\" />|<sms url=\"\+\{E164\}\@$5:$SIP_PORT_UDP\" method=\"SIP\" />|
					N; s|<fax url=\".*\" method=\".*\" />|<fax url=\"\+\{E164\}\@$5:$SIP_PORT_UDP\" method=\"SIP\" />|
					N; s|<ussd url=\".*\" method=\".*\" />|<ussd url=\"\+\{E164\}\@$5:$SIP_PORT_UDP\" method=\"SIP\" />|
				}" $FILE

				sed -i "/<voxbone>/ {
					N; s|<username>.*</username>|<username>$1</username>|
					N; s|<password>.*</password>|<password>$2</password>|
				}" $FILE
				sed -i "s|<outboudproxy-user-at-from-header>.*<\/outboudproxy-user-at-from-header>|<outboudproxy-user-at-from-header>"false"<\/outboudproxy-user-at-from-header>|" $FILE

		fi
		fi
		fi
		fi
}

## Description: Configures Fax Service Credentials
## Parameters : 1.Username
## 				2.Password
configFaxService() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml

	sed -e "/<fax-service.*>/ {
		N; s|<user>.*</user>|<user>$1</user>|
		N; s|<password>.*</password>|<password>$2</password>|
	}" $FILE > $FILE.bak

	mv $FILE.bak $FILE
	echo 'Configured Fax Service credentials'
}

## Description: Configures Sms Aggregator
## Parameters : 1.Outbound endpoint IP
##
configSmsAggregator() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml

	sed -e "/<sms-aggregator.*>/ {
		N; s|<outbound-prefix>.*</outbound-prefix>|<outbound-prefix>$2</outbound-prefix>|
		N; s|<outbound-endpoint>.*</outbound-endpoint>|<outbound-endpoint>$1</outbound-endpoint>|
	}" $FILE > $FILE.bak

	mv $FILE.bak $FILE
	echo "Configured Sms Aggregator using OUTBOUND PROXY $1"
}

## Description: Configures Speech Recognizer
## Parameters : 1.iSpeech Key
configSpeechRecognizer() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml

	sed -e "/<speech-recognizer.*>/ {
		N; s|<api-key.*></api-key>|<api-key production=\"true\">$1</api-key>|
	}" $FILE > $FILE.bak

	mv $FILE.bak $FILE
	echo 'Configured the Speech Recognizer'
}

## Description: Configures available speech synthesizers
## Parameters : none
configSpeechSynthesizers() {
	configAcapela $ACAPELA_APPLICATION $ACAPELA_LOGIN $ACAPELA_PASSWORD
	configVoiceRSS $VOICERSS_KEY
}

## Description: Configures Acapela Speech Synthesizer
## Parameters : 1.Application Code
## 				2.Login
## 				3.Password
configAcapela() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml

	sed -e "/<speech-synthesizer class=\"org.mobicents.servlet.restcomm.tts.AcapelaSpeechSynthesizer\">/ {
		N
		N; s|<application>.*</application>|<application>$1</application>|
		N; s|<login>.*</login>|<login>$2</login>|
		N; s|<password>.*</password>|<password>$3</password>|
	}" $FILE > $FILE.bak

	mv $FILE.bak $FILE
	echo 'Configured Acapela Speech Synthesizer'
}

## Description: Configures VoiceRSS Speech Synthesizer
## Parameters : 1.API key
configVoiceRSS() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml

	sed -e "/<service-root>http:\/\/api.voicerss.org<\/service-root>/ {
		N; s|<apikey>.*</apikey>|<apikey>$1</apikey>|
	}" $FILE > $FILE.bak

	mv $FILE.bak $FILE
	echo 'Configured VoiceRSS Speech Synthesizer'
}

## Description: Updates Mobicents properties for RestComm
## Parameters : none
configMobicentsProperties() {
	FILE=$RESTCOMM_DARS/mobicents-dar.properties
	sed -e 's|^ALL=.*|ALL=("RestComm", "DAR\:From", "NEUTRAL", "", "NO_ROUTE", "0")|' $FILE > $FILE.bak
	mv $FILE.bak $FILE
	echo "Updated mobicents-dar properties"
}



## Description: Configures SMPP Account Details
## Parameters : 1.activate
## 		2.systemID
## 		3.password
## 		4.systemType
## 		5.peerIP
## 		6.peerPort
configSMPPAccount() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml
	activate="$1"
	systemID="$2"
	password="$3"
	systemType="$4"
	peerIP="$5"
	peerPort="$6"

	sed -i "s|<smpp class=\"org.mobicents.servlet.restcomm.smpp.SmppService\" activateSmppConnection =\".*\">|<smpp class=\"org.mobicents.servlet.restcomm.smpp.SmppService\" activateSmppConnection =\"$activate\">|g" $FILE

	if [ "$activate" == "true" ] || [ "$activate" == "TRUE" ]; then
		sed -e	"/<smpp class=\"org.mobicents.servlet.restcomm.smpp.SmppService\"/{
			N
			N
			N
			N
			N; s|<systemid>.*</systemid>|<systemid>$systemID</systemid>|
			N; s|<peerip>.*</peerip>|<peerip>$peerIP</peerip>|
			N; s|<peerport>.*</peerport>|<peerport>$peerPort</peerport>|
			N
			N
			N; s|<password>.*</password>|<password>$password</password>|
			N; s|<systemtype>.*</systemtype>|<systemtype>$systemType</systemtype>|
		}" $FILE > $FILE.bak

		mv $FILE.bak $FILE
		echo 'Configured SMPP Account Details'

	else
		sed -e	"/<smpp class=\"org.mobicents.servlet.restcomm.smpp.SmppService\"/{
			N
			N
			N
			N
			N; s|<systemid>.*</systemid>|<systemid></systemid>|
			N; s|<peerip>.*</peerip>|<peerip></peerip>|
			N; s|<peerport>.*</peerport>|<peerport></peerport>|
			N
			N
			N; s|<password>.*</password>|<password></password>|
			N; s|<systemtype>.*</systemtype>|<systemtype></systemtype>|
		}" $FILE > $FILE.bak

		mv $FILE.bak $FILE
		echo 'Configured SMPP Account Details'
	fi
}

configRestCommURIs() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml

	if (( $PORT_OFFSET > 0 )); then
		local HTTP_PORT=$((HTTP_PORT + PORT_OFFSET))
		local HTTPS_PORT=$((HTTPS_PORT + PORT_OFFSET))
	fi

	if [ -n "$MS_ADDRESS" ] && [ "$MS_ADDRESS" != "$BIND_ADDRESS" ]; then
		if [ "$DISABLE_HTTP" = "true" ]; then
            REMOTEADD="$STATIC_ADDRESS"
            PORT="$HTTPS_PORT"
			sed -e "s|<prompts-uri>.*</prompts-uri>|<prompts-uri>https://$REMOTEADD:$PORT/restcomm/audio<\/prompts-uri>|" \
		    -e "s|<cache-uri>.*</cache-uri>|<cache-uri>https://$REMOTEADD/restcomm/cache</cache-uri>|" \
			-e "s|<error-dictionary-uri>.*</error-dictionary-uri>|<error-dictionary-uri>https://$REMOTEADD/restcomm/errors</error-dictionary-uri>|" $FILE > $FILE.bak

		else
			PORT="$HTTP_PORT"
			sed -e "s|<prompts-uri>.*</prompts-uri>|<prompts-uri>http://$BIND_ADDRESS:$PORT/restcomm/audio<\/prompts-uri>|" \
		    -e "s|<cache-uri>.*/cache-uri>|<cache-uri>http://$BIND_ADDRESS/restcomm/cache</cache-uri>|" \
			-e "s|<error-dictionary-uri>.*</error-dictionary-uri>|<error-dictionary-uri>http://$BIND_ADDRESS/restcomm/errors</error-dictionary-uri>|" $FILE > $FILE.bak
		fi
		mv $FILE.bak $FILE
		echo "Updated prompts-uri cache-uri error-dictionary-uri External MSaddress for "
	fi
}

updateRecordingsPath() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml

	if [ -n "$RECORDINGS_PATH" ]; then
		sed -e "s|<recordings-path>.*</recordings-path>|<recordings-path>file://${RECORDINGS_PATH}<\/recordings-path>|" $FILE > $FILE.bak
		echo "Updated RECORDINGS_PATH "
		mv $FILE.bak $FILE
	fi
}

configHypertextPort(){
    MSSFILE=$RESTCOMM_CONF/mss-sip-stack.properties

    #Check for Por Offset
	if (( $PORT_OFFSET > 0 )); then
		local HTTP_PORT=$((HTTP_PORT + PORT_OFFSET))
		local HTTPS_PORT=$((HTTPS_PORT + PORT_OFFSET))
	fi

    sed -e "s|org.mobicents.ha.javax.sip.LOCAL_HTTP_PORT=.*|org.mobicents.ha.javax.sip.LOCAL_HTTP_PORT=$HTTP_PORT|
    N; 		s|org.mobicents.ha.javax.sip.LOCAL_SSL_PORT=.*|org.mobicents.ha.javax.sip.LOCAL_SSL_PORT=$HTTPS_PORT|" $MSSFILE > $MSSFILE.bak
    mv $MSSFILE.bak $MSSFILE
}

otherRestCommConf(){
    FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml
    sed -e "s|<play-music-for-conference>.*</play-music-for-conference>|<play-music-for-conference>${PLAY_WAIT_MUSIC}<\/play-music-for-conference>|" $FILE > $FILE.bak
	mv $FILE.bak $FILE
}

# MAIN
echo 'Configuring RestComm...'
#configJavaOpts
configMobicentsProperties
configRestcomm "$STATIC_ADDRESS"
#configVoipInnovations "$VI_LOGIN" "$VI_PASSWORD" "$VI_ENDPOINT"
configDidProvisionManager "$DID_LOGIN" "$DID_PASSWORD" "$DID_ENDPOINT" "$DID_SITEID" "$PUBLIC_IP" "$DID_ACCOUNTID" "$SMPP_SYSTEM_TYPE"
configFaxService "$INTERFAX_USER" "$INTERFAX_PASSWORD"
configSmsAggregator "$SMS_OUTBOUND_PROXY" "$SMS_PREFIX"
configSpeechRecognizer "$ISPEECH_KEY"
configSpeechSynthesizers
configSMPPAccount "$SMPP_ACTIVATE" "$SMPP_SYSTEM_ID" "$SMPP_PASSWORD" "$SMPP_SYSTEM_TYPE" "$SMPP_PEER_IP" "$SMPP_PEER_PORT"
configRestCommURIs
updateRecordingsPath
configHypertextPort
configOutboundProxy
otherRestCommConf
echo 'Configured RestComm!'
