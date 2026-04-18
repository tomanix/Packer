#!/usr/bin/env bash
# Renforcement CIS Level 2 — Rocky Linux 9
set -euo pipefail

echo "[02] Début du durcissement CIS Level 2..."

# ─── 1. Kernel sysctl ─────────────────────────────────────────────────────────
cat > /etc/sysctl.d/99-cis.conf << 'EOF'
# CIS 3.1 - Désactiver les protocoles réseau inutilisés
net.ipv4.ip_forward                 = 0
net.ipv4.conf.all.send_redirects    = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects  = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects  = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.log_martians      = 1
net.ipv4.conf.default.log_martians  = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.rp_filter         = 1
net.ipv4.conf.default.rp_filter     = 1
net.ipv4.tcp_syncookies             = 1
net.ipv6.conf.all.accept_ra         = 0
net.ipv6.conf.default.accept_ra     = 0
net.ipv6.conf.all.disable_ipv6      = 1
net.ipv6.conf.default.disable_ipv6  = 1

# CIS 1.5 - Protections mémoire
kernel.randomize_va_space           = 2
fs.suid_dumpable                    = 0
kernel.core_uses_pid                = 1

# CIS 4.1 - Audit
kernel.dmesg_restrict               = 1
EOF

sysctl --system > /dev/null

# ─── 2. Modules noyau interdits (CIS 3.4 & 1.1) ───────────────────────────────
BLACKLIST=/etc/modprobe.d/cis-blacklist.conf
cat > "${BLACKLIST}" << 'EOF'
# Systèmes de fichiers inutilisés
install cramfs    /bin/false
install freevxfs  /bin/false
install jffs2     /bin/false
install hfs       /bin/false
install hfsplus   /bin/false
install squashfs  /bin/false
install udf       /bin/false

# Protocoles réseau
install dccp      /bin/false
install sctp      /bin/false
install rds       /bin/false
install tipc      /bin/false

# USB
install usb-storage /bin/false
EOF

# ─── 3. Auditd ────────────────────────────────────────────────────────────────
cat > /etc/audit/rules.d/99-cis.rules << 'EOF'
## CIS Level 2 — Règles d'audit
-D
-b 8192
-f 2

# Modifications des permissions
-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S chown,fchown,fchownat,lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod

# Accès aux fichiers non autorisés
-a always,exit -F arch=b64 -S open,truncate,ftruncate,creat,openat -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b64 -S open,truncate,ftruncate,creat,openat -F exit=-EPERM  -F auid>=1000 -F auid!=4294967295 -k access

# Montages
-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts

# Suppressions de fichiers
-a always,exit -F arch=b64 -S unlink,unlinkat,rename,renameat -F auid>=1000 -F auid!=4294967295 -k delete

# Changements sudo/su
-w /etc/sudoers      -p wa -k scope
-w /etc/sudoers.d/   -p wa -k scope

# Connexions
-w /var/log/lastlog  -p wa -k logins
-w /var/run/faillock -p wa -k logins

# Changements système
-w /etc/passwd   -p wa -k identity
-w /etc/group    -p wa -k identity
-w /etc/shadow   -p wa -k identity
-w /etc/gshadow  -p wa -k identity

# Appels d'administration
-a always,exit -F arch=b64 -S sethostname,setdomainname -k system-locale
-w /etc/issue    -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts    -p wa -k system-locale

# Immuable
-e 2
EOF

systemctl enable auditd

# ─── 4. PAM — politique de mots de passe ──────────────────────────────────────
# Historique des mots de passe
sed -i '/^password.*pam_unix/ s/$/ remember=5/' /etc/pam.d/system-auth
sed -i '/^password.*pam_unix/ s/$/ remember=5/' /etc/pam.d/password-auth

# Verrouillage après 5 tentatives
cat > /etc/security/faillock.conf << 'EOF'
deny = 5
unlock_time = 900
even_deny_root
root_unlock_time = 60
EOF

# ─── 5. SSH durci ─────────────────────────────────────────────────────────────
# Supprimer le fichier temporaire Packer (PasswordAuthentication yes)
rm -f /etc/ssh/sshd_config.d/01-packer-temp.conf

cat >> /etc/ssh/sshd_config << 'EOF'

# ── Durcissement CIS ──
Protocol 2
LogLevel VERBOSE
MaxAuthTries 4
IgnoreRhosts yes
HostbasedAuthentication no
PermitEmptyPasswords no
PermitUserEnvironment no
Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group14-sha256,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
ClientAliveInterval 300
ClientAliveCountMax 3
LoginGraceTime 60
Banner /etc/issue.net
AllowTcpForwarding no
X11Forwarding no
EOF

# Bannière de connexion
cat > /etc/issue.net << 'EOF'
*******************************************************************************
                              ACCÈS RESTREINT
  Ce système est réservé aux utilisateurs autorisés. Toute tentative d'accès
  non autorisé sera enregistrée et peut faire l'objet de poursuites.
*******************************************************************************
EOF

# ─── 6. Cron ──────────────────────────────────────────────────────────────────
chmod og-rwx /etc/crontab
chmod og-rwx /etc/cron.hourly
chmod og-rwx /etc/cron.daily
chmod og-rwx /etc/cron.weekly
chmod og-rwx /etc/cron.monthly
chmod og-rwx /etc/cron.d

# ─── 7. Désactiver services inutiles ──────────────────────────────────────────
SERVICES_TO_DISABLE=(
  avahi-daemon
  cups
  dhcpd
  slapd
  nfs
  rpcbind
  named
  vsftpd
  httpd
  dovecot
  smb
  squid
  snmpd
  ypserv
  rsh.socket
  rlogin.socket
  rexec.socket
  telnet.socket
  tftp
  xinetd
)

for svc in "${SERVICES_TO_DISABLE[@]}"; do
  systemctl disable --now "${svc}" 2>/dev/null || true
done

# ─── 8. Firewalld ─────────────────────────────────────────────────────────────
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --set-default-zone=drop
firewall-cmd --permanent --add-service=ssh
firewall-cmd --reload

echo "[02] Durcissement CIS Level 2 terminé."
