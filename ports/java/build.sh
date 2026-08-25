#!/usr/bin/env bash
set -euo pipefail
: "${ALPS_SOURCES:?}" "${ALPS_WORK:?}"
export ALPS_JOBS="${ALPS_JOBS:-$(nproc)}"
export MAKEFLAGS="-j$ALPS_JOBS"

# config / no-tarball port — book commands only

# --- commands from BLFS ---
public class HelloWorld
{
    public static void main(String[] args)
    {
        System.out.println("Hello, World");
    }
}

install -vdm755 /opt/OpenJDK-21.0.10-bin
mv -v * /opt/OpenJDK-21.0.10-bin
chown -R root:root /opt/OpenJDK-21.0.10-bin

ln -sfn OpenJDK-21.0.10-bin /opt/jdk
