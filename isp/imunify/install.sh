#!/bin/bash

if [ ! -f "/opt/php71/lib/php/modules/ioncube_loader_lin_7.1.so" ] ;
then
    echo "Install php 7.1 with ioncube support"
    exit 1
fi

if [ -f "/usr/local/mgr5/sbin/mgrctl" ] ;
then
    echo "Start installation"

    line='zend_extension=/opt/php71/lib/php/modules/ioncube_loader'
    file=/opt/php71/etc/php.ini
    if ! grep -q "$line" "$file"; then
        echo "* Add ioncube extension in /opt/php71/etc/php.ini"
        echo "zend_extension=/opt/php71/lib/php/modules/ioncube_loader_lin_7.1.so" >> /opt/php71/etc/php.ini 
    fi

    cd /tmp && wget -O ra-for-ispmanlite.zip https://files.imunify360.com/static/isp-imunifyav/v1/isp-imunifyav/ra-for-ispmanlite.zip && \
    unzip ra-for-ispmanlite.zip -d ra-isp-package-0x0000 && cd ra-isp-package-0x0000 && chmod +x *.sh && ./install.sh && \
    cd .. && find ra-isp-package-0x0000 -delete && rm ra-for-ispmanlite.zip

else
    echo "ISPmanager Lite v5 not found"
fi

