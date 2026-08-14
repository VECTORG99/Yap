# AppArmor profile for Yap — ChincoLinux local AI assistant
# Confines yap.py to minimal permissions:
#   - Read: /etc/yap/ (whitelists, cursos, pseint)
#   - Write: ~/.config/yap/ (progress, history, confirmations)
#   - Execute: llama-cli, xdg-open, notify-send (via subprocess)
#   - Network: required for webfetch (Wikipedia API) and llama-cli
#
# Install: sudo cp usr.local.bin.yap /etc/apparmor.d/
#          sudo apparmor_parser -r /etc/apparmor.d/usr.local.bin.yap
# Status:  aa-status | grep yap
# Logs:    journalctl -k | grep apparmor | grep yap

#include <tunables/global>

profile yap /usr/local/bin/yap {
  #include <abstractions/base>
  #include <abstractions/python>

  # Read access to Yap configuration
  /etc/yap/ r,
  /etc/yap/** r,

  # Read access to model files
  /opt/yap/ r,
  /opt/yap/** r,

  # Write access to user config (progress, history, confirmations)
  owner @{HOME}/.config/yap/ rw,
  owner @{HOME}/.config/yap/** rw,
  owner @{HOME}/.config/yap/*.tmp rw,

  # Read access to home (for readline history)
  owner @{HOME}/.config/yap/history.txt rw,

  # Execute llama-cli for LLM inference
  /usr/bin/llama-cli rix,
  /usr/local/bin/llama-cli rix,

  # Execute xdg-open for PDFs
  /usr/bin/xdg-open rix,

  # Execute notify-send for notifications
  /usr/bin/notify-send rix,

  # Execute whitelisted applications (subprocess.Popen)
  /usr/bin/firefox* rix,
  /usr/bin/firefox-esr rix,
  /usr/bin/libreoffice* rix,
  /usr/bin/pseint rix,
  /usr/bin/code rix,
  /usr/bin/gedit rix,
  /usr/bin/evince rix,
  /usr/bin/okular rix,
  /usr/bin/xdg-open rix,

  # Network access for webfetch (Wikipedia API) and llama-cli
  network inet stream,
  network inet6 stream,

  # System info for terminal size
  /proc/sys/kernel/osrelease r,
  sys kernel.osrelease r,

  # Python interpreter
  /usr/bin/python3 rix,
  /usr/bin/python3.* rix,

  # Python standard library
  /usr/lib/python3*/** r,
  /usr/lib/python3*/site-packages/** r,
  /usr/local/lib/python3*/** r,
  /usr/local/lib/python3*/dist-packages/** r,

  # Temp files
  /tmp/ rw,
  /tmp/** rw,

  # Deny everything else by default (AppArmor default-deny)
}
