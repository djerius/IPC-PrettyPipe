TEMPLATE_ROOT = /proj/axaf/simul/lib/templates/makefiles
TARGET=MACH_OSMAJREV
include $(TEMPLATE_ROOT)/sysinfo

LIB_DIR = $(install-prefix)/lib/perl

PM = PipeC.pm

check :
	$(PERL) -w -c $(PM)

install :
	cp $(PM) $(LIB_DIR)/$(PM)

FORCE:

clean :
	@echo "# Cleaning" ; \
	 $(RM) -f *.toc *.dvi *.log *.exp *.info *.BAK *.o *.bak *.d *.p *~; \
	 $(RM) -f make.out rcsdiff.out Makefile.sysinfo


DOC_DIR = .
DOC_EXT = .pm
DOC = $(PM:%.pm=%)
include $(TEMPLATE_ROOT)/docs_pod
