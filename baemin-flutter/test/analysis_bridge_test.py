import base64
import importlib.util
import json
from pathlib import Path
from tempfile import TemporaryDirectory
from threading import Thread
import unittest
from unittest.mock import patch
import urllib.error
import urllib.request

spec = importlib.util.spec_from_file_location('bridge', Path(__file__).resolve().parents[1] / 'tools/analysis_bridge.py')
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


class BridgeTests(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory()
        self.env = Path(self.temp.name) / '.env'
        self.env.write_text('HF_TOKEN=\n')
        self.server = bridge.ThreadingHTTPServer(('127.0.0.1', 0), bridge.Bridge)
        self.server.env_file = self.env
        self.thread = Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.url = f'http://127.0.0.1:{self.server.server_port}'
        self.photo = 'data:image/png;base64,' + base64.b64encode((bridge.ROOT.parent / 'baemin-calendar-mock/tests/sample-photo.png').read_bytes()).decode()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.temp.cleanup()

    def request(self, path, body=None, headers=None):
        req = urllib.request.Request(self.url + path, data=None if body is None else json.dumps(body).encode(), headers={'Content-Type':'application/json', **(headers or {})})
        try:
            r = urllib.request.urlopen(req, timeout=5)
        except urllib.error.HTTPError as e:
            r = e
        with r:
            return r.code, json.load(r), r.headers

    def test_missing_token_is_explicit_and_never_fabricates_results(self):
        code, body, _ = self.request('/api/config')
        self.assertEqual(code, 200)
        self.assertFalse(body['hfConfigured'])
        code, body, _ = self.request('/api/photo-analyze', {'image':self.photo, 'mode':'huggingface', 'consent':True})
        self.assertEqual(code, 503)
        self.assertIn('Hugging Face', body['error'])
        self.assertNotIn('nutrition', body)

    def test_configuration_reloads_without_exposing_token(self):
        self.env.write_text('HF_TOKEN="hf_FAKE_TEST_ONLY"\nHF_MODEL_ID=example/model:provider\n')
        code, body, _ = self.request('/api/config')
        self.assertTrue(body['hfConfigured'])
        self.assertEqual(body['modelId'], 'example/model:provider')
        self.assertNotIn('hf_FAKE_TEST_ONLY', json.dumps(body))

    def test_consent_is_checked_before_model_request(self):
        self.env.write_text('HF_TOKEN=hf_FAKE_TEST_ONLY\n')
        api = bridge.backend()
        original = api.analyze
        from unittest.mock import Mock
        provider = Mock()
        def guarded(payload, **kwargs):
            return original(payload, opener=provider, **kwargs)
        with patch.object(api, 'analyze', side_effect=guarded):
            code, _, _ = self.request('/api/photo-analyze', {'image':self.photo, 'mode':'huggingface', 'consent':False})
        self.assertEqual(code, 400)
        provider.assert_not_called()

    def test_success_preserves_provider_contract(self):
        self.env.write_text('HF_TOKEN=hf_FAKE_TEST_ONLY\n')
        expected={'name':'비빔밥','nutrition':{'calories':620,'carbs':88,'protein':21,'fat':20},'source':'hf-estimate'}
        with patch.object(bridge.backend(), 'analyze', return_value=expected) as analyze:
            code, body, _ = self.request('/api/photo-analyze', {'image':self.photo,'mode':'huggingface','consent':True})
        self.assertEqual((code,body),(200,expected))
        self.assertEqual(analyze.call_args.kwargs['token'],'hf_FAKE_TEST_ONLY')

    def test_only_api_paths_and_allowed_browser_origins(self):
        self.assertEqual(self.request('/.env')[0],404)
        self.assertEqual(self.request('/api/config',headers={'Origin':'https://unrelated.example'})[0],403)
        code,_,headers=self.request('/api/config',headers={'Origin':'http://localhost:4181'})
        self.assertEqual(code,200)
        self.assertEqual(headers.get('Access-Control-Allow-Origin'),'http://localhost:4181')


if __name__ == '__main__':
    unittest.main()
