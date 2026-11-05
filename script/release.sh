#!/usr/bin/env bash
set -euo pipefail

# WindowWeather's owner authorized signing and Apple notarization of future
# updates on 2026-11-05. This script uploads this app's archive only. Credentials
# stay in the macOS keychain; publication to a hosting service is separate.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec /usr/bin/python3 - "$ROOT_DIR" "$@" <<'PY'
import hashlib
import json
import os
import pathlib
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET

root = pathlib.Path(sys.argv[1])
arguments = sys.argv[2:]
if arguments not in ([], ['--resume']):
    raise SystemExit('Usage: script/release.sh [--resume]')
resume = bool(arguments)
environment = dict(os.environ)
environment.setdefault('WEATHER_SIGN_IDENTITY', 'Developer ID Application: Dongwook Min (4J7HGK26PF)')
profile = environment.get('WEATHER_NOTARY_PROFILE', 'DdayNotary')
timeout = int(environment.get('WEATHER_NOTARY_TIMEOUT_SECONDS', '1200'))
if timeout < 30:
    raise SystemExit('WEATHER_NOTARY_TIMEOUT_SECONDS must be at least 30.')

def run(*args, capture=False, check=True):
    result = subprocess.run([str(arg) for arg in args], cwd=root, env=environment,
                            text=True, stdout=subprocess.PIPE if capture else None,
                            stderr=subprocess.STDOUT if capture else None, check=False)
    if check and result.returncode:
        if capture:
            print(result.stdout, file=sys.stderr)
        raise RuntimeError(f'Command failed ({result.returncode}): {args[0]}')
    return result.stdout if capture else result.returncode

def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(chunk)
    return value.hexdigest()

def write_json(path, value):
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)

def notary_json(command, *args):
    # Warnings are printed on stderr by notarytool, leaving stdout valid JSON.
    result = subprocess.run(['xcrun', 'notarytool', command, *map(str, args),
                             '--keychain-profile', profile, '--output-format', 'json'],
                            cwd=root, env=environment, text=True, stdout=subprocess.PIPE,
                            check=True)
    return json.loads(result.stdout)

def validate_appcast(path, update_zip, bundle, download_prefix):
    namespace = '{http://www.andymatuschak.org/xml-namespaces/sparkle}'
    items = ET.parse(path).getroot().findall('channel/item')
    if len(items) != 1:
        raise RuntimeError('Expected exactly one release in the generated appcast.')
    item = items[0]
    enclosure = item.find('enclosure')
    if (item.findtext(namespace + 'version') != bundle['CFBundleVersion']
            or item.findtext(namespace + 'shortVersionString') != bundle['CFBundleShortVersionString']
            or enclosure is None
            or enclosure.get('url') != download_prefix + update_zip.name
            or enclosure.get('length') != str(update_zip.stat().st_size)
            or not enclosure.get(namespace + 'edSignature')):
        raise RuntimeError('Generated appcast version, archive, length, or signature is inconsistent.')
    return enclosure.get(namespace + 'edSignature')

version = run('/bin/bash', root / 'script/package_share.sh', '--print-version', capture=True).strip()
output = root / 'dist/releases' / version
evidence = root / 'docs/releases' / version
output.mkdir(parents=True, exist_ok=True)
evidence.mkdir(parents=True, exist_ok=True)
state_path = output / 'release-state.json'
lock = output / '.release-lock'
try:
    lock.mkdir()
except FileExistsError:
    raise SystemExit(f'Release already running, or stale lock after interruption: {lock}')

