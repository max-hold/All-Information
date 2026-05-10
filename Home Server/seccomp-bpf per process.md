- Adding **seccomp-bpf per process** is a solid hardening step. It lets you restrict which Linux syscalls a process is allowed to make. In practice:

* Firefox can browse normally
* but if a compromised process tries weird syscalls (mounting filesystems, ptrace, namespace tricks, etc.), the kernel kills or blocks it.

Think of it as telling the kernel: “this process may only use this small syscall vocabulary.”

For your setup, the best target is **Firefox itself**, not every process in Alpine (too brittle).

---

# Architecture

```text id="8d6s1v"
Firefox
   ↓
seccomp-bpf filter
   ↓
Linux kernel
```

If Firefox or child processes call forbidden syscalls:

* process killed
* or syscall denied with EPERM

---

# 1. Install tools

Inside Alpine:

```bash id="95hlwc"
apk add libseccomp libseccomp-dev gcc musl-dev
```

---

# 2. Create seccomp launcher

Create:

```bash id="z2w4m7"
nano /usr/local/bin/firefox-seccomp.c
```

Paste:

```c id="w2g4cg"
#include <seccomp.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    scmp_filter_ctx ctx;

    ctx = seccomp_init(SCMP_ACT_KILL);
    if (!ctx) {
        perror("seccomp_init");
        return 1;
    }

    /* Allow essential syscalls */
    int syscalls[] = {
        SCMP_SYS(read),
        SCMP_SYS(write),
        SCMP_SYS(open),
        SCMP_SYS(openat),
        SCMP_SYS(close),
        SCMP_SYS(stat),
        SCMP_SYS(fstat),
        SCMP_SYS(newfstatat),
        SCMP_SYS(mmap),
        SCMP_SYS(mprotect),
        SCMP_SYS(munmap),
        SCMP_SYS(brk),
        SCMP_SYS(rt_sigaction),
        SCMP_SYS(rt_sigprocmask),
        SCMP_SYS(ioctl),
        SCMP_SYS(pread64),
        SCMP_SYS(pwrite64),
        SCMP_SYS(access),
        SCMP_SYS(pipe),
        SCMP_SYS(pipe2),
        SCMP_SYS(select),
        SCMP_SYS(poll),
        SCMP_SYS(ppoll),
        SCMP_SYS(epoll_wait),
        SCMP_SYS(epoll_ctl),
        SCMP_SYS(socket),
        SCMP_SYS(connect),
        SCMP_SYS(sendto),
        SCMP_SYS(recvfrom),
        SCMP_SYS(sendmsg),
        SCMP_SYS(recvmsg),
        SCMP_SYS(getpid),
        SCMP_SYS(gettid),
        SCMP_SYS(futex),
        SCMP_SYS(clock_gettime),
        SCMP_SYS(nanosleep),
        SCMP_SYS(exit),
        SCMP_SYS(exit_group),
        SCMP_SYS(clone),
        SCMP_SYS(clone3),
        SCMP_SYS(execve),
        SCMP_SYS(wait4),
        SCMP_SYS(prlimit64),
        SCMP_SYS(getrandom)
    };

    int count = sizeof(syscalls) / sizeof(syscalls[0]);

    for (int i = 0; i < count; i++) {
        seccomp_rule_add(ctx, SCMP_ACT_ALLOW, syscalls[i], 0);
    }

    /* Explicitly deny dangerous syscalls */
    seccomp_rule_add(ctx, SCMP_ACT_KILL, SCMP_SYS(ptrace), 0);
    seccomp_rule_add(ctx, SCMP_ACT_KILL, SCMP_SYS(mount), 0);
    seccomp_rule_add(ctx, SCMP_ACT_KILL, SCMP_SYS(umount2), 0);
    seccomp_rule_add(ctx, SCMP_ACT_KILL, SCMP_SYS(kexec_load), 0);
    seccomp_rule_add(ctx, SCMP_ACT_KILL, SCMP_SYS(reboot), 0);

    if (seccomp_load(ctx) < 0) {
        perror("seccomp_load");
        return 1;
    }

    seccomp_release(ctx);

    execl("/usr/bin/firefox", "firefox", "--kiosk",
          "https://www.google.com", NULL);

    perror("execl");
    return 1;
}
```

