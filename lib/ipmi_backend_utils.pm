# SUSE's openQA tests
#
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
package ipmi_backend_utils;
# Summary: This file provides fundamental utilities related with the ipmi backend from test view,
#          like switching consoles between ssh and ipmi supported
# Maintainer: alice <xlai@suse.com>

use base Exporter;
use Exporter;
use strict;
use warnings;
use testapi;

our @EXPORT = qw(use_ssh_serial_console set_serial_console_on_xen);

#With the new ipmi backend, we only use the root-ssh console when the SUT boot up,
#and no longer setup the real serial console for either kvm or xen.
#When needs reboot, we will switch back to sut console which relies on ipmi.
#We will mostly rely on ikvm to continue the test flow.
#TODO: we need the serial output to debug issues in reboot, coolo will help add it.

#use it after SUT boot finish, as it requires ssh connection to SUT to interact with SUT, including window and serial console
sub use_ssh_serial_console() {
    console('sol')->disable;
    select_console('root-ssh');
    $serialdev = 'sshserial';
    set_var('SERIALDEV', 'sshserial');
    bmwqemu::save_vars();
}

my $grub_ver;

sub get_dom0_serialdev() {
    my $root_dir = shift;
    $root_dir //= '/';

    my $dom0_serialdev;

    script_run("clear");
    script_run("cat ${root_dir}/etc/SuSE-release");
    save_screenshot;
    assert_screen([qw(on_host_sles_12_sp2_or_above on_host_lower_than_sles_12_sp2)]);

    if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen")) {
        if (match_has_tag("on_host_sles_12_sp2_or_above")) {
            $dom0_serialdev = "hvc0";
        }
        elsif (match_has_tag("on_host_lower_than_sles_12_sp2")) {
            $dom0_serialdev = "xvc0";
        }
    }
    else {
        $dom0_serialdev = 'ttyS1';
    }

    if (match_has_tag("grub1")) {
        $grub_ver = "grub1";
    }
    else {
        $grub_ver = "grub2";
    }

    type_string("echo \"Debug info: hypervisor serial dev should be $dom0_serialdev. Grub version is $grub_ver.\"\n");

    return $dom0_serialdev;
}

sub setup_console_in_grub {
    my ($ipmi_console, $root_dir) = @_;
    $ipmi_console //= $serialdev;
    $root_dir     //= '/';

    #set grub config file
    my $grub_cfg_file;
    if ($grub_ver eq "grub2") {
        $grub_cfg_file = "${root_dir}/boot/grub2/grub.cfg";
    }
    elsif ($grub_ver eq "grub1") {
        $grub_cfg_file = "${root_dir}/boot/grub/menu.lst";
    }
    else {
        die "The grub version is not supported!";
    }

    #setup serial console for xen
    my $cmd;
    if ($grub_ver eq "grub2") {
        #grub2
        $cmd
          = "cp $grub_cfg_file ${grub_cfg_file}.org \&\& sed -ri '/(multiboot|module\\s*.*vmlinuz)/ {s/(console|loglevel|log_lvl|guest_loglvl)=[^ ]*//g; /multiboot/ s/\$/ console=com2,115200 log_lvl=all guest_loglvl=all/; /module\\s*.*vmlinuz/ s/\$/ console=$ipmi_console,115200 console=tty loglevel=5/;}' $grub_cfg_file";
        assert_script_run("$cmd");
        save_screenshot;
        $cmd = "sed -rn '/(multiboot|module\\s*.*vmlinuz)/p' $grub_cfg_file";
        assert_script_run("$cmd");
    }
    elsif ($grub_ver eq "grub1") {
        $cmd
          = "cp $grub_cfg_file ${grub_cfg_file}.org \&\&  sed -i 's/timeout [0-9]*/timeout 10/; /module \\\/boot\\\/vmlinuz/{s/console=.*,115200/console=$ipmi_console,115200/g;}' $grub_cfg_file";
        assert_script_run("$cmd");
        save_screenshot;
        $cmd = "sed -rn '/module \\\/boot\\\/vmlinuz/p' $grub_cfg_file";
        assert_script_run("$cmd");
    }
    else {
        die "Not supported grub version!";
    }
    save_screenshot;
    upload_logs("$grub_cfg_file");
}

sub mount_installation_disk() {
    my ($installation_disk, $mount_point) = @_;

    #default from yast installation
    $installation_disk //= "/dev/sda2";
    $mount_point       //= "/mnt";

    #mount
    assert_script_run("mkdir -p $mount_point");
    assert_script_run("mount $installation_disk $mount_point");
    assert_script_run("ls ${mount_point}/boot");
}

sub set_serial_console_on_xen() {
    my ($installation_disk, $mount_point) = @_;

    my $root_dir;
    if ($installation_disk ne "") {
        mount_installation_disk($installation_disk, $mount_point);
        $root_dir = $mount_point;
    }
    else {
        $root_dir = "/";
    }


    my $ipmi_console = get_dom0_serialdev($root_dir);
    setup_console_in_grub($ipmi_console, $root_dir);
}


1;

