"""설치 실패도 paused 유지. 합성 저장소/실패 Python으로 macOS 설치는 실행하지 않는다."""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'install-social-launchd.sh'


class InstallerSafetyTests(unittest.TestCase):
    def test_dependency_failure_leaves_fresh_or_resumed_install_paused(self):
        for reinstall in (False, True):
            with self.subTest(reinstall=reinstall), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                copy = root / 'scripts/marketing/install-social-launchd.sh'
                copy.parent.mkdir(parents=True)
                binaries = root / 'stub-bin'
                binaries.mkdir()
                python = binaries / 'python3'
                python.write_text('#!/bin/sh\nexit 7\n')
                python.chmod(0o700)
                # 테스트는 PATH만 교체하여 첫 dependency 호출에서 종료한다.
                source = re.sub(r'^export PATH=.*$', f'export PATH="{binaries}:/usr/bin:/bin"',
                                SCRIPT.read_text(), count=1, flags=re.M)
                copy.write_text(source)
                if reinstall:
                    (root / 'marketing/publishing').mkdir(parents=True)
                    (root / 'marketing/publishing/resumed-fixture').touch()
                result = subprocess.run(['/bin/zsh', str(copy)],
                    env={**os.environ, 'HOME':'/Users/choesuhun'}, capture_output=True, timeout=10)
                self.assertEqual(result.returncode, 7, result.stderr.decode())
                self.assertTrue((root / 'marketing/publishing/PUBLISH_DISABLED').exists())
                # venv/Meta/check/real LaunchAgents는 도달하지 않음.
                self.assertFalse((root / '.venv-marketing').exists())

    def test_sandbox_home_is_rejected_before_install(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            copy = root / 'scripts/marketing/install-social-launchd.sh'
            copy.parent.mkdir(parents=True)
            copy.write_text(SCRIPT.read_text())
            result = subprocess.run(['/bin/zsh', str(copy)], env={**os.environ, 'HOME':str(root)},
                                    capture_output=True, timeout=10)
            self.assertEqual(result.returncode, 2)
            self.assertFalse((root / 'marketing/publishing').exists())


if __name__ == '__main__':
    unittest.main()
