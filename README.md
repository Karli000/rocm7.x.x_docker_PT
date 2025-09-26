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
```bash
#rocm7.0.1
bash <(curl -s https://raw.githubusercontent.com/Karli000/rocm7.x.x_docker_PT/main/rocm7.0.1_install.sh)
```
```bash
#AMD-GPU-FAN
bash <(https://raw.githubusercontent.com/Karli000/rocm7.x.x_docker_PT/main/setup_gpu_fan.sh)
```
```
#test
ls -l /dev/kfd && ls -l /dev/dri && rocminfo && clinfo
```
```bash
#docker_wrapper
bash <(curl -s https://raw.githubusercontent.com/Karli000/rocm7.x.x_docker_PT/main/docker_wrapper.sh)
```

```bash
#rocm7.0.0
bash <(curl -s https://raw.githubusercontent.com/Karli000/rocm7.x.x_docker_PT/main/rocm7.0.0_install.sh)
```

```bash
#mirror-master
bash <(curl -s https://raw.githubusercontent.com/Karli000/rocm7.x.x_docker_PT/main/mirror-master.sh)
```
```bash
#mirror-host
bash <(curl -s https://raw.githubusercontent.com/Karli000/rocm7.x.x_docker_PT/main/mirror-host.sh)
```
