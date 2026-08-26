# AryaLinux ports

Public ALPS port recipes for [AryaLinux](https://github.com/cksjava) (BLFS-derived).

- **1223** ports under `ports/`
- Index: [`index.json`](./index.json) (`alps-index-v1`)

## Use with ALPS

```bash
# /etc/alps/repos.conf
ALPS_REPO_GIT="https://github.com/cksjava/aryalinux-ports.git"
ALPS_REPO_BRANCH="main"

alps sync
alps search wget
alps install wget
```

HTTP index (optional): `https://raw.githubusercontent.com/cksjava/aryalinux-ports/main/index.json`

## Layout

```
index.json
ports/<name>/meta.yaml
ports/<name>/build.sh
…
```

Published by `./bin/aryalinux-upload-ports` from the AryaLinux builder.
