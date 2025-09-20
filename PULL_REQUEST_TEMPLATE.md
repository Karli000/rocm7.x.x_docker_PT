# 🚀 Pull Request Template

## 📋 Description

Please describe your changes clearly and concisely. What problem does this solve? What feature does it add?

> Example:  
> This PR adds support for ROCm 7.x.x on Ubuntu 24.04 and updates the Docker wrapper to include `/dev/dri/renderD128`.

---

## ✅ Checklist

- [ ] I’ve tested this on a fresh Ubuntu 24.04 system
- [ ] The script runs without errors
- [ ] ROCm tools (`rocminfo`, `clinfo`) work inside the container
- [ ] Docker wrapper (`amd-docker`) behaves as expected
- [ ] I’ve updated the README if necessary
- [ ] My code follows the project’s formatting and shell best practices

---

## 🧪 How to Test

Provide instructions for testing your changes:

```bash
bash <(curl -s https://raw.githubusercontent.com/Karli000/rocm7.x.x_docker_PT/your-branch/rocm7.0.0_install.sh)

```bash
bash <(curl -s https://raw.githubusercontent.com/Karli000/rocm7.x.x_docker_PT/your-branch/rocm7.0.1_install.sh)

```bash
bash <(curl -s https://raw.githubusercontent.com/Karli000/rocm7.x.x_docker_PT/your-branch/docker_test.sh)
