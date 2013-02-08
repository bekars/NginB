SOFT:=mysql
VER:=5.6.10
SUF:=tar.gz
URL:=http://dev.mysql.com/get/Downloads/MySQL-5.6/mysql-5.6.10.tar.gz/from/http://cdn.mysql.com/
MD5:=9dcee911fb4bc7e977a6b63f4d3ffa63
TAR:=$(SOFT)-$(VER).$(SUF)
DIR:=$(SOFT)-$(VER)

all:
	@echo $(TAR)

config:
	cd $(DIR) && cmake -DCMAKE_INSTALL_PREFIX=/usr/local/mysql \
		-DMYSQL_UNIX_ADDR=/var/mysqldata/mysql.sock \
		-DDEFAULT_CHARSET=utf8 \
		-DDEFAULT_COLLATION=utf8_general_ci \
		-DWITH_EXTRA_CHARSETS:STRING=utf8,gbk \
		-DWITH_MYISAM_STORAGE_ENGINE=1 \
		-DWITH_INNOBASE_STORAGE_ENGINE=1 \
		-DWITH_MEMORY_STORAGE_ENGINE=1 \
		-DWITH_READLINE=1 \
		-DENABLED_LOCAL_INFILE=1 \
		-DMYSQL_DATADIR=/var/mysqldata \
		-DMYSQL_USER=mysql \
		-DMYSQL_TCP_PORT=3306

build:
	cd $(DIR) && make

pre:
	mkdir -p /usr/local/mysql
	mkdir -p /var/mysqldata
	groupadd mysql
	useradd -g mysql mysql

unzip:
	tar zxvf $(TAR)

