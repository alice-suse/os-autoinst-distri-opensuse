# SUSE's openQA tests
#
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: virt_autotest: the initial version of virtualization automation test in openqa, with kvm and xen support fully
# Maintainer: alice <xlai@suse.com>

package virt_manager_example;
use base "y2logsstep";
use strict;
use warnings;
use File::Basename;
use testapi;
use Utils::Backends 'use_ssh_serial_console';
use ipmi_backend_utils;

sub run {
    my $self = shift;

    use_ssh_serial_console;
    #GUI test of virt-manger
    assert_script_run("virsh list --all");
    type_string "Will start GUI test\n";
    save_screenshot;
    type_string "virt-manager\n";
    wait_still_screen;
    save_screenshot;
    sleep 10;
    save_screenshot;

    assert_and_click "new-vm-button";
    wait_still_screen;
    save_screenshot;

    assert_and_click "forward";
    wait_still_screen;
    save_screenshot;

    assert_and_click "cancel";
    wait_still_screen;
    save_screenshot;

    assert_and_click "close";
    wait_still_screen;
    save_screenshot;

    type_string "\n";
    assert_script_run("echo 'back to terminal after GUI test'");
    save_screenshot;
     
}

sub post_fail_hook {
    return 0;
}
1;

