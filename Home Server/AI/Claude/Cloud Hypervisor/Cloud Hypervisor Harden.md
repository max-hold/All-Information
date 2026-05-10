"Enable SECCOMP bpf filters on the CH process" means enabling a seccomp-bpf (Secure Computing with BPF) sandbox on the main Cloud Hypervisor (CH) process itself.
What is seccomp-bpf?
Seccomp (short for SECure COMPuting) is a Linux kernel feature that allows a process to restrict which system calls (syscalls) it can make after it starts. In filter mode (the useful one), it uses a BPF program (Berkeley Packet Filter — the same technology used for packet filtering) to inspect each syscall and decide:

Allow it
Deny it (usually return an error or kill the process)
Log it, etc.

Once the filter is loaded, it cannot be removed or relaxed. Child processes inherit it. This is a very effective way to reduce the attack surface of a program: even if the process is compromised (e.g., via a memory corruption bug), the attacker is limited to only the very small set of syscalls the filter explicitly allows.
Why Cloud Hypervisor enables it on the "CH process"
Cloud Hypervisor is a lightweight, Rust-based VMM (Virtual Machine Monitor) designed for cloud workloads (often used with KVM). The "CH process" is the main cloud-hypervisor binary that runs on the host and manages the VM.
By default, Cloud Hypervisor already enables seccomp filtering because the project treats security as non-optional. The message you saw is likely from documentation, a command-line option, a config flag, or a build/runtime note telling you that this protection is (or can be) active for the hypervisor process itself.
What it does in practice:

Drastically limits what the hypervisor process can do on the host (e.g., it can still do the necessary things like ioctl() for KVM, memory management, virtio handling, but blocks dangerous syscalls like mount, ptrace, bpf loading, kexec, etc.).
Provides defense-in-depth: even if there's a bug in Cloud Hypervisor, escaping to the host or doing serious damage becomes much harder.
Has very low performance overhead (the filter runs in the kernel very early on every syscall).

You can usually disable it for debugging/development (as the docs mention), but it's recommended to keep it on in production.
