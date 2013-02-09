SOFT:=php
VER:=5.4.11
SUF:=tar.bz2
URL:=http://www.php.net/get/php-5.4.11.tar.bz2/from/cn2.php.net/mirror
MD5:=9975e68c22b86b013b934743ad2d2276
TAR:=$(SOFT)-$(VER).$(SUF)
DIR:=$(SOFT)-$(VER)

all:
	@echo $(TAR)

config:
	cd $(DIR) && ./configure --prefix=/usr/local/php \
		--with-mysql=/usr/local/mysql \
		--with-mysqli=/usr/local/mysql/bin/mysql_config \
		--with-mysql-sock=/var/run/mysqld/mysqld.sock

build:
	cd $(DIR) && make

install:
	cd $(DIR) && make install

pre:
	mkdir -p /usr/local/mysql
	mkdir -p /var/mysqldata
	chmod 777 /var/mysqldata
	groupadd mysql
	useradd -g mysql mysql

unzip:
	tar jxvf $(TAR)

