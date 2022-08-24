# SUSE's openQA tests
#
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: virt_autotest: the initial version of virtualization automation test in openqa, with kvm and xen support fully
# Maintainer: alice <xlai@suse.com>

package setup_virt_container;
use base 'y2_installbase';
use strict;
use warnings;
use File::Basename;
use testapi;
use Utils::Architectures;
use Utils::Backends qw(use_ssh_serial_console is_remote_backend set_ssh_console_timeout);
use ipmi_backend_utils;
use IPC::Run;
use utils;
use virt_autotest::utils qw(subscribe_extensions_and_modules);

sub launch_vt_workload_container {
    script_run("podman stop libvirtd ; podman rm libvirtd ; podman ps --all");
    save_screenshot;
    assert_script_run("cd /home/alice/vasily-alp-kvm-base-container/home:vulyanov/kvm-base-container");
    assert_script_run("podman create --name libvirtd --privileged --init --cgroupns host --publish 16001:16001 --publish 16022:22 --tls-verify=false --volume ./data:/var/lib/libvirt/images --volume /dev/sshserial:/dev/sshserial  registry.suse.de/home/vulyanov/alp/alp/kvm-base:latest");
    assert_script_run("podman start libvirtd");
    save_screenshot;
    assert_script_run("podman ps | grep -i libvirtd | grep Up");
    save_screenshot;
}

sub enter_vt_container_sh {
    enter_cmd("podman exec -ti libvirtd bash", 15); # interactive mode, so no return immediately
    save_screenshot;
    assert_screen('in-libvirtd-container-bash');
    assert_script_run("echo hello from libvirtd container");
    save_screenshot;

    #script_output("ls");
    #assert_script_run("ip a");
    #save_screenshot;
    record_info('Please check if contents are from within libvirtd container');

}

sub exit_vt_container {
    assert_script_run("clear");
    assert_screen('in-libvirtd-container-bash');
    enter_cmd("exit");
    wait_still_screen 3;
    save_screenshot;
    assert_screen('back-to-host-shell');

}

sub install_tools_within_vt_container {
    assert_script_run("clear");
    assert_screen('in-libvirtd-container-bash');
    zypper_call("in suseconnect-ng", 180);
    assert_script_run("SUSEConnect -r " . get_var('libvirtd-container-reg-code')); #todo, replace regcode by get_var
    zypper_call("in curl openssh hostname gawk supportutils", 120);
    virt_autotest::utils::subscribe_extensions_and_modules(reg_exts => 'sle-module-desktop-applications PackageHub');
    #zypper_call("in screen libguestfs0 yast2-schema-default sshpass nmap", 300);
    save_screenshot;
    #record_info("Successfully installed GI needed tools within VT container.");
    record_info("Successfully registered within VT container.");

}

sub setup_services_within_vt_container {
    assert_script_run("clear");
    assert_screen('in-libvirtd-container-bash');
    script_run('virsh net-destroy default');
    assert_script_run('virsh net-define /var/lib/libvirt/images/net-br123.xml');
    assert_script_run('virsh net-start alice-br123');
    assert_script_run('ip a');
    save_screenshot;
}

sub run {
    my $self = shift;
    
    launch_vt_workload_container;
    enter_vt_container_sh;

    install_tools_within_vt_container;
    setup_services_within_vt_container;

    #exit_vt_container;
}

sub post_fail_hook {
    my ($self) = @_;
    # to be added
    #$self->SUPER::post_fail_hook;
}

1;

