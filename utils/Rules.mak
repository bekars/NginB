################################################################################
# Makefile rules define
#
#
# History:
#   2010.08.01	bekars	create the Makefile
#
################################################################################

MAJOR_VERSION    :=1
MINOR_VERSION    :=1
SUBLEVEL_VERSION :=0
EXTRAVERSION     :=
VERSION   	 :=$(MAJOR_VERSION).$(MINOR_VERSION).$(SUBLEVEL_VERSION)$(EXTRAVERSION)
BUILDTIME 	 := $(shell TZ=UTC date -u "+%Y.%m.%d-%H:%M%z")


CROSS          	:= 
CC             	:= $(CROSS)gcc
AR             	:= $(CROSS)ar
AS             	:= $(CROSS)as
LD             	:= $(CROSS)ld
NM             	:= $(CROSS)nm
STRIP          	:= $(CROSS)strip
CPP            	:= $(CC) -E
RM             	:= rm
RM_F           	:= $(RM) -f
RM_R           	:= $(RM) -rf
LN             	:= ln
LN_S           	:= $(LN) -s
MKDIR          	:= mkdir
MKDIR_P        	:= $(MKDIR) -p
MV             	:= mv
CP             	:= cp

CFLAGS  	:= -g -O2 -Wall -Wunused -Wstrict-prototypes
LDFLAGS 	:= -L.

ifdef DEBUG
	CFLAGS += -D__X_DEBUG__
endif

COMPILE   	= $(CC) $(CFLAGS) $(INCLUDE) $(DEFS) $(LDFLAGS_EX) $(LDFLAGS)
COMPILE_C 	= $(CC) $(CFLAGS) $(INCLUDE) $(DEFS)

define now_make_it
	@echo "... NOW IS MAKING PACKAGE $@ ..."
endef