try:
    if resume:
        if not state_path.exists():
            raise RuntimeError('No release state found. Run script/release.sh first.')
        state = json.loads(state_path.read_text())
    else:
        if state_path.exists():
            raise RuntimeError('A release already exists for this version. Use --resume or increment the version.')
        run('/bin/bash', root / 'script/package_share.sh')
        state = json.loads((output / 'package-state.json').read_text())
        package = pathlib.Path(state['package_dir'])
        archive = pathlib.Path(state['zip_path'])
        # Keep exactly the uploaded bytes for a resumable request. Only place a
        # finished archive at the public output path after all checks pass.
        upload_dir = pathlib.Path(state['stage_root']) / 'notarization-input'
        upload_dir.mkdir()
        upload = upload_dir / archive.name
        shutil.copyfile(archive, upload)
        archive.unlink()
        state.update(version=version, upload_path=str(upload), upload_sha256=digest(upload),
                     submission_id=None, submission_attempted=False, phase='signed')
        write_json(state_path, state)

    if state['version'] != version:
        raise RuntimeError('Release state does not match the current package version.')
    upload = pathlib.Path(state['upload_path'])
    package = pathlib.Path(state['package_dir'])
    app = pathlib.Path(state['app_bundle'])
    archive = pathlib.Path(state['zip_path'])
    if state.get('phase') == 'complete':
        for name, expected in state.get('artifact_sha256', {archive.name: state.get('final_sha256')}).items():
            artifact = output / name
            if not artifact.is_file() or digest(artifact) != expected:
                raise RuntimeError(f'Completed release artifact is missing or changed: {name}')
        print(f'Already complete: {archive}', flush=True)
        sys.exit(0)
    if not upload.is_file() or digest(upload) != state['upload_sha256']:
        raise RuntimeError('The original notarization upload is missing or changed. Do not resubmit altered bytes.')
    if not app.is_dir():
        raise RuntimeError('Staged app is missing. Preserve /private/tmp staging until the release finishes.')

    if not state.get('submission_id'):
        saved_submission = output / 'notary-submission.json'
        if state.get('submission_attempted') and saved_submission.exists():
            state['submission_id'] = json.loads(saved_submission.read_text())['id']
            write_json(state_path, state)
    if not state.get('submission_id'):
        if state.get('submission_attempted'):
            raise RuntimeError('An upload was attempted without a saved ID. Inspect notarytool history and recover its ID; do not submit again automatically.')
        state['submission_attempted'] = True
        write_json(state_path, state)
        print('Submitting signed archive to Apple notarization…', flush=True)
        submitted = notary_json('submit', upload, '--no-wait')
        write_json(output / 'notary-submission.json', submitted)
        state['submission_id'] = submitted['id']
        state['phase'] = 'submitted'
        write_json(state_path, state)

    submission = state['submission_id']
    print(f'Notarization submission: {submission}', flush=True)
    deadline = time.monotonic() + timeout
    while True:
        info = notary_json('info', submission)
        write_json(output / 'notary-status.json', info)
        status = info['status']
        print(f'Apple notarization: {status}', flush=True)
        if status == 'Accepted':
            write_json(evidence / 'notarization.json', info)
            break
        if status != 'In Progress':
            run('xcrun', 'notarytool', 'log', submission, evidence / 'notarization-log.json',
                '--keychain-profile', profile, check=False)
            raise RuntimeError(f'Apple notarization was not accepted: {status}')
        if time.monotonic() >= deadline:
            raise RuntimeError('Notarization is still pending. Resume with script/release.sh --resume; no second upload is needed.')
        # Timeout is normal here. The following info call is authoritative.
        run('xcrun', 'notarytool', 'wait', submission, '--keychain-profile', profile,
            '--timeout', '30s', '--output-format', 'json', capture=True, check=False)

    run('xcrun', 'stapler', 'staple', app)
    run('xcrun', 'stapler', 'validate', app)
    run('/usr/bin/codesign', '--verify', '--deep', '--strict', '--verbose=2', app)
    run('/usr/sbin/spctl', '--assess', '--type', 'execute', '--verbose=2', app)
    # These files are outside the signed app. Never rebuild or re-sign the
    # executable after notarization; only the ticket and packaging change.
    for name in ('START_HERE.ko.txt', 'RELEASE_NOTES.ko.md'):
        source = (evidence / name).read_text()
        text, count = re.subn(r'^배포 상태:.*$', '배포 상태: Developer ID 서명과 Apple 공증을 완료했습니다.',
                              source, flags=re.MULTILINE)
        if count != 1:
            raise RuntimeError(f'{name}: expected exactly one 배포 상태: line')
        (package / name).write_text(text)

    with tempfile.TemporaryDirectory(prefix='window-weather-release-verify.', dir='/private/tmp') as temporary:
        check_dir = pathlib.Path(temporary)
        final_zip = check_dir / archive.name
        run('/usr/bin/ditto', '-c', '-k', '--keepParent', '--norsrc', '--noextattr', package, final_zip)
        run('/usr/bin/ditto', '-x', '-k', final_zip, check_dir / 'unpacked')
        final_app = check_dir / 'unpacked' / package.name / app.name
        commands = [
            ['/usr/bin/codesign', '--verify', '--deep', '--strict', '--verbose=2', final_app],
            ['/usr/bin/codesign', '-dvvv', final_app],
            ['/usr/bin/plutil', '-lint', final_app / 'Contents/Info.plist'],
            ['xcrun', 'stapler', 'validate', final_app],
            ['/usr/sbin/spctl', '--assess', '--type', 'execute', '--verbose=2', final_app],
            ['/usr/bin/unzip', '-t', final_zip],
        ]
        results = []
        for command in commands:
            results.append('$ ' + ' '.join(map(str, command)) + '\n' + run(*command, capture=True))
        architectures = run('/usr/bin/lipo', '-archs', final_app / 'Contents/MacOS/WindowWeather', capture=True).strip()
        if not {'arm64', 'x86_64'}.issubset(set(architectures.split())):
            raise RuntimeError(f'Expected a universal app, got: {architectures}')
        results.append('Architectures: ' + architectures + '\n')

        with (root / 'Config/Updates.plist').open('rb') as stream:
            config = plistlib.load(stream)
        with (final_app / 'Contents/Info.plist').open('rb') as stream:
            bundle = plistlib.load(stream)
        if (bundle['CFBundleShortVersionString'] != version
                or any(bundle.get(key) != config[key] for key in ('SUFeedURL', 'SUPublicEDKey'))):
            raise RuntimeError('The notarized app version or updater settings differ from release configuration.')
        scratch = pathlib.Path(environment.get('WEATHER_SHARE_BUILD_ROOT', '/private/tmp/window-weather-share-universal'))
        generators = list((scratch / 'artifacts').glob('**/bin/generate_appcast'))
        if len(generators) != 1:
            raise RuntimeError('Expected one pinned Sparkle generate_appcast tool in the release build artifacts.')
        tools = generators[0].parent
        account = 'org.windowweather.app'
        public_key = run(tools / 'generate_keys', '--account', account, '-p', capture=True).strip()
        if public_key != config['SUPublicEDKey']:
            raise RuntimeError('The Sparkle signing account does not match the app public key.')

        updates = check_dir / 'sparkle'
        updates.mkdir()
        update_zip = updates / f'WindowWeather-{version}-update.zip'
        appcast = updates / 'appcast.xml'
        download_prefix = f'https://github.com/mindw96/WeatherWeather/releases/download/v{version}/'
        run('/usr/bin/ditto', '-c', '-k', '--keepParent', '--norsrc', '--noextattr', final_app, update_zip)
        run(generators[0], '--account', account, '--download-url-prefix', download_prefix,
            '--maximum-deltas', '0', '-o', appcast, updates)
        signature = validate_appcast(appcast, update_zip, bundle, download_prefix)
        results.append(run(tools / 'sign_update', '--account', account, '--verify', update_zip, signature, capture=True))
        run('/usr/bin/ditto', '-x', '-k', update_zip, check_dir / 'unpacked-update')
        updated_app = check_dir / 'unpacked-update' / app.name
        for command in (
            ['/usr/bin/codesign', '--verify', '--deep', '--strict', '--verbose=2', updated_app],
            ['xcrun', 'stapler', 'validate', updated_app],
            ['/usr/sbin/spctl', '--assess', '--type', 'execute', '--verbose=2', updated_app],
            ['/usr/bin/unzip', '-t', update_zip],
        ):
            results.append('$ ' + ' '.join(map(str, command)) + '\n' + run(*command, capture=True))
        results.append(f'Sparkle appcast verified: build {bundle["CFBundleVersion"]}, version {version}, '
                       f'{update_zip.stat().st_size} bytes, EdDSA signature valid.\n')
        (evidence / 'artifact-verification.txt').write_text('\n'.join(results))
        artifacts = [archive, output / update_zip.name, output / appcast.name]
        for source, destination in zip((final_zip, update_zip, appcast), artifacts):
            staged_output = destination.with_suffix(destination.suffix + '.partial')
            shutil.copyfile(source, staged_output)
            staged_output.replace(destination)

    final_hash = digest(archive)
    hashes = {artifact.name: digest(artifact) for artifact in artifacts}
    (output / 'SHA256SUMS.txt').write_text(''.join(f'{sha256}  {name}\n' for name, sha256 in hashes.items()))
    state.update(phase='complete', final_sha256=final_hash, final_size_bytes=archive.stat().st_size,
                 artifact_sha256=hashes)
    write_json(state_path, state)
    print(f'Notarized release ready: {archive}\nSHA-256: {final_hash}', flush=True)
except (RuntimeError, subprocess.CalledProcessError, OSError, ValueError, KeyError, ET.ParseError) as error:
    print(f'Release incomplete: {error}', file=sys.stderr)
    print('State and staged files are retained. Resume with script/release.sh --resume after resolving the issue.', file=sys.stderr)
    sys.exit(1)
finally:
    lock.rmdir()
PY
