#!/usr/bin/env bash
set -euo pipefail
: "${ALPS_SOURCES:?}" "${ALPS_WORK:?}"
export ALPS_JOBS="${ALPS_JOBS:-$(nproc)}"
export MAKEFLAGS="-j$ALPS_JOBS"
export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-$ALPS_JOBS}"
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-$ALPS_JOBS}"
export SCONSFLAGS="${SCONSFLAGS:--j$ALPS_JOBS}"
# Ninja/meson ignore MAKEFLAGS — wrap so bare invocations use all cores.
ninja -j "$ALPS_JOBS"() {
  local _a _has_j=0
  for _a in "$@"; do
    case "$_a" in -j|-j*) _has_j=1; break ;; esac
  done
  if ((_has_j)); then command ninja "$@"
  else command ninja -j "$ALPS_JOBS" "$@"
  fi
}
samu -j "$ALPS_JOBS"() {
  local _a _has_j=0
  for _a in "$@"; do
    case "$_a" in -j|-j*) _has_j=1; break ;; esac
  done
  if ((_has_j)); then command samu "$@"
  else command samu -j "$ALPS_JOBS" "$@"
  fi
}
meson() {
  if [[ "${1:-}" == "compile" ]]; then
    shift
    local _a _has_j=0
    for _a in "$@"; do
      case "$_a" in -j|-j*) _has_j=1; break ;; esac
    done
    if ((_has_j)); then command meson compile "$@"
    else command meson compile -j "$ALPS_JOBS" "$@"
    fi
  else
    command meson "$@"
  fi
}
# config / no-tarball port — book commands only
# --- commands from BLFS ---
mkdir -pv ~/.config/fontconfig
cat > ~/.config/fontconfig/fonts.conf << "EOF"
<?xml version='1.0'?>
<!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
<fontconfig>
  <match target="font" >
    <!-- autohint was the old automatic hinter when hinting was patent
    protected, so turn it off to ensure any hinting information in the font
    itself is used, this is the default -->
    <edit mode="assign" name="autohint">  <bool>false</bool></edit>
    <!-- hinting is enabled by default -->
    <edit mode="assign" name="hinting">   <bool>true</bool></edit>
    <!-- for the lcdfilter see https://www.spasche.net/files/lcdfiltering/ -->
    <edit mode="assign" name="lcdfilter"> <const>lcddefault</const></edit>
    <!-- options for hintstyle:
    hintfull: is supposed to give a crisp font that aligns well to the
    character-cell grid but at the cost of its proper shape. However, anything
    using Pango >= 1.44 will not support full hinting, Pango now uses harfbuzz
    for hinting. Apps which use Skia (e.g. Chromium, Firefox) should not be
    affected by this.
    hintmedium: is reported to be broken.
    hintslight is the default: - supposed to be more fuzzy but retains shape.
    hintnone: seems to turn hinting off.
    The variations are marginal and results vary with different fonts -->
    <edit mode="assign" name="hintstyle"> <const>hintslight</const></edit>
    <!-- antialiasing is on by default and really helps for faint characters
    and also for 'xft:' fonts used in rxvt-unicode -->
    <edit mode="assign" name="antialias"> <bool>true</bool></edit>
    <!-- subpixels are usually rgb, see
    http://www.lagom.nl/lcd-test/subpixel.php -->
    <edit mode="assign" name="rgba">      <const>rgb</const></edit>
    <!-- thanks to the Arch wiki for the lcd and subpixel links -->
  </match>
</fontconfig>
EOF
cat > /etc/fonts/conf.d/70-no-bitmaps.conf << "EOF"
<?xml version='1.0'?>
<!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
<fontconfig>
<!-- Reject bitmap fonts -->
 <selectfont>
  <rejectfont>
   <pattern>
     <patelt name="scalable"><bool>false</bool></patelt>
   </pattern>
  </rejectfont>
 </selectfont>
</fontconfig>
EOF
cat > /etc/fonts/conf.d/09-texlive.conf << "EOF"
<?xml version='1.0'?>
<!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
<fontconfig>
  <dir>/opt/texlive/2025/texmf-dist/fonts/opentype/arkandis/berenisadf</dir>
  <dir>/opt/texlive/2025/texmf-dist/fonts/truetype/paratype</dir>
</fontconfig>
EOF
mkdir -pv ~/.config/fontconfig/conf.d
cat >  ~/.config/fontconfig/conf.d/35-prefer-nimbus-for-timesnew.conf << "EOF"
<?xml version='1.0'?>
<!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
<fontconfig>
<!-- prefer Nimbus Roman No9 L for Times New Roman as well as for Times,
 without this Tinos and Liberation Serif take precedence for Times New Roman
 before Fontconfig falls back to whatever matches Times -->
    <alias binding="same">
        <family>Times New Roman</family>
        <accept>
            <family>Nimbus Roman No9 L</family>
        </accept>
    </alias>
</fontconfig>
EOF
cat > /etc/fonts/local.conf << "EOF"
<?xml version='1.0'?>
<!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
<fontconfig>
    <alias>
        <family>serif</family>
        <prefer>
            <family>DejaVu Serif</family>
            <family>IPAexMincho</family>
            <!-- WenQuanYi is preferred as Serif in 65-nonlatin.conf,
            override that so a real Korean font can be used for Serif -->
            <family>UnBatang</family>
        </prefer>
    </alias>
    <alias>
         <family>sans-serif</family>
         <prefer>
             <family>DejaVu Sans</family>
             <family>VL Gothic</family>
         <!-- This assumes WenQuanYi is good enough for Korean Sans -->
         </prefer>
    </alias>
    <alias>
         <family>monospace</family>
         <prefer>
             <family>DejaVu Sans Mono</family>
             <family>VL Gothic</family>
         <!-- This assumes WenQuanYi is good enough for Korean Monospace -->
         </prefer>
    </alias>
</fontconfig>
EOF
<match target="pattern">
       <test qual="any" name="lang" compare="contains">
           <string>zh-cn</string>
           <string>zh-sg</string>
       </test>
       <test qual="any" name="family">
           <string>serif</string>
       </test>
       <edit name="family" mode="prepend" binding="strong">
           <string>AR PL UMing CN</string>
       </edit>
   </match>
<match target="pattern">
       <test qual="any" name="lang" compare="contains">
           <string>zh-cn</string>
       </test>
       <test qual="any" name="family">
           <string>serif</string>
       </test>
       <edit name="family" mode="prepend" binding="strong">
           <string>AR PL UMing CN</string>
       </edit>
    </match>
   <match target="pattern">
       <test qual="any" name="lang" compare="contains">
           <string>zh-sg</string>
       </test>
       <test qual="any" name="family">
           <string>serif</string>
       </test>
       <edit name="family" mode="prepend" binding="strong">
           <string>AR PL UMing CN</string>
       </edit>
    </match>
