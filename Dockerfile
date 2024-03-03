# Docker image for TYPO3 CMS
# Copyright (C) 2016-2023  Martin Helmich <martin@helmich.me>
#                          and contributors <https://github.com/martin-helmich/docker-typo3/graphs/contributors>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# NOTE: This file is automatically generated from a template. Please
# do not make any changes to this file directly, and consult the
# CONTRIBUTING document, first.

FROM php:8.2-apache-bookworm

# Install TYPO3
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        wget \
        rsync \
        # Configure PHP
        libxml2-dev libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng-dev \
        libpq-dev \
        libzip-dev \
        zlib1g-dev \
# Install required 3rd party tools
        graphicsmagick && \
# Configure extensions
    docker-php-ext-configure gd --with-libdir=/usr/include/ --with-jpeg --with-freetype && \
    docker-php-ext-install -j$(nproc) mysqli soap gd zip opcache intl pgsql pdo_pgsql && \
    echo 'always_populate_raw_post_data = -1\nmax_execution_time = 240\nmax_input_vars = 1500\nupload_max_filesize = 32M\npost_max_size = 32M' > /usr/local/etc/php/conf.d/typo3.ini && \
# Configure Apache as needed
    a2enmod rewrite && \
    apt-get clean && \
    apt-get -y purge \
        libxml2-dev libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng-dev \
        libzip-dev \
        zlib1g-dev && \
    rm -rf /var/lib/apt/lists/* /usr/src/*

RUN echo "error_reporting = E_ALL" > /usr/local/etc/php/conf.d/error_reporting.ini
RUN echo "display_errors = On" >> /usr/local/etc/php/conf.d/error_reporting.ini
RUN echo "log_errors = On" >> /usr/local/etc/php/conf.d/error_reporting.ini

RUN cd /var/www/html && \
    wget -O download.tar.gz https://get.typo3.org/12.4.11 && \
    echo "a93bb3e8ceae5f00c77f985438dd948d2a33426ccfd7c2e0e5706325c43533a3 download.tar.gz" > download.tar.gz.sum && \
    sha256sum -c download.tar.gz.sum && \
    tar -xzf download.tar.gz && \
    rm download.* && \
    ln -s typo3_src-* typo3_src && \
    ln -s typo3_src/index.php && \
    ln -s typo3_src/typo3 && \
    cp typo3/sysext/install/Resources/Private/FolderStructureTemplateFiles/root-htaccess .htaccess && \
    mkdir typo3temp && \
    mkdir typo3conf && \
    mkdir fileadmin && \
    mkdir uploads && \
    touch FIRST_INSTALL && \
    chown -R www-data. .

RUN echo '#!/bin/bash' > /usr/bin/typo3 && \
    echo 'TYPO3_BINARY="/var/www/html/typo3/sysext/core/bin/typo3"' >> /usr/bin/typo3 && \
    echo 'php "$TYPO3_BINARY" "$@"' >> /usr/bin/typo3 && \
    chmod +x /usr/bin/typo3

USER www-data

# Configure volumes
VOLUME /var/www/html/fileadmin
VOLUME /var/www/html/typo3conf
VOLUME /var/www/html/typo3temp
VOLUME /var/www/html/uploads