---

# 3. Compile

```bash id="crn1t2"
gcc /usr/local/bin/firefox-seccomp.c -lseccomp -o /usr/local/bin/firefox-seccomp
chmod +x /usr/local/bin/firefox-seccomp
```

---

# 4. Replace Firefox autostart

Edit:

```bash id="1dr4po"
nano /home/browser-vm/.config/autostart/firefox.desktop
```

Use:

```ini id="h0ff8l"
[Desktop Entry]
Type=Application
Name=Firefox Kiosk
Exec=/usr/local/bin/firefox-seccomp
X-GNOME-Autostart-enabled=true
```

Now Firefox always launches under seccomp.

---

# 5. Add syscall logging first (recommended)

Before killing, use log mode to learn what Firefox needs.

Change:

```c id="tv3rcg"
ctx = seccomp_init(SCMP_ACT_LOG);
```

instead of:

```c id="rvj21r"
ctx = seccomp_init(SCMP_ACT_KILL);
```

This logs denied syscalls.

Check:

```bash id="cvsx3r"
dmesg | grep SECCOMP
```

or:

```bash id="7z7l18"
journalctl | grep SECCOMP
```

After tuning, switch back to KILL.

This avoids Firefox exploding because you forgot one syscall 😄

---

# 6. Useful syscalls to forbid

Strong denies:

```text id="04e2r1"
ptrace
mount
umount2
kexec_load
reboot
setns
unshare
pivot_root
swapon
swapoff
init_module
finit_module
delete_module
```

Add them:

```c id="s5xjpk"
seccomp_rule_add(ctx, SCMP_ACT_KILL, SCMP_SYS(setns), 0);
seccomp_rule_add(ctx, SCMP_ACT_KILL, SCMP_SYS(unshare), 0);
```

These block namespace/container tricks.

---

# 7. Optional stricter child process filtering

Firefox spawns child processes.

You can force no content sandbox escape by limiting forks:

Allow:

```text id="48w7im"
clone
clone3
wait4
```

but deny:

```text id="e3ew2w"
fork
vfork
```

Sometimes works, sometimes breaks plugins.

Test first.

---

# 8. Combine with kernel hardening

In `/etc/sysctl.conf`:

```bash id="t8s1t2"
kernel.unprivileged_bpf_disabled=1
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
kernel.yama.ptrace_scope=3
kernel.unprivileged_userns_clone=0
```

Apply:

```bash id="mjlwmq"
sysctl -p
```

Good combo with seccomp.

---

# 9. Verify working

Run:

```bash id="zx4wy0"
/usr/local/bin/firefox-seccomp
```

Try forbidden syscall test:

```bash id="73jckx"
strace -e ptrace firefox
```

Should fail / get killed.

(Though ideally you removed `strace` from final VM.)

---

# Final result

You now have:

✔ Firefox in kiosk
✔ disposable VM
✔ immutable root
✔ MITM proxy
✔ network restrictions
✔ seccomp syscall filtering

Security chain:

```text id="x6f4vf"
Firefox
 → seccomp-bpf
 → bubblewrap
 → Alpine guest
 → QEMU/KVM isolation
 → host firewall + MITM
```

That’s a pretty serious browser appliance.

One practical warning: seccomp profiles are notoriously finicky. Firefox updates may add syscalls, so after browser upgrades you may need to retune the allowlist.

If you want a cleaner setup, next upgrade is using **systemd service sandboxing + seccomp profile files** instead of custom C code, but Alpine/OpenRC makes that less straightforward.

