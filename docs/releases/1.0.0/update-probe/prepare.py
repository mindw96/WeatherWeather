#!/usr/bin/env python3
"""Compile isolated Sparkle hosts without querying the feed or changing product settings."""
import base64
import hashlib
import json
from pathlib import Path
import plistlib
import shlex
import shutil
import subprocess
import tempfile
import uuid

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
FRAMEWORK = Path('/Users/mindw/Applications/WindowWeather.app/Contents/Frameworks/Sparkle.framework')
FEED = 'https://github.com/mindw96/WeatherWeather/releases/latest/download/appcast.xml'
DOWNLOAD = 'https://github.com/mindw96/WeatherWeather/releases/download/v1.0.0/WindowWeather-1.0.0-update.zip'


def run(*arguments):
    subprocess.run([str(argument) for argument in arguments], check=True)


def prepare():
    with (FRAMEWORK / 'Resources/Info.plist').open('rb') as stream:
        framework_version = plistlib.load(stream)['CFBundleShortVersionString']
    if framework_version != '2.10.1':
        raise ValueError(f'Expected existing Sparkle 2.10.1, found {framework_version}')
    with (ROOT / 'Config/Updates.plist').open('rb') as stream:
        config = plistlib.load(stream)
    if config['SUFeedURL'] != FEED or len(base64.b64decode(config['SUPublicEDKey'], validate=True)) != 32:
        raise ValueError('Unexpected product update feed or public key')

    scratch = Path(tempfile.mkdtemp(prefix='window-weather-100-sparkle-probe.', dir='/private/tmp'))
    frameworks = scratch / 'Frameworks'
    frameworks.mkdir()
    run('/usr/bin/ditto', '--norsrc', '--noextattr', FRAMEWORK, frameworks / 'Sparkle.framework')
    compile_command = [
        '/usr/bin/xcrun', 'swiftc', '-swift-version', '5', '-O',
        '-target', 'arm64-apple-macos14.0', '-module-cache-path', str(scratch / 'ModuleCache'),
        '-F', str(frameworks), '-framework', 'AppKit', '-framework', 'Sparkle',
        '-Xlinker', '-rpath', '-Xlinker', '@executable_path/../Frameworks',
        str(HERE / 'main.swift'), '-o', str(scratch / 'SparkleProbe'),
    ]
    run(*compile_command)
    hosts = []
    for version, build, expected in [('0.8.0', '14', 'available'), ('1.0.0', '15', 'current')]:
        app = scratch / f'Build{build}.app'
        contents = app / 'Contents'
        (contents / 'MacOS').mkdir(parents=True)
        shutil.copy2(scratch / 'SparkleProbe', contents / 'MacOS/SparkleProbe')
        framework = contents / 'Frameworks/Sparkle.framework'
        run('/usr/bin/ditto', '--norsrc', '--noextattr', frameworks / 'Sparkle.framework', framework)
        identifier = f'org.windowweather.sparkle-probe.v100.build{build}.{uuid.uuid4().hex}'
        info = {
            'CFBundleIdentifier': identifier,
            'CFBundleName': 'WindowWeather Sparkle Probe 1.0.0',
            'CFBundleExecutable': 'SparkleProbe', 'CFBundlePackageType': 'APPL',
            'CFBundleVersion': build, 'CFBundleShortVersionString': version,
            'LSMinimumSystemVersion': '14.0', 'LSUIElement': True,
            'SUFeedURL': FEED, 'SUPublicEDKey': config['SUPublicEDKey'],
            'SUEnableAutomaticChecks': False, 'SUAutomaticallyUpdate': False,
            'SUAllowsAutomaticUpdates': False, 'SUEnableSystemProfiling': False,
        }
        with (contents / 'Info.plist').open('wb') as stream:
            plistlib.dump(info, stream)

        # Sign inside out; preserve Sparkle Downloader's sandbox entitlements.
        framework_version_path = framework / 'Versions/B'
        for relative in ['XPCServices/Installer.xpc', 'XPCServices/Downloader.xpc', 'Autoupdate', 'Updater.app']:
            command = ['/usr/bin/codesign', '--force', '--sign', '-']
            if relative == 'XPCServices/Downloader.xpc':
                command += ['--preserve-metadata=entitlements']
            run(*command, framework_version_path / relative)
        run('/usr/bin/codesign', '--force', '--sign', '-', framework)
        run('/usr/bin/codesign', '--force', '--sign', '-', app)
        verify_command = ['/usr/bin/codesign', '--verify', '--deep', '--strict', str(app)]
        run(*verify_command)
        report = HERE / f'{expected}.json'
        run_command = ['/usr/bin/open', '-n', '-W', str(app), '--args', str(report), expected]
        hosts.append({
            'app': str(app), 'hostVersion': version, 'hostBuild': build,
            'bundleIdentifier': identifier, 'expected': expected, 'report': str(report),
            'verifyCommand': verify_command, 'signatureVerified': True, 'runCommand': run_command,
        })

    metadata = {
        'status': 'prepared-not-executed', 'frameworkVersion': framework_version,
        'frameworkSource': str(FRAMEWORK), 'architecture': 'arm64', 'minimumOS': '14.0',
        'expectedVersion': '1.0.0', 'expectedBuild': '15', 'expectedDownloadURL': DOWNLOAD,
        'feedURL': FEED, 'compileCommand': compile_command, 'hosts': hosts,
        'probeSourceSHA256': hashlib.sha256((HERE / 'main.swift').read_bytes()).hexdigest(),
        'scope': 'Compiled and ad-hoc signature verified. Feed queries have not run. Run only after v1.0.0 publication. No product keys, preferences or caches modified.',
    }
    (HERE / 'prepared-hosts.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print('Prepared only. After v1.0.0 is publicly available, run:')
    for host in hosts:
        print(shlex.join(host['runCommand']))


if __name__ == '__main__':
    prepare()
