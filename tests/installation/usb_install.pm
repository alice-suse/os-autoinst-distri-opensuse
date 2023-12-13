# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: 
# On a minimum system that is launched by ipxe and 
# stops at sshd-server-started, dd installation iso to the first 
# usb device, and launch the installation with usb.
# Maintainer: Xiaoli Ai(Alice) <xlai@suse.com>, qe-virt@suse.de

package usb_install;
use base 'y2_installbase';
use strict;
use warnings;

use utils;
use testapi;
use bmwqemu;
use ipmi_backend_utils;
use version_utils qw(is_upgrade is_tumbleweed is_sle is_leap);
use Utils::Architectures;
use LWP::Simple 'head';
use Time::HiRes 'sleep';

sub run {
    #select_console 'sol', await_console => 0;
    #assert_screen('sshd-server-started', 20);
    select_console('root-ssh');
    assert_script_run("set -o pipefail");

    # find the first usb drive 
    my $usb = script_output("ls /dev/disk/by-id/ -l | grep -i usb | grep -i -v -E \"generic|part\" | head -1 | sed 's#^.*\\\/##'");
    record_info("Disk info on the machine:", script_output("ls /dev/disk/by-id/ -l; fdisk -l"));
    die "No proper usb device!" unless $usb;
    $usb = "/dev/$usb";
    record_info("Going to use usb drive $usb to store ISO.");

    # download and dd the iso to usb
    my $download_url = get_required_var('OPENQA_URL') . "/assets/iso/" . get_required_var('ISO');
    die "ISO URL is not accessible: $download_url." unless head($download_url);
    my $cmd = "curl -L $download_url | dd of=$usb bs=1M";
    script_retry($cmd, retry => 2, delay => 10, timeout => 600, die => 1);
    my $checksum = script_output("sha256sum $usb" . ' |cut -d\' \' -f 1');
    if ($checksum eq get_required_var('CHECKSUM_ISO')) {
        record_info("ISO successfully dd to $usb.", "ISO source $download_url.");
    } else {
        die("ISO dd to $usb failed.\nISO source $download_url.\nExpected sha256sum: " . get_required_var('CHECKSUM_ISO') . ".\nReal sha256sum: $checksum.");
    }

    # flush
    assert_script_run("sync");

    # set next boot to usb
    set_floppy_boot;

    # power reset
    ipmitool("chassis power reset");

    select_console 'sol', await_console => 0;
}

sub post_fail_hook {
    # ipmitool boot to disk
    # super::post_fail_hook
    my $self = shift;

    # To not affect following jobs 
    set_disk_boot;
    $self->SUPER::post_fail_hook;
}

1;
