FROM ubuntu:trusty
MAINTAINER Nicky Vandevoorde <@iampuma>
ENV DEBIAN_FRONTEND noninteractive
ARG DRUPAL_VERSION=8.1.3

RUN apt-get update && \
    apt-get install -y \
      curl \
      git \
      nginx \
      openssh-server \
      php-pear \
      php5-curl \
      php5-dev \
      php5-fpm \
      php5-gd \
      php5-mcrypt \
      php5-mysql \
      php5-xdebug \
      software-properties-common \
      supervisor \
      wget \
      zip && \
    rm -r /var/lib/apt/lists/*

# Install MariaDB from repository.
RUN echo "deb http://ftp.osuosl.org/pub/mariadb/repo/5.5/ubuntu trusty main" > /etc/apt/sources.list.d/mariadb.list && \
    apt-get update && \
    apt-get install -y --force-yes mariadb-server mariadb-server-5.5 && \
    rm -r /var/lib/apt/lists/*

# Install Composer.
RUN curl -sS https://getcomposer.org/installer | php
RUN mv composer.phar /usr/local/bin/composer

# Install Drush 8.
RUN wget http://files.drush.org/drush.phar
RUN mv drush.phar /usr/local/bin/drush && chmod +x /usr/local/bin/drush

# Install Drupal Console.
RUN curl http://drupalconsole.com/installer -L -o drupal.phar
RUN mv drupal.phar /usr/local/bin/drupal && chmod +x /usr/local/bin/drupal
RUN drupal init

# Install Nodejs & npm.
RUN add-apt-repository -y ppa:chris-lea/node.js
RUN apt-get update
RUN apt-get -y install nodejs

# Setup ssh
RUN echo 'root:root' | chpasswd
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN mkdir /var/run/sshd && chmod 0755 /var/run/sshd
RUN mkdir -p /root/.ssh/ && touch /root/.ssh/authorized_keys

ADD config/supervisord.conf /etc/supervisor/conf.d/lemp.conf
ADD config/nginx.conf /etc/nginx/sites-available/default
ADD config/xdebug.conf /etc/php5/mods-available/xdebug.ini
ADD scripts/run.sh run.sh

RUN sed -i 's/^\(\[supervisord\]\)$/\1\nnodaemon=true/' /etc/supervisor/supervisord.conf

RUN drush dl drupal-${DRUPAL_VERSION} -y --destination=/usr/share/nginx --drupal-project-rename=drop
RUN service mysql start && \
  cd /usr/share/nginx/drop && \
  drush si standard -y install_configure_form.update_status_module='array(FALSE,FALSE)' --account-name=admin --account-pass=admin --db-url=mysql://admin:admin@localhost/admin --db-su=root --site-name="Drop" && \
  chown -R www-data /usr/share/nginx/drop

EXPOSE 80 22 9000

ENTRYPOINT ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
