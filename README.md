## 📦 What the Script Installs

### 🧱 System & Kernel

- `build-essential`, `linux-headers`, `linux-modules-extra`
- Group permissions for `docker`, `video`, and `render`

### 🔧 ROCm 7.x.x

- ROCm repository and GPG key
- Packages: `amdgpu-dkms`, `rocm`, `rocm-opencl-runtime`
- Udev rules for Instinct GPUs
- Path configuration via `ld.so.conf` and `profile.d`

### 🐳 AMD-Docker Wrapper

- Creates `/usr/local/bin/amd-docker`
- Automatically adds GPU devices and group permissions when using `docker run`
- Bash function replaces `docker run` with `amd-docker run`

---

## 🐳 Using the Wrapper

After reboot, you can use `docker run` as usual. The wrapper automatically ensures:

- Access to `/dev/kfd` and `/dev/dri`
- Group permissions for `video` and `render`
