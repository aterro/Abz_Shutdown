#
# shutdown_efi/Makefile
# Build control file for the ABZ_Shutdown.efi utility
#

SRCDIR = .

VPATH = $(SRCDIR)

ARCH            = $(shell uname -m | sed s,i[3456789]86,ia32,)

TARGET	= ABZ_Shutdown.efi
SHUTDOWN_SBAT_CSV ?= abz-shutdown.csv

ifeq ($(ARCH),ia32)
  LIBEG = build32
  TARGET = ABZ_Shutdown_ia32.efi
endif

ifeq ($(ARCH),x86_64)
  LIBEG = build64
  TARGET = ABZ_Shutdown_x64.efi
endif

ifeq ($(ARCH),aarch64)
  LIBEG = build
  TARGET = ABZ_Shutdown_aa64.efi
endif

LOCAL_GNUEFI_CFLAGS  = -I$(SRCDIR) -I$(SRCDIR)/../include
LOCAL_LDFLAGS   =
LOCAL_LIBS      =

OBJS            = shutdown.o

include $(SRCDIR)/../Make.common

all: $(TARGET)

$(SHLIB_TARGET): $(OBJS)
	$(LD) $(LOCAL_LDFLAGS) $(GNUEFI_LDFLAGS) $(SUBSYSTEM_LDFLAG) $(OBJS) \
	      -o $@ $(LOCAL_LIBS) $(GNUEFI_LIBS)

$(TARGET): $(SHLIB_TARGET)
	$(OBJCOPY) -j .text -j .sdata -j .data -j .dynamic -j .dynsym -j .rodata \
		   -j .rel -j .rela -j .rel.* -j .rela.* -j .rel* -j .rela* \
		   -j .reloc --strip-unneeded $(FORMAT) $< $@
ifneq ($(OMIT_SBAT), 1)
	    $(OBJCOPY) --add-section .sbat=$(SRCDIR)/../$(SHUTDOWN_SBAT_CSV) \
		       --adjust-section-vma .sbat+10000000 $@
endif
	chmod a-x $(TARGET)

clean:
	rm -f $(TARGET) *~ *.so $(OBJS) *.efi *.obj ABZ_Shutdown_*.txt \
		ABZ_Shutdown_*.dll *.lib
