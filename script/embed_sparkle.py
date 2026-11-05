#!/usr/bin/env python3
"""Embed and sign the pinned SwiftPM Sparkle binary before signing the host app."""
import base64
import pathlib
import plistlib
import shutil
import subprocess
import sys
import urllib.parse

ROOT = pathlib.Path(__file__).resolve().parent.parent


def update_settings(path, required):
    settings = {
        'SUEnableAutomaticChecks': False,
        'SUAutomaticallyUpdate': False,
        'SUAllowsAutomaticUpdates': False,
        'SUEnableSystemProfiling': False,
    }
    if not path.exists() and not required:
        return settings
    with path.open('rb') as stream:
        config = plistlib.load(stream)
    if not isinstance(config, dict):
        raise ValueError('Updates.plist must contain a dictionary.')
    feed = config.get('SUFeedURL', '')
    if not isinstance(feed, str) or any(character.isspace() for character in feed):
        raise ValueError('SUFeedURL must be an HTTPS URL.')
    url = urllib.parse.urlsplit(feed)
    _ = url.port  # Reject malformed or out-of-range ports before distributing the app.
    if url.scheme != 'https' or not url.hostname or url.username or url.password or url.fragment:
        raise ValueError('SUFeedURL must be HTTPS, with a host and no credentials or fragment.')
    key = config.get('SUPublicEDKey', '')
    if not isinstance(key, str) or len(base64.b64decode(key, validate=True)) != 32:
        raise ValueError('SUPublicEDKey must be a base64-encoded 32-byte Ed25519 public key.')
    settings['SUEnableAutomaticChecks'] = True
    for name in settings:
        if name in config:
            if type(config[name]) is not bool:
                raise ValueError(f'{name} must be a boolean.')
            settings[name] = config[name]
    settings.update(SUFeedURL=feed, SUPublicEDKey=key)
    return settings


def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)


def embed(scratch, app, identity):
    settings = update_settings(ROOT / 'Config/Updates.plist', required=identity != '-')
    candidates = []
    for manifest in (scratch / 'artifacts').glob('**/Sparkle.xcframework/Info.plist'):
        with manifest.open('rb') as stream:
            libraries = plistlib.load(stream)['AvailableLibraries']
        for library in libraries:
            if (library['SupportedPlatform'] == 'macos'
                    and not library.get('SupportedPlatformVariant')
                    and {'arm64', 'x86_64'}.issubset(library['SupportedArchitectures'])):
                candidates.append(manifest.parent / library['LibraryIdentifier'] / library['LibraryPath'])
    if len(candidates) != 1:
        raise ValueError(f'Expected one universal Sparkle framework in {scratch}/artifacts, found {len(candidates)}.')

    framework = app / 'Contents/Frameworks/Sparkle.framework'
    framework.parent.mkdir(parents=True, exist_ok=True)
    run('/usr/bin/ditto', '--norsrc', '--noextattr', candidates[0], framework)
    licenses = [path / 'LICENSE' for path in (scratch / 'checkouts').iterdir()
                if path.name.lower() == 'sparkle' and (path / 'LICENSE').is_file()]
    if len(licenses) != 1:
        raise ValueError('The pinned Sparkle checkout license is missing.')
    resources = app / 'Contents/Resources'
    resources.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(licenses[0], resources / 'THIRD_PARTY_NOTICES.txt')

    info_path = app / 'Contents/Info.plist'
    with info_path.open('rb') as stream:
        info = plistlib.load(stream)
    info.update(settings)
    with info_path.open('wb') as stream:
        plistlib.dump(info, stream, sort_keys=False)

    # Sparkle's helpers need their own signatures; --deep signing loses their distinct entitlements.
    version = framework / 'Versions/B'
    targets = [
        (version / 'XPCServices/Installer.xpc', False),
        (version / 'XPCServices/Downloader.xpc', True),
        (version / 'Autoupdate', False),
        (version / 'Updater.app', False),
        (framework, False),
    ]
    for target, preserve_entitlements in targets:
        executable = target
        if target.suffix in ('.app', '.xpc'):
            with (target / 'Contents/Info.plist').open('rb') as stream:
                executable = target / 'Contents/MacOS' / plistlib.load(stream)['CFBundleExecutable']
        elif target.suffix == '.framework':
            executable = target / 'Versions/B/Sparkle'
        architectures = subprocess.check_output(['/usr/bin/lipo', '-archs', str(executable)], text=True).split()
        if not {'arm64', 'x86_64'}.issubset(architectures):
            raise ValueError(f'Sparkle component is not universal: {executable}')
        command = ['/usr/bin/codesign', '--force', '--sign', identity]
        if identity != '-':
            command += ['--options', 'runtime', '--timestamp']
        if preserve_entitlements:
            command += ['--preserve-metadata=entitlements']
        run(*command, target)


if __name__ == '__main__':
    try:
        if len(sys.argv) == 3 and sys.argv[1] == '--validate-config':
            update_settings(pathlib.Path(sys.argv[2]), required=True)
            print('Sparkle update configuration is valid.')
        elif len(sys.argv) == 4:
            embed(pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3])
        else:
            raise ValueError('Usage: embed_sparkle.py BUILD_ROOT APP SIGN_IDENTITY | --validate-config PLIST')
    except (OSError, ValueError, KeyError, plistlib.InvalidFileException, subprocess.CalledProcessError) as error:
        raise SystemExit(f'Sparkle packaging failed: {error}')
