#!/usr/bin/env python3
"""Configure PVE repositories without changing Debian or unrelated repositories."""
import re
import shutil
import sys
from pathlib import Path


def rewrite(text, deb822=False):
    if not deb822:
        lines = []
        for line in text.splitlines(keepends=True):
            if re.match(r'^\s*deb(?:-src)?\s', line) and re.search(
                r'https?://(?:enterprise|download)\.proxmox\.com/debian/', line
            ):
                if re.search(r'\bpve-(?:enterprise|no-subscription)\b', line):
                    line = '# pvepostinstall disabled: ' + line
                elif 'enterprise.proxmox.com/debian/ceph-' in line:
                    line = line.replace('enterprise.proxmox.com', 'download.proxmox.com')
                    line = re.sub(r'\benterprise\b', 'no-subscription', line)
            lines.append(line)
        return ''.join(lines)
    paragraphs = re.split(r'(\n\s*\n)', text)
    for i in range(0, len(paragraphs), 2):
        block = paragraphs[i]
        fields = {}
        key = None
        for line in block.splitlines():
            if line.startswith('#'):
                continue
            if line[:1].isspace() and key:
                fields[key] += ' ' + line.strip()
            elif ':' in line:
                key, value = line.split(':', 1)
                key = key.lower()
                fields[key] = value.strip()
        uris = fields.get('uris', '').split()
        components = fields.get('components', '').split()
        pve = any(re.match(r'https?://(?:enterprise|download)\.proxmox\.com/debian/pve/?$', u) for u in uris)
        ceph = any(re.match(r'https?://enterprise\.proxmox\.com/debian/ceph-[\w-]+/?$', u) for u in uris)
        if not (pve or ceph):
            continue
        # Mixed stanzas cannot safely be edited as one unit.
        if len(uris) != 1 or len(components) != 1:
            raise ValueError('Split mixed Proxmox repository stanzas before running setup')
        if pve and components[0] in ('pve-enterprise', 'pve-no-subscription'):
            block = re.sub(r'^Enabled:.*(?:\n[ \t]+[^\n]*)*', '', block, flags=re.M | re.I)
            block = block.rstrip() + '\nEnabled: no\n'
        elif ceph and components[0] == 'enterprise':
            block = block.replace('enterprise.proxmox.com', 'download.proxmox.com')
            block = re.sub(r'^(Components:)[^\n]*(?:\n[ \t]+[^\n]*)*', r'\1 no-subscription', block, flags=re.M | re.I)
        paragraphs[i] = block
    return ''.join(paragraphs)


def configure(root, codename):
    if codename not in ('bookworm', 'trixie'):
        raise ValueError('Unsupported Debian release')
    directory = root / 'etc/apt/sources.list.d'
    directory.mkdir(parents=True, exist_ok=True)
    managed = directory / 'pvepostinstall.sources'
    files = [root / 'etc/apt/sources.list', *sorted(directory.glob('*.list')), *sorted(directory.glob('*.sources'))]
    # Validate every transformation before modifying any sources.
    changes = [(p, rewrite(p.read_text(), p.suffix == '.sources')) for p in files if p.exists() and p != managed]
    signing = ''
    if codename == 'trixie':
        key = '/usr/share/keyrings/proxmox-archive-keyring.gpg'
        if not (root / key.lstrip('/')).is_file():
            raise ValueError('Proxmox archive keyring is missing')
        signing = f'Signed-By: {key}\n'
    for path, content in changes:
        if path.read_text() != content:
            backup = path.with_name(path.name + '.pvepostinstall.bak')
            if not backup.exists():
                shutil.copy2(path, backup)
            path.write_text(content)
    managed.write_text(f'Types: deb\nURIs: http://download.proxmox.com/debian/pve\nSuites: {codename}\nComponents: pve-no-subscription\n{signing}')


if __name__ == '__main__':
    configure(Path('/'), sys.argv[1])
