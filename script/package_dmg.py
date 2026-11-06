#!/usr/bin/env python3
"""Package an existing signed, stapled app; repeat the same command to resume."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import time


ROOT = Path(__file__).resolve().parent.parent


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


def run(*args, check=True):
    result = subprocess.run([str(arg) for arg in args], cwd=ROOT, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if check and result.returncode:
        raise RuntimeError(f'Command failed ({result.returncode}): {args[0]}\n{result.stdout}')
    return result.stdout


def validate_app(app, results):
    for command in (
        ('/usr/bin/codesign', '--verify', '--deep', '--strict', '--verbose=2', app),
        ('xcrun', 'stapler', 'validate', app),
        ('/usr/sbin/spctl', '--assess', '--type', 'execute', '--verbose=2', app),
    ):
        results.append('$ ' + ' '.join(map(str, command)) + '\n' + run(*command))
    with (app / 'Contents/Info.plist').open('rb') as stream:
        bundle = plistlib.load(stream)
    executable = app / 'Contents/MacOS' / bundle['CFBundleExecutable']
    architectures = run('/usr/bin/lipo', '-archs', executable).split()
    if not {'arm64', 'x86_64'}.issubset(architectures):
        raise RuntimeError(f'Expected a universal app, got: {architectures}')
    signature = run('/usr/bin/codesign', '-dv', '--verbose=4', app)
    match = re.search(r'^CDHash=(\S+)$', signature, re.MULTILINE)
    if not match:
        raise RuntimeError(f'Could not read the app code directory hash: {app}')
    results.append(signature)
    results.append('Architectures: ' + ' '.join(architectures) + '\n')
    return match.group(1), digest(executable)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--evidence', required=True, type=Path)
    args = parser.parse_args()
    app, output, evidence = (path.resolve() for path in (args.app, args.output, args.evidence))
    if not app.is_dir() or app.suffix != '.app' or output.suffix != '.dmg':
        raise RuntimeError('--app must be an existing .app directory and --output a .dmg path.')
    identity = os.environ.get('WEATHER_SIGN_IDENTITY',
                              'Developer ID Application: Dongwook Min (4J7HGK26PF)')
    profile = os.environ.get('WEATHER_NOTARY_PROFILE', 'WindowWeatherNotary')
    timeout = min(int(os.environ.get('WEATHER_NOTARY_TIMEOUT_SECONDS', '1200')), 1200)
    if not identity.startswith('Developer ID Application: ') or timeout < 30:
        raise RuntimeError('Use a Developer ID Application identity and a notarization timeout of at least 30 seconds.')
    output.parent.mkdir(parents=True, exist_ok=True)
    evidence.mkdir(parents=True, exist_ok=True)
    state_path = output.with_name(output.stem + '-state.json')
    submission_path = output.with_name(output.stem + '-notary-submission.json')
    status_path = output.with_name(output.stem + '-notary-status.json')
    lock = output.with_suffix('.dmg.lock')
    try:
        lock.mkdir()
    except FileExistsError:
        raise RuntimeError(f'Packaging is running, or a stale lock remains after interruption: {lock}')

    def notary_json(command, *arguments):
        # Keep stderr separate: notarytool may print warnings beside its JSON.
        result = subprocess.run(['xcrun', 'notarytool', command, *map(str, arguments),
                                 '--keychain-profile', profile, '--output-format', 'json'],
                                cwd=ROOT, text=True, stdout=subprocess.PIPE, check=True)
        return json.loads(result.stdout)

    try:
        results = []
        app_cdhash, executable_hash = validate_app(app, results)
        if state_path.exists():
            state = json.loads(state_path.read_text())
            if (state['app_cdhash'] != app_cdhash or state['executable_sha256'] != executable_hash
                    or state['output'] != str(output) or state['identity'] != identity):
                raise RuntimeError('The input app, output, or signing identity differs from saved packaging state.')
            if state['phase'] == 'complete':
                if not output.is_file() or digest(output) != state['final_sha256']:
                    raise RuntimeError('The completed DMG is missing or changed.')
                print(f'Already complete: {output}\nSHA-256: {state["final_sha256"]}', flush=True)
                return
        else:
            if output.exists() or submission_path.exists():
                raise RuntimeError('An output or submission record already exists without packaging state; inspect it before retrying.')
            stage = Path(tempfile.mkdtemp(prefix='window-weather-dmg.', dir='/private/tmp'))
            payload = stage / 'payload'
            payload.mkdir()
            staged_app = payload / app.name
            run('/usr/bin/ditto', '--norsrc', '--noextattr', app, staged_app)
            (payload / 'Applications').symlink_to('/Applications')
            # Legacy releases omitted our notice from Resources; preserve their sealed bundles.
            if not (staged_app / 'Contents/Resources/LICENSE.txt').is_file():
                shutil.copyfile(ROOT / 'LICENSE', payload / '.LICENSE.txt')
            if validate_app(staged_app, results) != (app_cdhash, executable_hash):
                raise RuntimeError('The staged app differs from the input app.')
            upload = stage / output.name
            run('/usr/bin/hdiutil', 'create', '-srcfolder', payload, '-volname', '쌓임쌓임',
                '-fs', 'HFS+', '-format', 'UDZO', upload)
            run('/usr/bin/codesign', '--force', '--sign', identity, '--timestamp', upload)
            run('/usr/bin/codesign', '--verify', '--verbose=2', upload)
            run('/usr/bin/hdiutil', 'verify', upload)
            state = dict(app=str(app), app_name=app.name, app_cdhash=app_cdhash,
                         executable_sha256=executable_hash, output=str(output), identity=identity,
                         stage_root=str(stage), upload_path=str(upload), upload_sha256=digest(upload),
                         submission_id=None, submission_attempted=False, phase='signed')
            write_json(state_path, state)

        stage = Path(state['stage_root'])
        upload = Path(state['upload_path'])
        if not upload.is_file() or digest(upload) != state['upload_sha256']:
            raise RuntimeError('The saved signed upload is missing or changed; do not resubmit altered bytes.')
        if not state.get('submission_id') and state.get('submission_attempted') and submission_path.exists():
            state['submission_id'] = json.loads(submission_path.read_text())['id']
            write_json(state_path, state)
        if not state.get('submission_id'):
            if state.get('submission_attempted'):
                raise RuntimeError('An upload was attempted without a saved ID. Inspect notarytool history and recover its ID; do not submit again automatically.')
            state['submission_attempted'] = True
            write_json(state_path, state)
            print('Submitting signed DMG to Apple notarization…', flush=True)
            submitted = notary_json('submit', upload, '--no-wait')
            write_json(submission_path, submitted)
            state.update(submission_id=submitted['id'], phase='submitted')
            write_json(state_path, state)

        submission = state['submission_id']
        print(f'Notarization submission: {submission}', flush=True)
        deadline = time.monotonic() + timeout
        while True:
            info = notary_json('info', submission)
            write_json(status_path, info)
            print(f'Apple notarization: {info["status"]}', flush=True)
            if info['status'] != 'In Progress':
                write_json(evidence / 'dmg-notarization.json', info)
                run('xcrun', 'notarytool', 'log', submission, evidence / 'dmg-notarization-log.json',
                    '--keychain-profile', profile)
                if info['status'] != 'Accepted':
                    raise RuntimeError(f'Apple notarization was not accepted: {info["status"]}')
                break
            if time.monotonic() >= deadline:
                raise RuntimeError('Notarization is still pending. Repeat the same command to resume without a second upload.')
            run('xcrun', 'notarytool', 'wait', submission, '--keychain-profile', profile,
                '--timeout', '30s', '--output-format', 'json', check=False)

        state['phase'] = 'accepted'
        write_json(state_path, state)
        # Staple a copy so resume can always verify the original uploaded bytes.
        final_dmg = stage / 'stapled.dmg'
        shutil.copyfile(upload, final_dmg)
        run('xcrun', 'stapler', 'staple', final_dmg)
        for command in (
            ('xcrun', 'stapler', 'validate', final_dmg),
            ('/usr/bin/codesign', '--verify', '--verbose=2', final_dmg),
            ('/usr/sbin/spctl', '-a', '-t', 'open', '--context', 'context:primary-signature', '-vv', final_dmg),
            ('/usr/bin/hdiutil', 'verify', final_dmg),
        ):
            results.append('$ ' + ' '.join(map(str, command)) + '\n' + run(*command))
        mountpoint = stage / 'mounted'
        mountpoint.mkdir(exist_ok=True)
        run('/usr/bin/hdiutil', 'attach', '-readonly', '-nobrowse', '-mountpoint', mountpoint, final_dmg)
        try:
            if not (mountpoint / 'Applications').is_symlink() or os.readlink(mountpoint / 'Applications') != '/Applications':
                raise RuntimeError('The DMG Applications link does not point to /Applications.')
            if validate_app(mountpoint / state['app_name'], results) != (app_cdhash, executable_hash):
                raise RuntimeError('The mounted app differs from the input app.')
            results.append('Mounted app code signature, executable bytes, universal architectures, and Applications link verified.\n')
        finally:
            run('/usr/bin/hdiutil', 'detach', mountpoint)
        final_hash = digest(final_dmg)
        results.append(f'DMG SHA-256: {final_hash}\n')
        (evidence / 'dmg-artifact-verification.txt').write_text('\n'.join(results))
        temporary = output.with_suffix('.dmg.partial')
        shutil.copyfile(final_dmg, temporary)
        if digest(temporary) != final_hash:
            raise RuntimeError('The final DMG copy differs from its verified source.')
        temporary.replace(output)
        state.update(phase='complete', final_sha256=final_hash, final_size_bytes=output.stat().st_size)
        write_json(state_path, state)
        print(f'Notarized DMG ready: {output}\nSHA-256: {final_hash}', flush=True)
    finally:
        lock.rmdir()


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError, OSError, ValueError, KeyError) as error:
        print(f'DMG packaging incomplete: {error}', file=sys.stderr)
        print('State and staging are retained. Repeat the same command after resolving the issue.', file=sys.stderr)
        sys.exit(1)
