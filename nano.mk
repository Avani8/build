################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
override COMPILE_NS_USER   := 64
override COMPILE_NS_KERNEL := 64
override COMPILE_S_USER    := 64
override COMPILE_S_KERNEL  := 64

DEBUG ?= 0
BUILDROOT_GETTY_PORT ?= ttyS0

include common.mk

################################################################################
# Paths to git projects and various binaries
################################################################################
ARM_TF_PATH		?= $(ROOT)/arm-trusted-firmware-master
UBOOT_PATH		?= $(ROOT)/u-boot
UBOOT_BIN		?= $(UBOOT_PATH)/spl/sunxi-spl.bin
QEMU_PATH	        ?= $(ROOT)/qemu
BINARIES_PATH           ?= $(ROOT)/qemu
SOC_TERM_PATH	        ?= $(ROOT)/soc_term
OUT_BR 			?= $(ROOT)/out-br
LINUX_DTB		?= $(ROOT)/linux/arch/arm64/boot/dts/allwinner
NPI_BOOT_CONFIG		?= $(ROOT)/linux
LINUX_IMAGE		?= $(ROOT)/linux/arch/arm64/boot
MODULE_OUTPUT		?= $(ROOT)/module_output
################################################################################
# Targets
################################################################################
all:arm-tf u-boot linux optee-os buildroot
clean: arm-tf-clean buildroot-clean u-boot-clean optee-os-clean

include toolchain.mk

################################################################################
# ARM Trusted Firmware
################################################################################
ARM_TF_EXPORTS ?= \
	CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

ARM_TF_FLAGS ?= \
        BL32=$(OPTEE_OS_HEADER_V2_BIN) \
	BL32_EXTRA1=$(OPTEE_OS_PAGER_V2_BIN) \
	BL32_EXTRA2=$(OPTEE_OS_PAGEABLE_V2_BIN) \
	BL33=$(UBOOT_BIN) \
	PLAT=sun50i_h5 \
	ARM_TSP_RAM_LOCATION=dram \
	DEBUG=0 \
	SPD=opteed

#
arm-tf: optee-os u-boot
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS)  all fip

arm-tf-clean:
	$(ARM_TF_EXPORTS) $(MAKE) -C $(ARM_TF_PATH) $(ARM_TF_FLAGS) clean

################################################################################
# Das U-Boot
################################################################################

UBOOT_EXPORTS ?= CROSS_COMPILE="$(CCACHE)$(AARCH64_CROSS_COMPILE)"

UBOOT_DEFCONFIG_FILES := \
	$(UBOOT_PATH)/configs/nanopi_neo_plus2_defconfig \
	$(ROOT)/build/kconfigs/uboot_nano.conf

uboot-defconfig: $(UBOOT_PATH)/.config
.PHONY: u-boot
u-boot:
	cd $(UBOOT_PATH) \
		
	$(UBOOT_EXPORTS) $(MAKE) -C $(UBOOT_PATH) all

u-boot-clean:
	$(UBOOT_EXPORTS) $(MAKE) -C $(UBOOT_PATH) clean

################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH := arm64
LINUX_DEFCONFIG_COMMON_FILES := \
		$(LINUX_PATH)/arch/arm64/configs/nanopi_h5_defconfig \
		$(CURDIR)/kconfigs/nano.conf

linux-defconfig: $(LINUX_PATH)/.config

LINUX_COMMON_FLAGS += ARCH=arm64

linux: linux-common
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS) INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=$(MODULE_OUTPUT) modules_install
linux-defconfig-clean: linux-defconfig-clean-common

LINUX_CLEAN_COMMON_FLAGS += ARCH=arm64

linux-clean: linux-clean-common

LINUX_CLEANER_COMMON_FLAGS += ARCH=arm64

linux-cleaner: linux-cleaner-common

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS += PLATFORM=sunxi-sun50i_h5
optee-os: optee-os-common

OPTEE_OS_CLEAN_COMMON_FLAGS += PLATFORM=sunxi-sun50i_h5
optee-os-clean: optee-os-clean-common





################################################################################
# Build-ROOT
################################################################################

$(ROOT)/out-br/images/ramdisk.img: $(ROOT)/out-br/images/rootfs.cpio.gz
	$(ROOT)/../u-boot/tools/mkimage -A arm64 -O linux -T ramdisk -C gzip \
		-d $< $@

#FTP-UPLOAD = ftp-upload -v --host $(nano_IP) --dir SOFTWARE

#.PHONY: flash
#flash: $(ROOT)/out-br/images/ramdisk.img
	#@test -n "$(nano_IP)" || \
	#	(echo "nano_IP not set" ; exit 1)
	#$(FTP-UPLOAD) $(ROOT)/u-boot/spl/sunxi-spl.bin
	#$(FTP-UPLOAD) $(ROOT)/u-boot/u-boot.itb
	#$(FTP-UPLOAD) $(ARM_TF_PATH)/build/sun50i_h5/release/bl31.bin
	#$(FTP-UPLOAD) $(ARM_TF_PATH)/build/sun50i_h5/release/fip.bin
	#$(FTP-UPLOAD) $(ROOT)/linux/arch/arm64/boot/Image
	#$(FTP-UPLOAD) $(ROOT)/linux/arch/arm64/boot/dts/allwinner/sun50i-h5-nanopi*.dtb
	#$(FTP-UPLOAD) $(ROOT)/out-br/images/ramdisk.img
	


################################################################################
#Create Image
################################################################################

# Creating images etc, could wipe out a drive on the system, therefore we don't
# want to automate that in script or make target. Instead we just simply provide
# the steps here.
.PHONY: img-help
img-help:
	@echo "$$ fdisk /dev/sdx   # where sdx is the name of your sd-card"
	@echo "   > p             # prints partition table"
	@echo "   > d             # repeat until all partitions are deleted"
	@echo "   > n             # create a new partition"
	@echo "   > p             # create primary"
	@echo "   > 1             # make it the first partition"
	@echo "   > <enter>       # use the default sector"
	@echo "   > +32M          # create a boot partition with 32MB of space"
	@echo "   > n             # create rootfs partition"
	@echo "   > p"
	@echo "   > 2"
	@echo "   > <enter>"
	@echo "   > <enter>       # fill the remaining disk, adjust size to fit your needs"
	@echo "   > t             # change partition type"
	@echo "   > 1             # select first partition"
	@echo "   > e             # use type 'e' (FAT16)"
	@echo "   > a             # make partition bootable"
	@echo "   > 1             # select first partition"
	@echo "   > p             # double check everything looks right"
	@echo "   > w             # write partition table to disk."
	@echo ""
	@echo "run the following as root"
	@echo "   $$ mkfs.vfat -F16 -n BOOT /dev/sdx1"
	@echo "   $$ mkdir -p /media/boot"
	@echo "   $$ mount /dev/sdx1 /media/boot"
	@echo "   $$ cd /media"
	@echo "   $$ gunzip -cd $(ROOT)/out-br/images/rootfs.cpio.gz | sudo cpio -idmv \"boot/*\""
	@echo "   $$ umount boot"
	@echo ""
	@echo "run the following as root"
	@echo "   $$ mkfs.ext4 -L rootfs /dev/sdx2"
	@echo "   $$ mkdir -p /media/rootfs"
	@echo "   $$ mount /dev/sdx2 /media/rootfs"
	@echo "   $$ cd rootfs"
	@echo "   $$ gunzip -cd $(ROOT)/out-br/images/rootfs.cpio.gz | sudo cpio -idmv"
	@echo "   $$ rm -rf /media/rootfs/boot/*"
	@echo "   $$ cd .. && umount rootfs"
