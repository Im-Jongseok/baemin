import io
import json
import unittest
from nutrition_api.analysis import analyze,normalize_result,validate_image,APIError

IMAGE='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j8ioAAAAASUVORK5CYII='
RESULT={'is_food':True,'name':'비빔밥','ingredients':['밥','채소'],'nutrition':{'calories':610,'carbs':85,'protein':20,'fat':18}}

class Tests(unittest.TestCase):
 def test_demo_never_calls_external_model(self):
  def forbidden(*a,**kw):self.fail('Demo must not call provider')
  r=analyze({'image':IMAGE,'mode':'demo','sample':'비빔밥'},opener=forbidden)
  self.assertEqual(r['source'],'photo-demo');self.assertIsNone(r['modelId'])
 def test_hf_requires_consent_and_token(self):
  for kwargs in ({'consent':False},{'consent':True}):
   with self.assertRaises(APIError):analyze({'image':IMAGE,'mode':'huggingface',**kwargs},token='')
 def test_vlm_adapter_sends_expected_schema_and_validates_response(self):
  def fake(req,timeout):
   self.assertEqual(req.full_url,'https://router.huggingface.co/v1/chat/completions')
   self.assertEqual(req.headers['Authorization'],'Bearer TEST_ONLY')
   body=json.loads(req.data)
   self.assertEqual(body['messages'][0]['content'][1]['image_url']['url'],IMAGE)
   return io.BytesIO(json.dumps({'choices':[{'message':{'content':'```json\n'+json.dumps(RESULT)+'\n```'}}]}).encode())
  r=analyze({'image':IMAGE,'mode':'huggingface','consent':True},token='TEST_ONLY',model='test/model:provider',opener=fake)
  self.assertEqual(r['source'],'hf-estimate');self.assertEqual(r['nutrition']['calories'],610)
 def test_low_cost_probe_limit_is_sent_without_retry(self):
  calls=[]
  def fake(req,timeout):
   body=json.loads(req.data);calls.append(body)
   self.assertEqual(body['max_tokens'],256)
   return io.BytesIO(json.dumps({'choices':[{'message':{'content':json.dumps(RESULT)}}]}).encode())
  analyze({'image':IMAGE,'mode':'huggingface','consent':True},token='TEST_ONLY',opener=fake,max_output_tokens=256)
  self.assertEqual(len(calls),1)
 def test_invalid_image_and_model_nutrients_are_not_accepted(self):
  for value in ('https://example.com/food.jpg','data:image/svg+xml;base64,AAAA',IMAGE.replace('iVBOR','AAAAA')):
   with self.assertRaises(APIError):validate_image(value)
  for value in (-1,float('nan'),True,30001):
   data={**RESULT,'nutrition':{**RESULT['nutrition'],'calories':value}}
   with self.assertRaises(APIError):normalize_result(data)
  with self.assertRaises(APIError):normalize_result({'is_food':False})
 def test_failed_inference_does_not_return_demo_nutrition(self):
  def fake(req,timeout):return io.BytesIO(b'{"choices": [{"message":{"content":"not json"}}]}')
  with self.assertRaises(APIError):analyze({'image':IMAGE,'mode':'huggingface','consent':True},token='TEST_ONLY',opener=fake)


class ProviderFailureTests(unittest.TestCase):
 def test_provider_errors_expose_actionable_codes_without_provider_body(self):
  import urllib.error
  cases={400:'provider_model',401:'provider_auth',402:'provider_billing',403:'provider_access',404:'provider_model',429:'provider_rate_limit',503:'provider_unavailable'}
  for status,code in cases.items():
   def failed(req,timeout):
    raise urllib.error.HTTPError(req.full_url,status,'failure',{},io.BytesIO(b'PRIVATE_PROVIDER_RESPONSE'))
   with self.subTest(status=status),self.assertRaises(APIError) as caught:
    analyze({'image':IMAGE,'mode':'huggingface','consent':True},token='TEST_ONLY',opener=failed)
   self.assertEqual(caught.exception.code,code)
   self.assertEqual(caught.exception.provider_status,status)
   self.assertNotIn('PRIVATE',caught.exception.message)
 def test_whole_photo_basis_and_not_food_are_explicit(self):
  self.assertEqual(normalize_result(RESULT)['basis'],'whole-photo')
  with self.assertRaises(APIError) as caught:
   normalize_result({'is_food':False})
  self.assertEqual(caught.exception.code,'not_food')

if __name__=='__main__':unittest.main()
