FROM alpine

RUN apk update
RUN apk add openvpn curl unzip openssl openresolv bash

RUN wget https://www.privateinternetaccess.com/openvpn/openvpn.zip
RUN mkdir /PIA_CONFIG
ADD openvpn.zip /openvpn.zip
RUN unzip openvpn.zip -d /PIA_CONFIG
RUN rm openvpn.zip

RUN sed -i '/^auth-user-pass/ s/$/ \/PIA_CONFIG\/.pia.cfg/' /PIA_CONFIG/CA\ Toronto.ovpn
RUN sed -i '/^crl-verify/ s/ / \/PIA_CONFIG\//' /PIA_CONFIG/CA\ Toronto.ovpn
RUN sed -i '/^ca/ s/ / \/PIA_CONFIG\//' /PIA_CONFIG/CA\ Toronto.ovpn

RUN echo "script-security 2" >> /PIA_CONFIG/CA\ Toronto.ovpn
RUN echo "up /PIA_CONFIG/update-resolv-conf.sh" >> /PIA_CONFIG/CA\ Toronto.ovpn
RUN echo "down /PIA_CONFIG/update-resolv-conf.sh" >> /PIA_CONFIG/CA\ Toronto.ovpn

ADD .pia.cfg /PIA_CONFIG/.pia.cfg
ADD https://raw.githubusercontent.com/masterkorp/openvpn-update-resolv-conf/master/update-resolv-conf.sh /PIA_CONFIG/update-resolv-conf.sh
ADD openvpn.sh /PIA_CONFIG/openvpn.sh

RUN chmod +x /PIA_CONFIG/update-resolv-conf.sh
RUN chmod +x /PIA_CONFIG/openvpn.sh

VOLUME /PIA_CONFIG