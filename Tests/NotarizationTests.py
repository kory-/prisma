"""Submission lifecycle gates; no credentials, network requests or signing are used."""
import importlib.util
from pathlib import Path
import tempfile
import io
import contextlib
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('notarize', Path(__file__).resolve().parents[1]/'Source/Notarize.py')
n = importlib.util.module_from_spec(spec)
spec.loader.exec_module(n)

class NotarizationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.work = Path(self.tmp.name)
        self.work_patch = patch.object(n, 'WORK', self.work)
        self.state_patch = patch.object(n, 'STATE', self.work/'state.json')
        self.work_patch.start(); self.state_patch.start()
        self.stdout = contextlib.redirect_stdout(io.StringIO()); self.stdout.__enter__()
    def tearDown(self):
        self.stdout.__exit__(None,None,None)
        self.state_patch.stop(); self.work_patch.stop(); self.tmp.cleanup()
    def prepared(self):
        (self.work/'payload').mkdir(); (self.work/'payload/program').write_bytes(b'signed fixture')
        (self.work/'submission.zip').write_bytes(b'archive fixture')
        n.write_state({'phase':'prepared','archive_sha256':n.digest(self.work/'submission.zip'),
                       'payload':n.payload_fingerprint(self.work/'payload')})
    def test_development_certificate_cannot_be_used(self):
        with patch.object(n,'run',return_value='1) '+'A'*40+' "Apple Development: Example (TEAM)"') as run:
            with self.assertRaisesRegex(RuntimeError,'Developer ID Application'): n.prepare(None)
            self.assertEqual(run.call_count,1)
        self.assertFalse(n.STATE.exists())
    def test_uncertain_upload_is_not_retried(self):
        self.prepared()
        with patch.object(n,'run',side_effect=RuntimeError('connection interrupted')) as run:
            with self.assertRaisesRegex(RuntimeError,'interrupted'): n.submit('test-profile')
            with self.assertRaisesRegex(RuntimeError,'already attempted'): n.submit('test-profile')
            self.assertEqual(run.call_count,1)
        self.assertEqual(n.read_state()['phase'],'submission-attempted')
    def test_mutated_payload_is_not_uploaded(self):
        self.prepared(); (self.work/'payload/program').write_bytes(b'modified')
        with patch.object(n,'run') as run:
            with self.assertRaisesRegex(RuntimeError,'changed'): n.submit('test-profile')
            run.assert_not_called()
    def test_unaccepted_submission_cannot_be_published(self):
        self.prepared(); state=n.read_state();state.update(submission_id='test-id',phase='submitted');n.write_state(state)
        with patch.object(n,'run',return_value='{"id":"test-id","status":"In Progress"}') as run:
            with self.assertRaisesRegex(RuntimeError,'not accepted'): n.finish('test-profile','streamdeck')
            self.assertEqual(run.call_count,1)
        self.assertFalse((self.work/'distribution').exists())
    def test_wrong_submission_id_is_rejected(self):
        self.prepared();state=n.read_state();state.update(submission_id='test-id',phase='submitted');n.write_state(state)
        with patch.object(n,'run',return_value='{"id":"another-id","status":"Accepted"}'):
            with self.assertRaisesRegex(RuntimeError,'does not identify'):n.status('test-profile')

if __name__=='__main__':unittest.main()
